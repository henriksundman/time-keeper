import SwiftUI

@main
struct TimeKeeperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    #if os(macOS)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    #endif
                }
        }
    }
}
