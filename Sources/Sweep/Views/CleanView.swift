import SwiftUI
import SweepCore

struct CleanView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        switch model.scanState {
        case .idle:
            IdleView()
        case .scanning(let progress, let current):
            ProgressPanel(title: "Scanning", detail: current, progress: progress, cancel: model.cancelScan)
        case .ready:
            if let report = model.report {
                if model.proMode {
                    ProResultsView(report: report)
                } else {
                    SimpleResultsView()
                }
            }
        case .cleaning(let progress):
            ProgressPanel(title: "Cleaning", detail: "Removing selected items", progress: progress, cancel: nil)
        case .finished:
            FinishedView()
        }
    }
}

private struct IdleView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            GaugeRing(fraction: model.disk?.usedFraction ?? 0) {
                ScanOrb { model.startScan() }
            }
            VStack(spacing: 4) {
                if let disk = model.disk {
                    Text("\(ByteFormat.string(disk.available)) free of \(ByteFormat.string(disk.total))")
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                }
                Text("Tuned for \(profileList(model.profiles, joiner: " and ")). Nothing is removed until you confirm.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            Spacer(minLength: 0)
            if !model.hasFullDiskAccess {
                FullDiskAccessBanner()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
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
        VStack(spacing: 16) {
            Spacer()
            GaugeRing(fraction: progress) {
                VStack(spacing: 2) {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 30, weight: .semibold))
                        .monospacedDigit()
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(detail)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
            if let cancel {
                Button("Cancel", action: cancel)
                    .buttonStyle(BubbleButtonStyle())
            }
            Spacer()
        }
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
                VStack(spacing: 16) {
                    Spacer()
                    GaugeRing(fraction: 1, tint: LinearGradient(colors: [.green, Palette.good], startPoint: .top, endPoint: .bottom)) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(Palette.good)
                    }
                    Text("All tidy")
                        .font(.title3.weight(.semibold))
                    Text("Nothing safe to clean right now. Pro shows items that need a closer look.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    Button("Scan again") { model.startScan() }
                        .buttonStyle(BubbleButtonStyle())
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ByteFormat.string(breakdown.permanent + breakdown.trash))
                                .font(.system(size: 34, weight: .semibold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("ready to clean · tuned for \(profileList(model.profiles, joiner: " and "))")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)

                        ForEach(groups) { group in
                            CategoryCard(group: group, isOn: model.isOn(group)) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    model.toggle(group)
                                    confirming = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }

                VStack(spacing: 10) {
                    if confirming {
                        Text(confirmationText(permanent: breakdown.permanent, trash: breakdown.trash))
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            Button { confirming = false } label: { Text("Cancel").frame(maxWidth: .infinity) }
                                .buttonStyle(BubbleButtonStyle())
                            Button {
                                confirming = false
                                model.cleanSelected()
                            } label: { Text("Clean now").frame(maxWidth: .infinity) }
                                .buttonStyle(BubbleButtonStyle(kind: .primary))
                                .keyboardShortcut(.defaultAction)
                        }
                    } else {
                        Button("Clean \(ByteFormat.string(breakdown.permanent + breakdown.trash))") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { confirming = true }
                        }
                        .buttonStyle(BubbleButtonStyle(kind: .primary, large: true))
                        .disabled(breakdown.count == 0)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 14)
            }
        }
    }
}

