import Foundation
import CoreBluetooth

struct FoundGlasses: Identifiable, Hashable {
    let id: UUID
    let name: String
    let rssi: Int
}

final class BLEController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BLEController()

    // Confirmed from your M02S capture.
    private let controlService = CBUUID(string: "DE5BF728-D711-4E47-AF26-65E3012A5DC7")
    private let writeCharacteristicUUID = CBUUID(string: "DE5BF72A-D711-4E47-AF26-65E3012A5DC7")
    private let wakePacket = Data(hexString: "BC4103009052020107")!

    @Published var status: String = "Ready"
    @Published var devices: [FoundGlasses] = []
    @Published var selectedName: String = UserDefaults.standard.string(forKey: "jarvis.glasses.name") ?? "Not selected"
    @Published var isScanning = false

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var activePeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var pendingWake = false
    private var wakeContinuation: CheckedContinuation<Void, Error>?
    private var powerContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionRestoreIdentifierKey: "com.nexer.jarvisglasses.central"]
        )
    }

    var savedPeripheralID: UUID? {
        guard let raw = UserDefaults.standard.string(forKey: "jarvis.glasses.id") else { return nil }
        return UUID(uuidString: raw)
    }

    func startScan() {
        guard central.state == .poweredOn else {
            status = "Turn Bluetooth on"
            return
        }
        devices.removeAll()
        peripherals.removeAll()
        isScanning = true
        status = "Scanning..."
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self = self else { return }
            if self.isScanning {
                self.stopScan()
            }
        }
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        if devices.isEmpty {
            status = "No BLE devices found. Make sure the glasses are on."
        } else {
            status = "Pick your M02S below"
        }
    }

    func select(_ device: FoundGlasses) {
        guard let peripheral = peripherals[device.id] else { return }
        UserDefaults.standard.set(device.id.uuidString, forKey: "jarvis.glasses.id")
        UserDefaults.standard.set(device.name, forKey: "jarvis.glasses.name")
        selectedName = device.name
        activePeripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        isScanning = false
        status = "Connecting to \(device.name)..."
        central.connect(peripheral, options: nil)
    }

    func testWake() {
        Task {
            do {
                try await wakeSavedGlasses()
                await MainActor.run { self.status = "Wake command sent ✓" }
            } catch {
                await MainActor.run { self.status = "Wake failed: \(error.localizedDescription)" }
            }
        }
    }

    func wakeSavedGlasses() async throws {
        if let peripheral = activePeripheral,
           peripheral.state == .connected,
           let characteristic = writeCharacteristic {
            peripheral.writeValue(wakePacket, for: characteristic, type: .withoutResponse)
            return
        }

        try await waitForBluetooth()

        guard let id = savedPeripheralID else {
            throw JarvisBLEError.noSavedGlasses
        }

        let matches = central.retrievePeripherals(withIdentifiers: [id])
        guard let peripheral = matches.first else {
            throw JarvisBLEError.glassesUnavailable
        }

        activePeripheral = peripheral
        peripheral.delegate = self
        pendingWake = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            wakeContinuation = continuation
            central.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                guard let self = self, let continuation = self.wakeContinuation else { return }
                self.wakeContinuation = nil
                self.pendingWake = false
                self.central.cancelPeripheralConnection(peripheral)
                continuation.resume(throwing: JarvisBLEError.timeout)
            }
        }
    }

    private func waitForBluetooth() async throws {
        if central.state == .poweredOn { return }
        if central.state == .unauthorized { throw JarvisBLEError.bluetoothUnauthorized }
        if central.state == .unsupported { throw JarvisBLEError.bluetoothUnsupported }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            powerContinuation = continuation
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self = self, let continuation = self.powerContinuation else { return }
                self.powerContinuation = nil
                continuation.resume(throwing: JarvisBLEError.bluetoothOff)
            }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            status = "Bluetooth ready"
            if let continuation = powerContinuation {
                powerContinuation = nil
                continuation.resume()
            }
        } else if central.state == .poweredOff {
            status = "Bluetooth is off"
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? "BLE Device"
        peripherals[peripheral.identifier] = peripheral

        let item = FoundGlasses(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let index = devices.firstIndex(where: { $0.id == item.id }) {
            devices[index] = item
        } else {
            devices.append(item)
            devices.sort { lhs, rhs in
                let lM02 = lhs.name.localizedCaseInsensitiveContains("M02")
                let rM02 = rhs.name.localizedCaseInsensitiveContains("M02")
                if lM02 != rM02 { return lM02 }
                return lhs.rssi > rhs.rssi
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        activePeripheral = peripheral
        peripheral.delegate = self
        status = "Connected. Finding control service..."
        peripheral.discoverServices([controlService])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        finishWake(error: error ?? JarvisBLEError.connectFailed)
        status = "Connection failed"
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        writeCharacteristic = nil
        if pendingWake {
            finishWake(error: error ?? JarvisBLEError.disconnected)
        }
        status = "Disconnected"
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            finishWake(error: error)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == controlService }) else {
            finishWake(error: JarvisBLEError.controlServiceMissing)
            return
        }
        peripheral.discoverCharacteristics([writeCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            finishWake(error: error)
            return
        }
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == writeCharacteristicUUID }) else {
            finishWake(error: JarvisBLEError.writeCharacteristicMissing)
            return
        }

        writeCharacteristic = characteristic
        status = "M02S ready ✓"

        if pendingWake {
            peripheral.writeValue(wakePacket, for: characteristic, type: .withoutResponse)
            pendingWake = false
            if let continuation = wakeContinuation {
                wakeContinuation = nil
                continuation.resume()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        if let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let saved = savedPeripheralID,
           let peripheral = restored.first(where: { $0.identifier == saved }) {
            activePeripheral = peripheral
            peripheral.delegate = self
        }
    }

    private func finishWake(error: Error) {
        pendingWake = false
        if let continuation = wakeContinuation {
            wakeContinuation = nil
            continuation.resume(throwing: error)
        }
    }
}

enum JarvisBLEError: LocalizedError {
    case noSavedGlasses
    case glassesUnavailable
    case bluetoothOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case connectFailed
    case disconnected
    case controlServiceMissing
    case writeCharacteristicMissing
    case timeout

    var errorDescription: String? {
        switch self {
        case .noSavedGlasses: return "Open Jarvis Glasses once and select your M02S first."
        case .glassesUnavailable: return "The saved glasses were not available. Turn them on and open the app once."
        case .bluetoothOff: return "Bluetooth did not become ready."
        case .bluetoothUnauthorized: return "Bluetooth permission is blocked for Jarvis Glasses."
        case .bluetoothUnsupported: return "Bluetooth LE is not supported."
        case .connectFailed: return "Could not connect to the glasses."
        case .disconnected: return "The glasses disconnected before the command was sent."
        case .controlServiceMissing: return "The M02S control service was not found."
        case .writeCharacteristicMissing: return "The M02S write characteristic was not found."
        case .timeout: return "Timed out connecting to the glasses."
        }
    }
}

extension Data {
    init?(hexString: String) {
        let clean = hexString.replacingOccurrences(of: " ", with: "")
        guard clean.count % 2 == 0 else { return nil }
        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        for _ in 0..<(clean.count / 2) {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
