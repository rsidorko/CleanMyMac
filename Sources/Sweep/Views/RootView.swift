import SwiftUI
import SweepCore

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if model.hasOnboarded {
                HeaderView()
                Picker("Section", selection: $model.tab) {
                    ForEach(AppModel.Tab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                Divider()

                Group {
                    switch model.tab {
                    case .clean: CleanView()
                    case .apps: AppsView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                FooterView()
            } else {
                OnboardingView()
            }
        }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Sweep", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text(model.profiles.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let disk = model.disk {
                DiskBar(usage: disk)
            }
        }
        .padding(14)
    }
}

struct DiskBar: View {
    let usage: DiskUsage

    private var tint: Color {
        switch usage.usedFraction {
        case ..<0.75: return .accentColor
        case ..<0.9: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: usage.usedFraction)
                .tint(tint)
            HStack {
                Text("\(ByteFormat.string(usage.available)) available")
                Spacer()
                Text("\(ByteFormat.string(usage.used)) of \(ByteFormat.string(usage.total)) used")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
}

private struct FooterView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            if let message = model.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Button {
                    model.statusMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
