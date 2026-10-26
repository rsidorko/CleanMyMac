import SwiftUI
import SweepCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        // The glass backdrop comes from the panel window (see GlassBackground).
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if model.hasOnboarded {
                    HeaderView()
                    TabBar()

                    Group {
                        switch model.tab {
                        case .clean: CleanView()
                        case .uninstall: UninstallView()
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
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if model.statusMessage == message { model.statusMessage = nil }
                    }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.statusMessage)
        .frame(width: Metrics.panelWidth, height: Metrics.panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.panelRadius, style: .continuous))
        .onAppear {
            model.refreshDisk()
            model.refreshPermissions()
        }
    }
}

/// "Sweep" on the left, the Pro switch and Quit on the right, like the header of a Control Center menu.
private struct HeaderView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Text("Sweep")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Toggle("Pro", isOn: $model.proMode)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .help(model.proMode ? "Hide advanced options" : "Show every rule, file and setting")
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q")
            .help("Quit Sweep")
            .accessibilityLabel("Quit Sweep")
        }
        .padding(.horizontal, Metrics.gutter + 6)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }
}

/// Control Center–style switcher: a capsule track with a raised pill under the current tab.
private struct TabBar: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(model.visibleTabs) { tab in
                let selected = model.tab == tab
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { model.tab = tab }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.9))
                                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.07), in: Capsule())
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 10)
    }
}
