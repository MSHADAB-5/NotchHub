import SwiftUI

@main
struct NotchHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window — this is an LSUIElement agent app.
        // All UI is in the notch overlay panel and menu bar.
        Settings {
            Text("NotchHub Settings — Coming Soon")
                .frame(width: 300, height: 200)
        }
    }
}
