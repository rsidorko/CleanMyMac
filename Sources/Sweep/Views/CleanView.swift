import SwiftUI
import SweepCore

struct CleanView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        switch model.scanState {
        case .idle:
            IdleView()
        case .scanning(let progress, let current):
            ProgressPanel(title: "Scanning…", detail: current, progress: progress, cancel: model.cancelScan)
        case .ready:
            if let report = model.report {
                ResultsView(report: report)
            }
        case .cleaning(let progress):
            ProgressPanel(title: "Cleaning…", detail: "Removing selected items", progress: progress, cancel: nil)
        case .finished:
            FinishedView()
        }
    }
}

private struct IdleView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: 4) {
                Text("Ready to scan")
                    .font(.title3.weight(.semibold))
                Text("Tuned for \(model.profiles.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: ", ")). Nothing is removed until you review and confirm.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Button {
                model.startScan()
            } label: {
                Text("Scan")
                    .frame(width: 140)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            Spacer()
            if !model.hasFullDiskAccess {
                FullDiskAccessBanner()
                    .padding(12)
            }
        }
    }
}

private struct ProgressPanel: View {
    let title: String
    let detail: String
    let progress: Double
    let cancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(.headline)
            ProgressView(value: progress)
                .padding(.horizontal, 40)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let cancel {
                Button("Cancel", action: cancel)
                    .controlSize(.small)
            }
            Spacer()
        }
    }
}

private struct ResultsView: View {
    @EnvironmentObject private var model: AppModel
    let report: ScanReport
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            if report.results.isEmpty {
                EmptyStateView(symbol: "checkmark.seal", title: "Nothing to clean",
                               message: "Your Mac is already tidy for the selected profile.")
            } else {
                List {
                    if !report.unreadableLocations.isEmpty && !model.hasFullDiskAccess {
                        FullDiskAccessBanner()
                            .listRowSeparator(.hidden)
                    }
                    ForEach(report.categories, id: \.self) { category in
                        Section {
                            ForEach(report.results(in: category)) { result in
                                RuleSection(result: result)
                            }
                        } header: {
                            Label(category.title, systemImage: category.symbolName)
                        }
                    }
                }
                .listStyle(.inset)
            }
            Divider()
            actionBar
                .padding(12)
        }
        .onChange(of: model.selectedItems) { _, _ in confirming = false }
    }

    @ViewBuilder
    private var actionBar: some View {
        let breakdown = model.selectionBreakdown
        if confirming {
            VStack(alignment: .leading, spacing: 8) {
                Text(confirmationText(permanent: breakdown.permanent, trash: breakdown.trash))
                    .font(.callout)
                HStack {
                    Spacer()
                    Button("Cancel") { confirming = false }
                    Button("Clean") {
                        confirming = false
                        model.cleanSelected()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ByteFormat.string(breakdown.permanent + breakdown.trash))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text("\(breakdown.count) of \(report.results.reduce(0) { $0 + $1.items.count }) items selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rescan") { model.startScan() }
                Button("Clean…") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(breakdown.count == 0)
            }
        }
    }

    private func confirmationText(permanent: Int64, trash: Int64) -> String {
        var parts: [String] = []
        if permanent > 0 { parts.append("delete \(ByteFormat.string(permanent)) of data that rebuilds itself") }
        if trash > 0 { parts.append("move \(ByteFormat.string(trash)) to the Trash") }
        return "This will " + parts.joined(separator: " and ") + "."
    }
}

private struct RuleSection: View {
    @EnvironmentObject private var model: AppModel
    let result: RuleResult
    @State private var expanded = false

    private static let visibleItemLimit = 60

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(result.items.prefix(Self.visibleItemLimit)) { item in
                ItemRow(item: item, isSelected: model.isSelected(item)) { model.toggle(item) }
            }
            if result.items.count > Self.visibleItemLimit {
                Text("and \(result.items.count - Self.visibleItemLimit) smaller items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Checkbox(state: model.selectionState(of: result)) { model.toggleAll(in: result) }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(result.rule.name)
                            .font(.body.weight(.medium))
                        if result.rule.safety == .review {
                            Tag(text: "Review", color: .orange)
                        }
                    }
                    Text(result.rule.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detailLine)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 4)
                Text(ByteFormat.string(result.totalBytes))
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .onTapGesture { expanded.toggle() }
        }
    }

    private var detailLine: String {
        var parts: [String] = []
        parts.append(result.rule.resolvedDeletion(alwaysUseTrash: model.alwaysUseTrash) == .permanent ? "Deleted" : "Moved to Trash")
        if result.policy.minAgeDays > 0 {
            parts.append("unused for \(result.policy.minAgeDays)+ days")
        }
        if result.skippedRecentCount > 0 {
            parts.append("\(result.skippedRecentCount) recently used kept")
        }
        return parts.joined(separator: " · ")
    }
}

private struct FinishedView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.green)
            if let outcome = model.lastOutcome {
                VStack(spacing: 6) {
                    Text("\(ByteFormat.string(outcome.freedBytes + outcome.trashedBytes)) cleaned")
                        .font(.title3.weight(.semibold))
                    if outcome.freedBytes > 0 {
                        Text("\(ByteFormat.string(outcome.freedBytes)) freed right away.")
                            .foregroundStyle(.secondary)
                    }
                    if outcome.trashedBytes > 0 {
                        Text("\(ByteFormat.string(outcome.trashedBytes)) is in the Trash. Empty it to reclaim the space.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    if !outcome.failures.isEmpty {
                        Text("\(outcome.failures.count) item\(outcome.failures.count == 1 ? "" : "s") couldn't be removed.")
                            .foregroundStyle(.orange)
                            .help(outcome.failures.prefix(10).map { "\($0.path): \($0.reason)" }.joined(separator: "\n"))
                    }
                }
                .font(.callout)
                .padding(.horizontal, 24)

                HStack {
                    if !outcome.record.restorableEntries.isEmpty {
                        Button("Undo") { model.undo(outcome.record) }
                    }
                    if outcome.trashedBytes > 0 {
                        Button("Open Trash") { SystemIntegration.openTrash() }
                    }
                    Button("Done") { model.resetScan() }
                        .buttonStyle(.borderedProminent)
                }
            }
            Spacer()
        }
    }
}
