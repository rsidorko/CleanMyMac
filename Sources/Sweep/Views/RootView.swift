import SwiftUI
import SweepCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            GlassBackground()

            VStack(spacing: 0) {
                if model.hasOnboarded {
                    HeaderView()
                    BubbleTabs(tabs: model.visibleTabs, selection: $model.tab)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)

                    Group {
                        switch model.tab {
                        case .clean: CleanView()
                        case .apps: AppsView()
                        case .settings: SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    OnboardingView()
                }
            }

            if let message = model.statusMessage {
                Toast(message: message) { model.statusMessage = nil }
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if model.statusMessage == message { model.statusMessage = nil }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.statusMessage)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: model.proMode)
        .frame(width: 400, height: 580)
        .onAppear {
            model.refreshDisk()
            model.refreshPermissions()
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Label("Sweep", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .labelStyle(SweepLabelStyle())
                Spacer()
                ProButton(isOn: $model.proMode)
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(RoundButtonStyle())
                .keyboardShortcut("q")
                .help("Quit Sweep")
                .accessibilityLabel("Quit Sweep")
            }
            if model.proMode, let disk = model.disk {
                DiskBar(usage: disk)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

private struct SweepLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(Palette.blue)
            configuration.title
        }
    }
}

struct DiskBar: View {
    let usage: DiskUsage

    var body: some View {
        HStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.blueTop, tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * usage.usedFraction)
                }
            }
            .frame(height: 7)
            Text("\(ByteFormat.string(usage.available)) free of \(ByteFormat.string(usage.total))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
        }
    }

    private var tint: Color {
        switch usage.usedFraction {
        case ..<0.75: return Palette.blueBottom
        case ..<0.9: return .orange
        default: return .red
        }
    }
}
