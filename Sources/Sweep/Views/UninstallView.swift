import SwiftUI
import SweepCore

/// Every installed app, searchable. Choosing one shows everything it keeps on the Mac, and removes all of it.
struct UninstallView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selected: InstalledApp?

    var body: some View {
        Group {
            if model.appsLoading && !model.appsLoaded {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Looking at your apps…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let app = selected {
                AppDetailView(app: app) { withAnimation(.easeOut(duration: 0.2)) { selected = nil } }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                AppListView { app in withAnimation(.easeOut(duration: 0.2)) { selected = app } }
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .onAppear {
            model.loadApps()
            model.computeSizes(for: model.installedApps)
        }
        .onChange(of: model.installedApps) { _, apps in
            // Back to the list once the app has been removed.
            if let app = selected, !apps.contains(app) { selected = nil }
        }
    }
}

// MARK: - List

private enum AppSort: String, CaseIterable, Identifiable {
    case name = "Name", size = "Size", lastOpened = "Last opened"
    var id: String { rawValue }
}

private struct AppListView: View {
    @EnvironmentObject private var model: AppModel
    let open: @MainActor (InstalledApp) -> Void
    @State private var query = ""
    @State private var sort: AppSort = .name

    private var apps: [InstalledApp] {
        let terms = query.trimmingCharacters(in: .whitespaces)
        let matching = terms.isEmpty ? model.installedApps : model.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(terms) || ($0.bundleID?.localizedCaseInsensitiveContains(terms) ?? false)
        }
        switch sort {
        case .name:
            return matching.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            return matching.sorted { (model.appSizes[$0.id] ?? -1) > (model.appSizes[$1.id] ?? -1) }
        case .lastOpened:
            return matching.sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }
    }

    var body: some View {
        let apps = self.apps
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                SearchField(text: $query)
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(AppSort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Sort by \(sort.rawValue.lowercased())")
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    SectionTitle(query.isEmpty ? "Installed apps" : "Results", trailing: "\(apps.count)")
                    VStack(spacing: 0) {
                        if apps.isEmpty {
                            Text(query.isEmpty ? "No apps found in Applications." : "No apps match “\(query)”.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        }
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            if index > 0 { RowDivider(leading: 48) }
                            AppListRow(app: app) { open(app) }
                        }
                    }
                    .insetGroup()

                    Text("Apple apps can't be removed. Apps are moved to the Trash, so you can put them back.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 60)
            }
        }
    }
}

private struct SearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search apps", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(Color.primary.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(focused ? 0.5 : 0), lineWidth: 1))
    }
}

