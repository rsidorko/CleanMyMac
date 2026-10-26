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
                        .frame(width: 22, height: 6)
                }
            }
            if step == 0 {
                profileStep
            } else {
                accessStep
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What do you use this Mac for?")
                .font(.system(size: 20, weight: .semibold))
            Text("Sweep is careful with files your work depends on and thorough with everything else. Pick one or more.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ProfilePicker()
                    if let suggestion = model.suggestion, !suggestion.profiles.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("We preselected what we found")
                                .font(.system(size: 12, weight: .semibold))
                            EvidenceList(suggestion: suggestion)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentColor.opacity(0.12)))
                    }
                }
            }
            HStack {
                Spacer()
                Button("Continue") { step = 1 }
                    .buttonStyle(BubbleButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            BubbleIcon(symbol: "lock.shield.fill", color: Palette.blueBottom, size: 52)
            Text("Allow Full Disk Access")
                .font(.system(size: 20, weight: .semibold))
            Text("macOS hides some folders from apps, including the Trash and Mail downloads. Sweep only reads them during a scan and never sends anything off your Mac.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Open Privacy & Security settings.")
                Text("2. Turn on Sweep under Full Disk Access.")
                Text("3. Come back here. Sweep picks it up on its own.")
            }
            .foregroundStyle(.secondary)
            if model.hasFullDiskAccess {
                Label("Full Disk Access is on", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Palette.good)
                    .font(.system(size: 13, weight: .semibold))
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Back") { step = 0 }
                    .buttonStyle(BubbleButtonStyle())
                Spacer()
                if model.hasFullDiskAccess {
                    Button("Start") { finish() }
                        .buttonStyle(BubbleButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Later") { finish() }
                        .buttonStyle(BubbleButtonStyle())
                    Button("Open Settings") { SystemIntegration.openFullDiskAccessSettings() }
                        .buttonStyle(BubbleButtonStyle(kind: .primary))
                }
            }
        }
        .task {
            // Notice when the user grants access in System Settings.
            while !Task.isCancelled && !model.hasFullDiskAccess {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                model.refreshPermissions()
            }
        }
    }

    private func finish() {
        model.tab = .clean
        model.hasOnboarded = true
    }
}
