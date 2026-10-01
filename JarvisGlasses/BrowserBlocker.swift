import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class BrowserBlocker: ObservableObject {
    static let shared = BrowserBlocker()

    @Published var selection = FamilyActivitySelection()
    @Published var isAuthorized = false
    @Published var isBlocking = false
    @Published var status = "Screen Time permission required"

    private let store = ManagedSettingsStore(named: .init("NexerBrowserLock"))

    private init() {
        refreshAuthorization()
    }

    func refreshAuthorization() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        status = isAuthorized ? "Ready — select every browser you want locked" : "Screen Time permission required"
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshAuthorization()
        } catch {
            status = "Authorization failed: \(error.localizedDescription)"
        }
    }

    func startBlocking() {
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else {
            status = "Select Safari, Chrome/Google, Orion, Edge, Firefox and any other browser first"
            return
        }

        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
        isBlocking = true
        status = "Browser lock is ON"
    }
}
