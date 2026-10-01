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
    private var timer: Timer?

    private init() {
        refreshAuthorization()
        startClock()
    }

    func refreshAuthorization() {
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if isAuthorized { enforceSchedule() }
        else { status = "Screen Time permission required" }
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
        enforceSchedule()
    }

    private func startClock() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.enforceSchedule() }
        }
    }

    private func enforceSchedule(now: Date = Date()) {
        guard isAuthorized else { return }
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty || !selection.webDomainTokens.isEmpty else { return }

        let hour = Calendar.current.component(.hour, from: now)
        let allowedWindow = hour >= 13 && hour < 18

        if allowedWindow {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            isBlocking = false
            status = "Browsers unlocked until 6:00 PM"
        } else {
            store.shield.applications = selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
            store.shield.webDomains = selection.webDomainTokens
            isBlocking = true
            status = "LOCKED — browser access is only allowed 1:00 PM–6:00 PM"
        }
    }
}
