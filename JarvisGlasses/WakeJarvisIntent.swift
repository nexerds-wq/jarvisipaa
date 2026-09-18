import AppIntents

struct WakeJarvisIntent: AppIntent {
    static var title: LocalizedStringResource = "Wake Jarvis"
    static var description = IntentDescription("Send the M02S AI wake command over Bluetooth.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        try await BLEController.shared.wakeSavedGlasses()
        return .result()
    }
}

struct JarvisShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WakeJarvisIntent(),
            phrases: [
                "Wake Jarvis with \(.applicationName)",
                "Wake my glasses with \(.applicationName)"
            ],
            shortTitle: "Wake Jarvis",
            systemImageName: "waveform.circle"
        )
    }
}
