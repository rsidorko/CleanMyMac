import SwiftUI
import SweepCore

/// Only shown in Pro mode.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GroupLabel("What do you use this Mac for?")
                ProfilePicker()
                if let suggestion = model.suggestion, !suggestion.profiles.isEmpty,
                   Set(suggestion.profiles) != model.profiles {
                    SuggestionCard(suggestion: suggestion) {
                        model.profiles = Set(suggestion.profiles)
                    }
                }

                GroupLabel("Options")
                VStack(spacing: 0) {
                    SettingRow(title: "Show free space in menu bar", isOn: $model.showFreeSpaceInMenuBar)
                    Divider().padding(.leading, 12)
                    SettingRow(title: "Always use the Trash",
                               detail: "Rebuildable caches are normally deleted right away so the space is freed immediately.",
                               isOn: $model.alwaysUseTrash)
                    Divider().padding(.leading, 12)
                    SettingRow(title: "Open at login",
                               isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchAtLogin($0) }))
                }
                .glassCard()

                GroupLabel("Permissions")
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Full Disk Access")
                            .font(.system(size: 12.5))
                        Text("Needed to read the Trash, Mail downloads and app containers.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if model.hasFullDiskAccess {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.good)
                    } else {
                        Button("Open Settings") { SystemIntegration.openFullDiskAccessSettings() }
                            .buttonStyle(BubbleButtonStyle())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .glassCard()

                GroupLabel("Recent cleanups")
                VStack(spacing: 0) {
                    if model.history.isEmpty {
                        Text("Nothing cleaned yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    ForEach(Array(model.history.prefix(8).enumerated()), id: \.element.id) { index, record in
                        if index > 0 { Divider().padding(.leading, 12) }
                        HistoryRow(record: record)
                    }
                }
                .glassCard()

                HStack {
                    Spacer()
                    Button("Run setup again") { model.hasOnboarded = false }
                        .buttonStyle(BubbleButtonStyle())
                    Spacer()
                }
                Text("Sweep \(Self.version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 60)
        }
        .onAppear { model.refreshPermissions() }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }
}

private struct GroupLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 6)
            .padding(.top, 4)
    }
}

private struct SettingRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5))
                if let detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(Palette.good)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

private struct HistoryRow: View {
    @EnvironmentObject private var model: AppModel
    let record: CleanupRecord

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(ByteFormat.string(record.totalBytes)) cleaned")
                    .font(.system(size: 12.5))
                Text("\(DateFormat.relative(record.date)) · \(record.entries.count) item\(record.entries.count == 1 ? "" : "s")")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if !record.restorableEntries.isEmpty {
                Button("Undo") { model.undo(record) }
                    .buttonStyle(BubbleButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

struct SuggestionCard: View {
    let suggestion: ProfileSuggestion
    let apply: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Suggested: \(suggestion.profiles.map(\.title).joined(separator: ", "))")
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 4)
                Button("Apply", action: apply)
                    .buttonStyle(BubbleButtonStyle())
            }
            EvidenceList(suggestion: suggestion)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.accentColor.opacity(0.12)))
    }
}

struct EvidenceList: View {
    let suggestion: ProfileSuggestion

    var body: some View {
        let lines = suggestion.profiles.flatMap { suggestion.evidence[$0] ?? [] }.prefix(4)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text("• " + line)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Grid of usage profiles. At least one always stays selected.
struct ProfilePicker: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(UsageProfile.allCases) { profile in
                ProfileTile(profile: profile, isSelected: model.profiles.contains(profile)) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { model.toggle(profile) }
                }
            }
        }
    }
}

private struct ProfileTile: View {
    let profile: UsageProfile
    let isSelected: Bool
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: profile.symbolName)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.title)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(profile.summary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.25), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(TileStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private struct TileStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
        }
    }
}
