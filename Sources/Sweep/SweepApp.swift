import SwiftUI

@main
struct SweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        // Lives in the status area of the menu bar, beside Control Center. macOS decides the initial
        // position; ⌘-drag the icon to move it and macOS remembers where you put it.
        MenuBarExtra {
            RootView()
                .environmentObject(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon or app menu, even when launched without the bundle's LSUIElement
        // (e.g. via `swift run`).
        NSApp.setActivationPolicy(.accessory)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.showFreeSpaceInMenuBar, let disk = model.disk {
            // A single Text renders reliably in the menu bar; HStacks don't.
            Text("\(Image(systemName: "sparkles")) \(ByteFormat.string(disk.available))")
        } else {
            Image(systemName: "sparkles")
        }
    }
}
