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
        Group {
            if model.showFreeSpaceInMenuBar, let disk = model.disk {
                // A single Text renders reliably in the menu bar; HStacks don't.
                Text("\(Image(systemName: "trash")) \(ByteFormat.string(disk.available))")
            } else {
                Image(systemName: "trash")
            }
        }
        // The label is the only view created at launch, so it's where the dev preview gets the model.
        .task { DevPreview.showIfEnabled(model: model) }
    }
}

/// With SWEEP_PREVIEW=1 (set by scripts/dev.sh), the panel also opens in a floating window at launch, so
/// each rebuild shows up without clicking the menu bar icon (the menu bar panel closes when the app relaunches).
@MainActor
enum DevPreview {
    private static var window: NSWindow?

    static func showIfEnabled(model: AppModel) {
        guard ProcessInfo.processInfo.environment["SWEEP_PREVIEW"] == "1", window == nil else { return }
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Metrics.panelWidth, height: Metrics.panelHeight),
                             styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        window.title = "Sweep preview"
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: RootView().environmentObject(model))
        if let screen = NSScreen.main?.visibleFrame {
            window.setFrameTopLeftPoint(NSPoint(x: screen.maxX - Metrics.panelWidth - 24, y: screen.maxY - 12))
        }
        window.orderFrontRegardless()
        self.window = window
    }
}
