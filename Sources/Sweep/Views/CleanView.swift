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
                if model.proMode {
                    ProResultsView(report: report)
                } else {
                    SimpleResultsView()
                }
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
        VStack(alignment: .leading, spacing: 12) {
            if let disk = model.disk {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(ByteFormat.string(disk.available)) available")
                            .font(.system(size: 20, weight: .semibold))
                            .monospacedDigit()
                        Spacer(minLength: 4)
                        Text("of \(ByteFormat.string(disk.total))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    CapacityBar(fraction: disk.usedFraction)
                    Text("\(ByteFormat.string(disk.used)) used")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(12)
                .insetGroup()
            }

            Text("Tuned for \(profileList(model.profiles, joiner: " and ")). Nothing is removed until you confirm.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            Spacer(minLength: 0)

            if !model.hasFullDiskAccess {
                FullDiskAccessBanner()
            }

            Button { model.startScan() } label: {
                Text("Scan").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, Metrics.gutter)
    }
}

func profileList(_ profiles: Set<UsageProfile>, joiner: String) -> String {
    profiles.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: joiner)
}

private struct ProgressPanel: View {
    let title: String
    let detail: String
    let progress: Double
    let cancel: (@MainActor () -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .animation(.easeOut(duration: 0.3), value: progress)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let cancel {
                Button(action: cancel) {
                    Text("Cancel").frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, Metrics.gutter + 4)
        .padding(.bottom, Metrics.gutter)
    }
}

/// A large symbol with a title and message, used for "done" and "nothing found" states.
private struct StatusMessage: View {
    let symbol: String
    var color: Color = .secondary
    let title: String
    let message: [String]

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(color)
                .padding(.bottom, 4)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
            ForEach(message, id: \.self) { line in
                Text(line)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Simple mode

private struct SimpleResultsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirming = false

    var body: some View {
        let groups = model.simpleGroups
        let breakdown = model.selectionBreakdown
        VStack(spacing: 0) {
            if groups.isEmpty {
                Spacer()
                StatusMessage(symbol: "checkmark.circle", title: "All tidy",
                              message: ["Nothing safe to clean right now. Turn on Pro to see items that need a closer look."])
                Spacer()
                Button { model.startScan() } label: { Text("Scan again").frame(maxWidth: .infinity) }
                    .controlSize(.large)
                    .padding(Metrics.gutter)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ByteFormat.string(breakdown.permanent + breakdown.trash))
                                .font(.system(size: 26, weight: .semibold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("can be cleaned, tuned for \(profileList(model.profiles, joiner: " and "))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                                if index > 0 { RowDivider(leading: 46) }
                                CategoryRow(group: group, isOn: model.isOn(group)) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        model.toggle(group)
                                        confirming = false
                                    }
                                }
                            }
                        }
                        .insetGroup()
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 10)
                }

                VStack(spacing: 8) {
                    if confirming {
                        Text(confirmationText(permanent: breakdown.permanent, trash: breakdown.trash))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button { confirming = false } label: { Text("Cancel").frame(maxWidth: .infinity) }
                                .keyboardShortcut(.cancelAction)
                            Button {
                                confirming = false
                                model.cleanSelected()
                            } label: { Text("Clean now").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(.defaultAction)
                        }
                        .controlSize(.large)
                    } else {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { confirming = true }
                        } label: {
                            Text("Clean \(ByteFormat.string(breakdown.permanent + breakdown.trash))")
                                .monospacedDigit()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(breakdown.count == 0)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 4)
                .padding(.bottom, Metrics.gutter)
            }
        }
    }
}

