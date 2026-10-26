import SwiftUI
import SweepCore

/// Only shown in Pro mode.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("What do you use this Mac for?")
                ProfilePicker()
                if let suggestion = model.suggestion, !suggestion.profiles.isEmpty,
                   Set(suggestion.profiles) != model.profiles {
                    SuggestionCard(suggestion: suggestion) {
                        model.profiles = Set(suggestion.profiles)
                    }
                }

                SectionTitle("Options")
                VStack(spacing: 0) {
                    SettingRow(title: "Show free space in menu bar", isOn: $model.showFreeSpaceInMenuBar)
                    RowDivider()
                    SettingRow(title: "Always use the Trash",
                               detail: "Rebuildable caches are normally deleted right away so the space is freed immediately.",
                               isOn: $model.alwaysUseTrash)
                    RowDivider()
                    SettingRow(title: "Open at login",
                               isOn: Binding(get: { model.launchesAtLogin }, set: { model.setLaunchAtLogin($0) }))
                }
                .insetGroup()

                SectionTitle("Permissions")
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Full Disk Access")
                            .font(.system(size: 13))
                        Text("Needed to read the Trash, Mail downloads and app containers.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if model.hasFullDiskAccess {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.multicolor)
                    } else {
                        Button("Open Settings") { SystemIntegration.openFullDiskAccessSettings() }
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .insetGroup()

                SectionTitle("Recent cleanups")
                VStack(spacing: 0) {
                    if model.history.isEmpty {
                        Text("Nothing cleaned yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    ForEach(Array(model.history.prefix(8).enumerated()), id: \.element.id) { index, record in
                        if index > 0 { RowDivider() }
                        HistoryRow(record: record)
                    }
                }
                .insetGroup()

                HStack {
                    Spacer()
                    Button("Run Setup Again") { model.hasOnboarded = false }
                        .controlSize(.small)
                    Spacer()
                }
                .padding(.top, 10)
                Text("Sweep \(Self.version)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Metrics.gutter)
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

private struct SettingRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct HistoryRow: View {
    @EnvironmentObject private var model: AppModel
    let record: CleanupRecord

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(ByteFormat.string(record.totalBytes)) cleaned")
                    .font(.system(size: 13))
                    .monospacedDigit()
                Text("\(DateFormat.relative(record.date).capitalizingFirstLetter), \(record.entries.count) item\(record.entries.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if !record.restorableEntries.isEmpty {
                Button("Undo") { model.undo(record) }
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
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
                    .controlSize(.small)
            }
            EvidenceList(suggestion: suggestion)
        }
        .padding(10)
        .insetGroup()
    }
}

struct EvidenceList: View {
    let suggestion: ProfileSuggestion

    var body: some View {
        let lines = suggestion.profiles.flatMap { suggestion.evidence[$0] ?? [] }.prefix(4)
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Label(line, systemImage: "checkmark")
                    .font(.system(size: 11))
                    .labelStyle(EvidenceLabelStyle())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct EvidenceLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            configuration.title
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
                    withAnimation(.easeOut(duration: 0.15)) { model.toggle(profile) }
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
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.title)
                        .font(.system(size: 12, weight: .medium))
                    Text(profile.summary)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: Metrics.groupRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Metrics.groupRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Metrics.groupRadius, style: .continuous))
        }
        .buttonStyle(TileStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private struct TileStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}
