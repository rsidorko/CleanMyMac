import SwiftUI
import SweepCore

struct AppsView: View {
    @EnvironmentObject private var model: AppModel

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
            } else if model.proMode {
                ProAppsView()
            } else {
                SimpleAppsView()
            }
        }
        .onAppear { model.loadApps() }
    }
}

private func thresholdLabel(_ days: Int) -> String {
    days >= 365 ? "a year" : "\(days / 30) months"
}

// MARK: - Simple

private struct SimpleAppsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirming: String?

    var body: some View {
        let apps = model.unusedApps
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Not opened in \(thresholdLabel(model.unusedThresholdDays))")

                VStack(spacing: 0) {
                    if apps.isEmpty {
                        Text("Every app has been opened recently.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        if index > 0 { RowDivider(leading: 52) }
                        SimpleAppRow(app: app, confirming: confirming == app.id,
                                     ask: { withAnimation(.easeOut(duration: 0.2)) { confirming = app.id } },
                                     cancel: { withAnimation(.easeOut(duration: 0.2)) { confirming = nil } },
                                     remove: {
                                         confirming = nil
                                         model.uninstallWithSupportFiles(app)
                                     })
                    }
                }
                .insetGroup()

                if !model.leftovers.isEmpty {
                    SectionTitle("Left behind by deleted apps")
                    HStack(spacing: 10) {
                        SymbolCircle(symbol: "folder", size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Support files of \(model.leftovers.count) app\(model.leftovers.count == 1 ? "" : "s")")
                                .font(.system(size: 13))
                            Text(ByteFormat.string(model.leftovers.reduce(0) { $0 + $1.totalBytes }))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 4)
                        Button("Move to Trash") { model.removeAllLeftovers() }
                            .controlSize(.small)
                            .disabled(model.appsBusy)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .insetGroup()
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 60)
        }
        .onChange(of: model.unusedThresholdDays) { _, _ in model.computeSizes(for: model.unusedApps) }
    }
}

private struct SimpleAppRow: View {
    @EnvironmentObject private var model: AppModel
    let app: InstalledApp
    let confirming: Bool
    let ask: @MainActor () -> Void
    let cancel: @MainActor () -> Void
    let remove: @MainActor () -> Void

