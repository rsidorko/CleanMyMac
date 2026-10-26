import AppKit
import SwiftUI
import SweepCore

// The panel follows the look of macOS's own menu bar extras (Control Center, Wi-Fi, Battery): the menu
// material, system text colors, the user's accent color, native controls and grouped rows. Color is only
// used where it means something: the accent for the main action and selections, green for done, orange for
// caution, red for removal.

enum Metrics {
    static let panelWidth: CGFloat = 360
    static let panelHeight: CGFloat = 560
    /// Horizontal inset of panel content.
    static let gutter: CGFloat = 12
    static let groupRadius: CGFloat = 10
}

/// The menu material behind the whole panel.
struct PanelBackground: View {
    var body: some View {
        VisualEffectView(material: .menu, blendingMode: .behindWindow)
            .ignoresSafeArea()
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}

/// A rounded group of rows on a faint fill, like the sections of a Control Center menu.
struct InsetGroup: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Metrics.groupRadius, style: .continuous))
    }
}

extension View {
    func insetGroup() -> some View { modifier(InsetGroup()) }
}

/// Divider between rows of an inset group, starting where the row's text starts.
struct RowDivider: View {
    var leading: CGFloat = 10

    var body: some View {
        Divider().padding(.leading, leading)
    }
}

/// Small sentence-case heading above a group, with an optional count or total on the right.
struct SectionTitle: View {
    let title: String
    var trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.top, 6)
    }
}

/// An SF Symbol in a circle: accent-filled when on, grey when off, like Control Center's toggles.
struct SymbolCircle: View {
    let symbol: String
    var isOn = false
    var size: CGFloat = 26

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .medium))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(width: size, height: size)
            .background(Circle().fill(isOn ? Color.accentColor : Color.primary.opacity(0.10)))
            .animation(.easeOut(duration: 0.15), value: isOn)
    }
}

/// Thin capacity bar, as in System Settings › Storage.
struct CapacityBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(fraction >= 0.9 ? Color.red : Color.accentColor)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("Disk used")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}

/// Message at the bottom of the panel.
struct Toast: View {
    let message: String
    let dismiss: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.system(size: 12))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .padding(.horizontal, Metrics.gutter)
    }
}

extension RuleCategory {
    /// Friendlier names for simple mode.
    var simpleTitle: String {
        switch self {
        case .system: return "System junk"
        case .downloads: return "Old installers"
        case .developer: return "Developer files"
        case .creative: return "Creative caches"
        case .gaming: return "Game temp files"
        }
    }

    var simpleSummary: String {
        switch self {
        case .system: return "App caches, logs and old updates"
        case .downloads: return "Disk images you've already installed"
        case .developer: return "Build data, package caches, idle projects"
        case .creative: return "Render files and media caches"
        case .gaming: return "Unfinished downloads and web caches"
        }
    }
}
