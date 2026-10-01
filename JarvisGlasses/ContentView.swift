import SwiftUI
import FamilyControls

struct ContentView: View {
    @EnvironmentObject var bluetooth: BLEController
    @StateObject private var blocker = BrowserBlocker.shared
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 72))

                    Text("Jarvis Glasses")
                        .font(.largeTitle.bold())

                    GroupBox("Browser Lock") {
                        VStack(spacing: 12) {
                            Text(blocker.status)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)

                            if !blocker.isAuthorized {
                                Button("Enable Screen Time Access") {
                                    Task { await blocker.requestAuthorization() }
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            Button("Choose Browsers / Apps") {
                                showPicker = true
                            }
                            .buttonStyle(.bordered)
                            .disabled(!blocker.isAuthorized || blocker.isBlocking)

                            Button(blocker.isBlocking ? "LOCK ACTIVE" : "START BROWSER LOCK") {
                                blocker.startBlocking()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!blocker.isAuthorized || blocker.isBlocking)

                            Text("Select Safari, Chrome/Google, Orion, Edge, Firefox and any other browser installed on the phone. iOS applies the system shield when a selected app opens.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 6)
                    }
                    .padding(.horizontal)

                    Divider()

                    Text("Selected glasses: \(bluetooth.selectedName)")
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

                    ForEach(bluetooth.devices) { device in
                        Button {
                            bluetooth.select(device)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(device.name).font(.headline)
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
                            .padding(.horizontal)
                        }
                    }

                    Text("Wake packet: BC4103009052020107")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical)
            }
            .navigationTitle("Setup")
            .familyActivityPicker(isPresented: $showPicker, selection: $blocker.selection)
            .onAppear { blocker.refreshAuthorization() }
        }
    }
}
