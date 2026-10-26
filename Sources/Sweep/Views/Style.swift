import AppKit
import SwiftUI
import SweepCore

enum Palette {
    static let blueTop = Color(red: 0.31, green: 0.66, blue: 1.0)
    static let blueBottom = Color(red: 0.04, green: 0.45, blue: 1.0)
    static let proStart = Color(red: 1.0, green: 0.70, blue: 0.25)
    static let proEnd = Color(red: 1.0, green: 0.42, blue: 0.37)
    static let dangerTop = Color(red: 1.0, green: 0.48, blue: 0.43)
    static let dangerBottom = Color(red: 0.84, green: 0.23, blue: 0.18)
    static let good = Color(red: 0.12, green: 0.64, blue: 0.36)

    static let blue = LinearGradient(colors: [blueTop, blueBottom], startPoint: .top, endPoint: .bottom)
    static let pro = LinearGradient(colors: [proStart, proEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let danger = LinearGradient(colors: [dangerTop, dangerBottom], startPoint: .top, endPoint: .bottom)
}

/// The blurred desktop behind the panel, plus a faint white sheen so it reads as glass.
struct GlassBackground: View {
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            LinearGradient(colors: [Color.white.opacity(0.10), Color.white.opacity(0.02)], startPoint: .top, endPoint: .bottom)
        }
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

/// Rounded, glossy buttons that squish when pressed.
struct BubbleButtonStyle: ButtonStyle {
    enum Kind { case plain, primary, danger }
    var kind: Kind = .plain
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        BubbleBody(configuration: configuration, kind: kind, large: large)
    }

    private struct BubbleBody: View {
        let configuration: Configuration
        let kind: Kind
        let large: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(large ? .system(size: 15, weight: .semibold) : .system(size: 12.5, weight: .medium))
                .foregroundStyle(kind == .plain ? Color.primary : Color.white)
                .padding(.horizontal, large ? 18 : 13)
                .padding(.vertical, large ? 11 : 5)
                .frame(maxWidth: large ? .infinity : nil)
                .background(background)
                .overlay(highlight)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(kind == .plain ? 0.10 : 0), lineWidth: 1))
                .clipShape(Capsule())
                .shadow(color: shadowColor, radius: 8, y: 4)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .opacity(isEnabled ? 1 : 0.45)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
                .contentShape(Capsule())
        }

        @ViewBuilder private var background: some View {
            switch kind {
            case .plain: Capsule().fill(.regularMaterial)
            case .primary: Capsule().fill(Palette.blue)
            case .danger: Capsule().fill(Palette.danger)
            }
        }

        private var highlight: some View {
            Capsule()
                .fill(LinearGradient(colors: [Color.white.opacity(kind == .plain ? 0.35 : 0.40), Color.white.opacity(0)],
                                     startPoint: .top, endPoint: .center))
                .padding(.horizontal, 6)
                .padding(.top, 1.5)
                .allowsHitTesting(false)
        }

        private var shadowColor: Color {
            switch kind {
            case .plain: return Color.black.opacity(0.08)
            case .primary: return Palette.blueBottom.opacity(0.35)
            case .danger: return Palette.dangerBottom.opacity(0.30)
            }
        }
    }
}

/// Small round icon button (quit, dismiss).
struct RoundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(Circle().fill(.regularMaterial))
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
            .contentShape(Circle())
    }
}

/// The Pro switch in the header: plain bubble when off, warm gradient when on.
struct ProButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { isOn.toggle() }
        } label: {
            Label("Pro", systemImage: "star.fill")
                .font(.system(size: 12, weight: .bold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    if isOn {
                        Capsule().fill(Palette.pro)
                    } else {
                        Capsule().fill(.regularMaterial)
                    }
                }
                .overlay(Capsule().strokeBorder(Color.primary.opacity(isOn ? 0 : 0.10), lineWidth: 1))
                .shadow(color: isOn ? Palette.proEnd.opacity(0.35) : .black.opacity(0.08), radius: 8, y: 3)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(isOn ? "Hide advanced options" : "Show advanced options")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Pill-shaped tab switcher with a sliding bubble.
struct BubbleTabs: View {
    let tabs: [AppModel.Tab]
    @Binding var selection: AppModel.Tab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selection = tab }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 12.5, weight: selection == tab ? .semibold : .medium))
                        .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(.regularMaterial)
                                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                                    .matchedGeometryEffect(id: "tab", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
    }
}

/// Rounded translucent card used for rows and groups.
struct GlassCard: ViewModifier {
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.white.opacity(0.10)))
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }
}

extension View {
    func glassCard(radius: CGFloat = 16) -> some View { modifier(GlassCard(radius: radius)) }
}

/// A glossy colored circle holding an SF Symbol.
struct BubbleIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 38

    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [color.opacity(0.65), color], center: UnitPoint(x: 0.35, y: 0.3),
                                         startRadius: 0, endRadius: size * 0.7))
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0)], startPoint: .top, endPoint: .center))
                .padding(size * 0.12)
                .offset(y: -size * 0.08)
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(0.35), radius: 5, y: 3)
    }
}

/// The disk ring that surrounds the scan button and shows progress.
struct GaugeRing<Content: View>: View {
    let fraction: Double
    var tint: LinearGradient = Palette.blue
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.001, min(fraction, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: fraction)
            content()
        }
        .frame(width: 200, height: 200)
    }
}

/// The big glossy Scan button.
struct ScanOrb: View {
    let action: @MainActor () -> Void
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text("Scan")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
        }
        .buttonStyle(OrbStyle())
        .background {
            Circle()
                .stroke(Palette.blueBottom.opacity(0.35), lineWidth: 2)
                .scaleEffect(pulsing ? 1.2 : 0.95)
                .opacity(pulsing ? 0 : 0.9)
                .allowsHitTesting(false)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { pulsing = true }
        }
        .keyboardShortcut(.defaultAction)
    }

    private struct OrbStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(width: 132, height: 132)
                .background(Circle().fill(RadialGradient(colors: [Palette.blueTop, Palette.blueBottom],
                                                         center: UnitPoint(x: 0.35, y: 0.28), startRadius: 4, endRadius: 90)))
                .overlay(alignment: .top) {
                    Ellipse()
                        .fill(LinearGradient(colors: [Color.white.opacity(0.6), Color.white.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 70, height: 40)
                        .padding(.top, 10)
                        .allowsHitTesting(false)
                }
                .clipShape(Circle())
                .shadow(color: Palette.blueBottom.opacity(0.45), radius: 16, y: 10)
                .scaleEffect(configuration.isPressed ? 0.93 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
                .contentShape(Circle())
        }
    }
}

/// Floating message at the bottom of the panel.
struct Toast: View {
    let message: String
    let dismiss: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .font(.system(size: 12))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        .padding(.horizontal, 14)
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

    var tint: Color {
        switch self {
        case .system: return Color(red: 0.24, green: 0.55, blue: 1.0)
        case .downloads: return Color(red: 1.0, green: 0.60, blue: 0.24)
        case .developer: return Color(red: 0.48, green: 0.42, blue: 0.94)
        case .creative: return Color(red: 0.94, green: 0.37, blue: 0.56)
        case .gaming: return Color(red: 0.18, green: 0.75, blue: 0.53)
        }
    }
}
