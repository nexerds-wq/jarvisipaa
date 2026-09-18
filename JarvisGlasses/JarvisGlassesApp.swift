import SwiftUI

@main
struct JarvisGlassesApp: App {
    @StateObject private var bluetooth = BLEController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetooth)
        }
    }
}
