import SwiftUI
import SweepCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            PanelBackground()

            VStack(spacing: 0) {
                if model.hasOnboarded {
                    HeaderView()
                    Picker("Section", selection: $model.tab) {
                        ForEach(model.visibleTabs) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, Metrics.gutter)
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
        .padding(.horizontal, Metrics.gutter + 2)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}
