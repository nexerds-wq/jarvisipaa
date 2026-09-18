import SwiftUI

struct ContentView: View {
    @EnvironmentObject var bluetooth: BLEController

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72))

                Text("Jarvis Glasses")
                    .font(.largeTitle.bold())

                Text("Selected: \(bluetooth.selectedName)")
                    .font(.headline)

                Text(bluetooth.status)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                HStack {
                    Button(bluetooth.isScanning ? "Stop Scan" : "Scan for M02S") {
                        bluetooth.isScanning ? bluetooth.stopScan() : bluetooth.startScan()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Test Wake") {
                        bluetooth.testWake()
                    }
                    .buttonStyle(.bordered)
                }

                List(bluetooth.devices) { device in
                    Button {
                        bluetooth.select(device)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.headline)
                                Text(device.id.uuidString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(device.rssi) dBm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)

                Text("Wake packet: BC4103009052020107")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.top)
            .navigationTitle("Setup")
        }
    }
}