private struct CategoryRow: View {
    let group: AppModel.SimpleGroup
    let isOn: Bool
    let toggle: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 10) {
            SymbolCircle(symbol: group.category.symbolName, isOn: isOn)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.category.simpleTitle)
                    .font(.system(size: 13))
                Text(group.category.simpleSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Text(ByteFormat.string(group.bytes))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Toggle("Include \(group.category.simpleTitle)", isOn: Binding(get: { isOn }, set: { _ in toggle() }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
    }
}

func confirmationText(permanent: Int64, trash: Int64) -> String {
    var parts: [String] = []
    if permanent > 0 { parts.append("delete \(ByteFormat.string(permanent)) of data that rebuilds itself") }
    if trash > 0 { parts.append("move \(ByteFormat.string(trash)) to the Trash") }
    return "This will " + parts.joined(separator: " and ") + "."
}

// MARK: - Pro mode

private struct ProResultsView: View {
    @EnvironmentObject private var model: AppModel
    let report: ScanReport
    @State private var confirming = false

    var body: some View {
        VStack(spacing: 0) {
            if report.results.isEmpty {
                Spacer()
                StatusMessage(symbol: "checkmark.circle", title: "Nothing to clean",
                              message: ["Your Mac is already tidy for the selected profiles."])
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if !report.unreadableLocations.isEmpty && !model.hasFullDiskAccess {
                            FullDiskAccessBanner()
                        }
                        ForEach(report.categories, id: \.self) { category in
                            let results = report.results(in: category)
                            SectionTitle(category.title, trailing: ByteFormat.string(results.reduce(0) { $0 + $1.totalBytes }))
                            VStack(spacing: 0) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                    if index > 0 { RowDivider(leading: 50) }
                                    RuleSection(result: result)
                                }
                            }
                            .insetGroup()
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 8)
                }
            }
            Divider()
            actionBar
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 10)
        }
        .onChange(of: model.selectedItems) { _, _ in confirming = false }
    }

    @ViewBuilder
    private var actionBar: some View {
        let breakdown = model.selectionBreakdown
        if confirming {
            VStack(spacing: 8) {
                Text(confirmationText(permanent: breakdown.permanent, trash: breakdown.trash))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button { confirming = false } label: { Text("Cancel").frame(maxWidth: .infinity) }
                        .keyboardShortcut(.cancelAction)
                    Button {
                        confirming = false
                        model.cleanSelected()
                    } label: { Text("Clean now").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        } else {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(ByteFormat.string(breakdown.permanent + breakdown.trash))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                    Text("\(breakdown.count) of \(report.results.reduce(0) { $0 + $1.items.count }) items selected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Button("Rescan") { model.startScan() }
                Button("Clean…") { confirming = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(breakdown.count == 0)
            }
        }
    }
}

private struct RuleSection: View {
    @EnvironmentObject private var model: AppModel
    let result: RuleResult
    @State private var expanded = false

    private static let visibleItemLimit = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 10)
                    .padding(.top, 4)
                Checkbox(state: model.selectionState(of: result)) { model.toggleAll(in: result) }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(result.rule.name)
                            .font(.system(size: 13))
                        if result.rule.safety == .review {
                            Tag(text: "Review", color: .orange)
                        }
                    }
                    Text(result.rule.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detailLine)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 4)
                Text(ByteFormat.string(result.totalBytes))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(expanded ? "Hides the files" : "Shows the files")

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.items.prefix(Self.visibleItemLimit)) { item in
                        ItemRow(item: item, isSelected: model.isSelected(item)) { model.toggle(item) }
                    }
                    if result.items.count > Self.visibleItemLimit {
                        Text("and \(result.items.count - Self.visibleItemLimit) smaller items")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 34)
                .padding(.trailing, 10)
                .padding(.bottom, 8)
            }
        }
    }

    private var detailLine: String {
        var parts: [String] = []
        parts.append(result.rule.resolvedDeletion(alwaysUseTrash: model.alwaysUseTrash) == .permanent ? "Deleted" : "Moved to Trash")
        parts.append(result.policy.mode.rawValue)
        if result.policy.minAgeDays > 0 {
            parts.append("unused for \(result.policy.minAgeDays)+ days")
        }
        if result.skippedRecentCount > 0 {
            parts.append("\(result.skippedRecentCount) recently used kept")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Finished

private struct FinishedView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            if let outcome = model.lastOutcome {
                StatusMessage(symbol: "checkmark.circle.fill", color: .green,
                              title: "\(ByteFormat.string(outcome.freedBytes + outcome.trashedBytes)) cleaned",
                              message: lines(for: outcome))
                if !outcome.failures.isEmpty {
                    Text("\(outcome.failures.count) item\(outcome.failures.count == 1 ? "" : "s") couldn't be removed.")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .padding(.top, 6)
                        .help(outcome.failures.prefix(10).map { "\($0.path): \($0.reason)" }.joined(separator: "\n"))
                }
            }
            Spacer()
            HStack(spacing: 8) {
                if let outcome = model.lastOutcome {
                    if !outcome.record.restorableEntries.isEmpty {
                        Button("Undo") { model.undo(outcome.record) }
                    }
                    if model.proMode && outcome.trashedBytes > 0 {
                        Button("Open Trash") { SystemIntegration.openTrash() }
                    }
                }
                Spacer()
                Button("Done") { model.resetScan() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(Metrics.gutter)
        }
    }

    private func lines(for outcome: CleanupOutcome) -> [String] {
        var lines: [String] = []
        if outcome.freedBytes > 0 {
            lines.append("\(ByteFormat.string(outcome.freedBytes)) freed right away.")
        }
        if outcome.trashedBytes > 0 {
            lines.append("\(ByteFormat.string(outcome.trashedBytes)) is in the Trash. Empty it to get that space back.")
        }
        return lines
    }
}
