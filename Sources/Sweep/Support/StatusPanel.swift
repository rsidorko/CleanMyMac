import AppKit
import Combine
import SwiftUI

/// The menu bar icon and the panel it opens. SwiftUI's MenuBarExtra window has small, fixed corners and its own
/// material, so Sweep uses a status item and a borderless glass panel instead, like Control Center.
@MainActor
final class StatusPanelController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = FloatingPanel(size: NSSize(width: Metrics.panelWidth, height: Metrics.panelHeight))
    private var clickMonitor: Any?
    private var labelUpdates: AnyCancellable?
    private var lastClosed = Date.distantPast
    /// scripts/dev.sh sets SWEEP_PREVIEW=1: the panel opens at launch and stays open when you click elsewhere,
    /// so each rebuild shows up without clicking the icon.
    private let autoHides = ProcessInfo.processInfo.environment["SWEEP_PREVIEW"] != "1"

    init(model: AppModel) {
        super.init()
        let hosting = NSHostingView(rootView: RootView().environmentObject(model))
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: panel.frame.size)
        panel.contentView = GlassBackground.make(containing: hosting, cornerRadius: Metrics.panelRadius)
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.close() }

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.imagePosition = .imageLeading
            let image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Sweep")
            image?.isTemplate = true
            button.image = image
        }
        labelUpdates = model.$showFreeSpaceInMenuBar.combineLatest(model.$disk)
            .sink { [weak self] show, disk in
                self?.statusItem.button?.title = show ? disk.map { " " + ByteFormat.string($0.available) } ?? "" : ""
            }

        if !autoHides { showOnceIconIsPlaced() }
    }

    /// The icon has no position until the menu bar has laid it out, a moment after launch.
    private func showOnceIconIsPlaced(attempt: Int = 0) {
        if iconFrame != nil || attempt >= 30 {
            show()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.showOnceIconIsPlaced(attempt: attempt + 1) }
        }
    }

    /// The icon's frame on screen, or nil while it isn't in the menu bar yet.
    private var iconFrame: NSRect? {
        guard let button = statusItem.button, let window = button.window,
              let visible = (window.screen ?? NSScreen.main)?.visibleFrame else { return nil }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        return frame.maxY >= visible.maxY ? frame : nil
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            close()
        } else if Date().timeIntervalSince(lastClosed) > 0.3 {
            // Clicking the icon while the panel is open also counts as clicking outside it; don't reopen.
            show()
        }
    }

    private func show() {
        guard let visible = (statusItem.button?.window?.screen ?? NSScreen.main)?.visibleFrame else { return }
        let size = panel.frame.size
        // Under the icon; at the top right if the icon isn't in the menu bar (e.g. hidden behind the notch).
        let centerX = iconFrame?.midX ?? visible.maxX - size.width / 2 - 8
        // Just below the menu bar, like Control Center.
        panel.setFrameOrigin(NSPoint(x: min(max(centerX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8),
                                     y: visible.maxY - 4 - size.height))
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()
        statusItem.button?.highlight(true)

        if autoHides, clickMonitor == nil {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor in self?.close() }
            }
        }
    }

    private func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
        lastClosed = Date()
    }

    func windowDidResignKey(_ notification: Notification) {
        if autoHides { close() }
    }
}

/// A borderless panel that can take keyboard input (for search) without activating the app.
final class FloatingPanel: NSPanel {
    var onEscape: (() -> Void)?

    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}

/// The panel's backdrop: Liquid Glass (NSGlassEffectView, macOS 26 and later) when the system has it, otherwise
/// the vibrant popover material. The glass class is looked up at run time so the app still builds with older SDKs.
enum GlassBackground {
    static func make(containing content: NSView, cornerRadius: CGFloat) -> NSView {
        if let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassClass.init(frame: content.frame)
            if glass.responds(to: NSSelectorFromString("setContentView:")),
               glass.responds(to: NSSelectorFromString("setCornerRadius:")) {
                glass.setValue(content, forKey: "contentView")
                glass.setValue(cornerRadius, forKey: "cornerRadius")
                return glass
            }
        }
        let effect = NSVisualEffectView(frame: content.frame)
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.maskImage = roundedMask(radius: cornerRadius)
        content.frame = effect.bounds
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        return effect
    }

    /// A stretchable rounded rectangle; NSVisualEffectView only clips its blur through a mask image.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