    private var isRunning: Bool {
        app.bundleID.map { SystemIntegration.runningBundleIDs().contains($0) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(nsImage: SystemIntegration.icon(for: app.url))
                    .resizable()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if !confirming {
                    Button(isRunning ? "Open" : "Remove", action: ask)
                        .controlSize(.small)
                        .disabled(isRunning || model.appsBusy)
                        .help(isRunning ? "Quit \(app.name) to remove it." : "Move \(app.name) and its files to the Trash.")
                }
            }
            if confirming {
                HStack(spacing: 8) {
                    Text("Move \(app.name) and its files to the Trash?")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("Keep", action: cancel)
                        .keyboardShortcut(.cancelAction)
                    Button("Remove", role: .destructive, action: remove)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let lastUsed = app.lastUsed { parts.append("Last opened \(DateFormat.relative(lastUsed))") }
        if let size = model.appSizes[app.id] { parts.append(ByteFormat.string(size)) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Pro

private struct ProAppsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let apps = model.unusedApps
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Not opened in")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Picker("Not opened in", selection: $model.unusedThresholdDays) {
                    Text("3 months").tag(90)
                    Text("6 months").tag(180)
                    Text("1 year").tag(365)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                Spacer()
                Button("Refresh") { model.loadApps(force: true) }
                    .disabled(model.appsLoading)
            }
            .controlSize(.small)
            .padding(.horizontal, Metrics.gutter + 2)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    SectionTitle("Unused apps", trailing: "\(apps.count)")
                    VStack(spacing: 0) {
                        if apps.isEmpty {
                            Text("No apps have gone unopened that long.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                            if index > 0 { RowDivider(leading: 60) }
                            ProAppRow(app: app)
                        }
                    }
                    .insetGroup()

                    SectionTitle("Left behind by deleted apps", trailing: "\(model.leftovers.count)")
                    VStack(spacing: 0) {
                        if model.leftovers.isEmpty {
                            Text("No leftover app data found.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        ForEach(Array(model.leftovers.enumerated()), id: \.element.id) { index, group in
                            if index > 0 { RowDivider(leading: 50) }
                            LeftoverRow(group: group)
                        }
                    }
                    .insetGroup()
                    if !model.leftovers.isEmpty {
                        HStack {
                            Spacer()
                            Button("Move \(ByteFormat.string(model.selectedLeftoverBytes)) to Trash") {
                                model.removeSelectedLeftovers()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.selectedLeftovers.isEmpty || model.appsBusy)
                        }
                        .padding(.top, 2)
                    }

                    Text("Apps without a recorded last-use date are not listed. Apple apps and apps that are open can't be removed here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 60)
            }
        }
        .onChange(of: model.unusedThresholdDays) { _, _ in model.computeSizes(for: model.unusedApps) }
    }
}

private struct ProAppRow: View {
    @EnvironmentObject private var model: AppModel
    let app: InstalledApp
    @State private var expanded = false
    @State private var related: [ScanItem]?
    @State private var included: Set<String> = []
    @State private var confirming = false

    private var isRunning: Bool {
        app.bundleID.map { SystemIntegration.runningBundleIDs().contains($0) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 10)
                Image(nsImage: SystemIntegration.icon(for: app.url))
                    .resizable()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 13))
                            .lineLimit(1)
                        if isRunning { Tag(text: "Open", color: .orange) }
                    }
                    if let lastUsed = app.lastUsed {
                        Text("Last opened \(DateFormat.relative(lastUsed))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if let size = model.appSizes[app.id] {
                    Text(ByteFormat.string(size))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                let willExpand = !expanded
                withAnimation(.easeOut(duration: 0.2)) { expanded = willExpand }
                if willExpand && related == nil { loadRelated() }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let related {
                        if related.isEmpty {
                            Text("No support files found.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(related) { item in
                            HStack(spacing: 6) {
                                Checkbox(isOn: included.contains(item.id)) {
                                    if included.contains(item.id) { included.remove(item.id) } else { included.insert(item.id) }
                                    confirming = false
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.displayName)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(item.location)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer(minLength: 4)
                                Text(ByteFormat.string(item.bytes))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .contextMenu {
                                Button("Show in Finder") { SystemIntegration.revealInFinder(item.url) }
                            }
                        }
                    } else {
                        ProgressView().controlSize(.small)
                    }

                    if confirming {
                        HStack(spacing: 8) {
                            Text("Move \(app.name) and \(included.count) related item\(included.count == 1 ? "" : "s") to the Trash?")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Button("Cancel") { confirming = false }
                                .keyboardShortcut(.cancelAction)
                            Button("Move to Trash", role: .destructive) {
                                confirming = false
                                let files = (related ?? []).filter { included.contains($0.id) }
                                model.uninstall(app, including: files)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .controlSize(.small)
                    } else {
                        HStack(spacing: 8) {
                            Text(isRunning ? "Quit \(app.name) to uninstall it." : "Everything goes to the Trash, so you can put it back.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Button("Uninstall…") { confirming = true }
                                .controlSize(.small)
                                .disabled(isRunning || related == nil || model.appsBusy)
                        }
                    }
                }
                .padding(.leading, 30)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
            }
        }
    }

    private func loadRelated() {
        Task {
            let items = await model.relatedFiles(for: app)
            related = items
            included = Set(items.map(\.id))
        }
    }
}

private struct LeftoverRow: View {
    @EnvironmentObject private var model: AppModel
    let group: LeftoverGroup
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 10)
                    .padding(.top, 4)
                Checkbox(isOn: model.selectedLeftovers.contains(group.id)) { model.toggleLeftover(group) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(SystemIntegration.appName(for: group.bundleID) ?? group.bundleID)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    Text("\(group.bundleID), \(group.items.count) item\(group.items.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(ByteFormat.string(group.totalBytes))
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

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.items) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(item.location + "/" + item.displayName)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Text(ByteFormat.string(item.bytes))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .contextMenu {
                            Button("Show in Finder") { SystemIntegration.revealInFinder(item.url) }
                        }
                    }
                }
                .padding(.leading, 30)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
            }
        }
    }
}