private struct CategoryCard: View {
    let group: AppModel.SimpleGroup
    let isOn: Bool
    let toggle: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 10) {
            BubbleIcon(symbol: group.category.symbolName, color: group.category.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.category.simpleTitle)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(group.category.simpleSummary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .opacity(isOn ? 1 : 0.55)
            Spacer(minLength: 4)
            Text(ByteFormat.string(group.bytes))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Toggle("Include \(group.category.simpleTitle)", isOn: Binding(get: { isOn }, set: { _ in toggle() }))
                .toggleStyle(.switch)
                .tint(Palette.good)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(radius: 18)
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
                EmptyStateView(symbol: "checkmark.seal", title: "Nothing to clean",
                               message: "Your Mac is already tidy for the selected profiles.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6, pinnedViews: [.sectionHeaders]) {
                        if !report.unreadableLocations.isEmpty && !model.hasFullDiskAccess {
                            FullDiskAccessBanner()
                        }
                        ForEach(report.categories, id: \.self) { category in
                            Section {
                                ForEach(report.results(in: category)) { result in
                                    RuleSection(result: result)
                                }
                            } header: {
                                Label(category.title.uppercased(), systemImage: category.symbolName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
            Divider()
            actionBar
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .onChange(of: model.selectedItems) { _, _ in confirming = false }
    }

    @ViewBuilder
    private var actionBar: some View {
        let breakdown = model.selectionBreakdown
        if confirming {
            VStack(spacing: 8) {
                Text(confirmationText(permanent: breakdown.permanent, trash: breakdown.trash))
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Button { confirming = false } label: { Text("Cancel").frame(maxWidth: .infinity) }
                        .buttonStyle(BubbleButtonStyle())
                    Button {
                        confirming = false
                        model.cleanSelected()
                    } label: { Text("Clean now").frame(maxWidth: .infinity) }
                        .buttonStyle(BubbleButtonStyle(kind: .primary))
                        .keyboardShortcut(.defaultAction)
                }
            }
        } else {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ByteFormat.string(breakdown.permanent + breakdown.trash))
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                    Text("\(breakdown.count) of \(report.results.reduce(0) { $0 + $1.items.count }) items selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rescan") { model.startScan() }
                    .buttonStyle(BubbleButtonStyle())
                Button("Clean…") { confirming = true }
                    .buttonStyle(BubbleButtonStyle(kind: .primary))
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .padding(.top, 4)
                Checkbox(state: model.selectionState(of: result)) { model.toggleAll(in: result) }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(result.rule.name)
                            .font(.system(size: 13, weight: .semibold))
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
            .padding(10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expanded.toggle() }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(result.items.prefix(Self.visibleItemLimit)) { item in
                        ItemRow(item: item, isSelected: model.isSelected(item)) { model.toggle(item) }
                    }
                    if result.items.count > Self.visibleItemLimit {
                        Text("and \(result.items.count - Self.visibleItemLimit) smaller items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 30)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
            }
        }
        .glassCard(radius: 14)
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
        return parts.joined(separator: " · ")
    }
}

// MARK: - Finished

private struct FinishedView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            GaugeRing(fraction: 1, tint: LinearGradient(colors: [.green, Palette.good], startPoint: .top, endPoint: .bottom)) {
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(Palette.good)
            }
            if let outcome = model.lastOutcome {
                VStack(spacing: 6) {
                    Text("\(ByteFormat.string(outcome.freedBytes + outcome.trashedBytes)) cleaned")
                        .font(.system(size: 22, weight: .semibold))
                    if outcome.freedBytes > 0 {
                        Text("\(ByteFormat.string(outcome.freedBytes)) freed right away.")
                            .foregroundStyle(.secondary)
                    }
                    if outcome.trashedBytes > 0 {
                        Text("\(ByteFormat.string(outcome.trashedBytes)) is in the Trash. Empty it to get that space back.")
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

                HStack(spacing: 8) {
                    if !outcome.record.restorableEntries.isEmpty {
                        Button("Undo") { model.undo(outcome.record) }
                            .buttonStyle(BubbleButtonStyle())
                    }
                    if model.proMode && outcome.trashedBytes > 0 {
                        Button("Open Trash") { SystemIntegration.openTrash() }
                            .buttonStyle(BubbleButtonStyle())
                    }
                    Button("Done") { model.resetScan() }
                        .buttonStyle(BubbleButtonStyle(kind: .primary))
                }
            }
            Spacer()
        }
    }
}
