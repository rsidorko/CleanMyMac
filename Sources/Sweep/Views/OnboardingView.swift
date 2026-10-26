import SwiftUI
import SweepCore

/// First run: pick profiles (detected ones are preselected), then ask for Full Disk Access.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<2) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color.primary.opacity(0.12))
                        .frame(width: 18, height: 4)
                }
            }
            if step == 0 {
                profileStep
            } else {
                accessStep
            }
        }
        .padding(.horizontal, Metrics.gutter + 4)
        .padding(.top, 18)
        .padding(.bottom, Metrics.gutter)
        .animation(.easeOut(duration: 0.2), value: step)
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What do you use this Mac for?")
                .font(.system(size: 17, weight: .semibold))
            Text("Sweep is careful with files your work depends on and thorough with everything else. Pick one or more.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ProfilePicker()
                    if let suggestion = model.suggestion, !suggestion.profiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preselected from what's on this Mac")
                                .font(.system(size: 12, weight: .semibold))
                            EvidenceList(suggestion: suggestion)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .insetGroup()
                    }
                }
            }
            HStack {
                Spacer()
                Button("Continue") { step = 1 }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.system(size: 34))
                .foregroundStyle(Color.accentColor)
            Text("Allow Full Disk Access")
                .font(.system(size: 17, weight: .semibold))
            Text("macOS hides some folders from apps, including the Trash and Mail downloads. Sweep only reads them during a scan and never sends anything off your Mac.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Open Privacy & Security settings.")
                Text("2. Turn on Sweep under Full Disk Access.")
                Text("3. Come back here. Sweep picks it up on its own.")
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            if !model.hasFullDiskAccess && SystemIntegration.canRelaunch {
                HStack(spacing: 6) {
                    Text("Turned it on but nothing changed?")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("Relaunch Sweep") { SystemIntegration.relaunch() }
                        .controlSize(.small)
                }
            }
            if model.hasFullDiskAccess {
                Label("Full Disk Access is on", systemImage: "checkmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 12, weight: .medium))
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Back") { step = 0 }
                Spacer()
                if model.hasFullDiskAccess {
                    Button("Start") { finish() }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Later") { finish() }
                    Button("Open Settings") { SystemIntegration.openFullDiskAccessSettings() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func finish() {
        model.tab = .clean
        model.hasOnboarded = true
    }
}
