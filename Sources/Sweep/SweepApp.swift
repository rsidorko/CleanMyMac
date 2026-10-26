import SwiftUI

@main
struct SweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar icon and its panel are AppKit (see StatusPanelController); SwiftUI needs at least one scene.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusPanel: StatusPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon or app menu, even when launched without the bundle's LSUIElement
        // (e.g. via `swift run`).
        NSApp.setActivationPolicy(.accessory)
        // Lives in the status area of the menu bar, beside Control Center. macOS decides the initial
        // position; ⌘-drag the icon to move it and macOS remembers where you put it.
        statusPanel = StatusPanelController(model: AppModel())
    }
}