private struct AppListRow: View {
    @EnvironmentObject private var model: AppModel
    let app: InstalledApp
    let open: @MainActor () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: open) {
            HStack(spacing: 9) {
                Image(nsImage: SystemIntegration.icon(for: app.url))
                    .resizable()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 13))
                            .lineLimit(1)
                        if model.isRunning(app) { Tag(text: "Open", color: .orange) }
                    }
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if let size = model.appSizes[app.id] {
                    Text(ByteFormat.string(size))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(hovering ? 0.05 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var subtitle: String {
        if let lastUsed = app.lastUsed { return "Opened \(DateFormat.relative(lastUsed))" }
        return app.version.map { "Version \($0)" } ?? "Never opened"
    }
}

// MARK: - Detail

private struct AppDetailView: View {
    @EnvironmentObject private var model: AppModel
    let app: InstalledApp
    let back: @MainActor () -> Void
    @State private var related: [ScanItem]?
    @State private var excluded: Set<String> = []
    @State private var confirming = false

    private var included: [ScanItem] { (related ?? []).filter { !excluded.contains($0.id) } }
    private var totalBytes: Int64 {
        let appBytes: Int64 = model.appSizes[app.id] ?? 0
        return included.reduce(appBytes) { $0 + $1.bytes }
    }
    private var isRunning: Bool { model.isRunning(app) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    Button(action: back) {
                        Label("All apps", systemImage: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)

                    header

                    if let related {
                        ForEach(groups(of: related), id: \.title) { group in
                            SectionTitle(group.title, trailing: ByteFormat.string(group.items.reduce(0) { $0 + $1.bytes }))
                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                    if index > 0 { RowDivider(leading: model.proMode ? 34 : 10) }
                                    RelatedFileRow(item: item, showsCheckbox: model.proMode,
                                                   isIncluded: !excluded.contains(item.id)) {
                                        if excluded.contains(item.id) { excluded.remove(item.id) } else { excluded.insert(item.id) }
                                        confirming = false
                                    }
                                }
                            }
                            .insetGroup()
                        }
                        if related.isEmpty {
                            Text("\(app.name) keeps no other files in your Library.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.top, 6)
                        }
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Finding everything \(app.name) keeps…")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 12)
            }

            actionBar
        }
        .task(id: app.id) {
            model.computeSizes(for: [app])
            let items = await model.relatedFiles(for: app)
            related = items
            excluded = []
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: SystemIntegration.icon(for: app.url))
                .resizable()
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(app.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    if isRunning { Tag(text: "Open", color: .orange) }
                }
                Text([app.version.map { "Version \($0)" }, app.lastUsed.map { "opened \(DateFormat.relative($0))" }]
                    .compactMap { $0 }.joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(summary)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .insetGroup()
        .contextMenu {
            Button("Show in Finder") { SystemIntegration.revealInFinder(app.url) }
        }
    }

    private var summary: String {
        guard related != nil, model.appSizes[app.id] != nil else { return "Measuring…" }
        let count = included.count
        return "\(ByteFormat.string(totalBytes)) in total, with \(count) related item\(count == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isRunning {
                HStack(spacing: 8) {
                    Text("Quit \(app.name) to uninstall it.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button("Quit \(app.name)") { model.quit(app) }
                }
            } else if confirming {
                Text("Move \(app.name) and \(included.count) related item\(included.count == 1 ? "" : "s") to the Trash?")
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel") { confirming = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Move to Trash", role: .destructive) {
                        confirming = false
                        model.uninstall(app, including: included)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                HStack(spacing: 8) {
                    if model.appsBusy {
                        ProgressView().controlSize(.small)
                        Text("Uninstalling…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Everything goes to the Trash, so you can put it back.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Button("Uninstall") { confirming = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(related == nil || model.appsBusy)
                }
            }
        }
        .controlSize(.small)
        .padding(.horizontal, Metrics.gutter + 6)
        .padding(.vertical, 10)
        .background(alignment: .top) { Divider() }
        .animation(.easeOut(duration: 0.15), value: confirming)
    }

    /// Related files grouped by what they are, in the order people care about.
    private func groups(of items: [ScanItem]) -> [(title: String, items: [ScanItem])] {
        let order = ["App data", "Sandboxed data", "Shared data", "Caches", "Preferences", "Background items",
                     "Web data", "Window state", "Logs", "Crash reports", "Scripts", "Other"]
        let grouped = Dictionary(grouping: items, by: kind(of:))
        return order.compactMap { title in grouped[title].map { (title, $0) } }
    }

    private func kind(of item: ScanItem) -> String {
        switch item.url.deletingLastPathComponent().lastPathComponent {
        case "Application Support": return "App data"
        case "Containers": return "Sandboxed data"
        case "Group Containers": return "Shared data"
        case "Caches": return "Caches"
        case "Preferences", "ByHost": return "Preferences"
        case "LaunchAgents": return "Background items"
        case "HTTPStorages", "WebKit": return "Web data"
        case "Saved Application State": return "Window state"
        case "Logs": return "Logs"
        case "DiagnosticReports": return "Crash reports"
        case "Application Scripts": return "Scripts"
        default: return "Other"
        }
    }
}

private struct RelatedFileRow: View {
    let item: ScanItem
    let showsCheckbox: Bool
    let isIncluded: Bool
    let toggle: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if showsCheckbox { Checkbox(isOn: isIncluded, action: toggle) }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(item.location)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 4)
            Text(ByteFormat.string(item.bytes))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .opacity(isIncluded ? 1 : 0.5)
        .contextMenu {
            Button("Show in Finder") { SystemIntegration.revealInFinder(item.url) }
        }
    }
}
