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
            VStack(alignment: .leading, spacing: 8) {
                Text("Apps you haven't opened in \(thresholdLabel(model.unusedThresholdDays))")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)

                if apps.isEmpty {
                    Text("Every app has been used recently.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                }
                ForEach(apps) { app in
                    SimpleAppCard(app: app, confirming: confirming == app.id,
                                  ask: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { confirming = app.id } },
                                  cancel: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { confirming = nil } },
                                  remove: {
                                      confirming = nil
                                      model.uninstallWithSupportFiles(app)
                                  })
                }

                if !model.leftovers.isEmpty {
                    HStack(spacing: 10) {
                        BubbleIcon(symbol: "folder.fill", color: Color(red: 0.55, green: 0.60, blue: 0.67), size: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Leftovers from deleted apps")
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(model.leftovers.count) app\(model.leftovers.count == 1 ? "" : "s") · \(ByteFormat.string(model.leftovers.reduce(0) { $0 + $1.totalBytes }))")
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Button("Clean up") { model.removeAllLeftovers() }
                            .buttonStyle(BubbleButtonStyle())
                            .disabled(model.appsBusy)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .glassCard(radius: 18)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 60)
        }
        .onChange(of: model.unusedThresholdDays) { _, _ in model.computeSizes(for: model.unusedApps) }
    }
}

private struct SimpleAppCard: View {
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
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if !confirming {
                    Button(isRunning ? "Open" : "Remove", action: ask)
                        .buttonStyle(BubbleButtonStyle())
                        .disabled(isRunning || model.appsBusy)
                        .help(isRunning ? "Quit \(app.name) to remove it." : "Move \(app.name) and its files to the Trash.")
                }
            }
            if confirming {
                HStack(spacing: 8) {
                    Text("Move \(app.name) and its files to the Trash?")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button("Keep", action: cancel)
                        .buttonStyle(BubbleButtonStyle())
                    Button("Remove", action: remove)
                        .buttonStyle(BubbleButtonStyle(kind: .danger))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(radius: 18)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let lastUsed = app.lastUsed { parts.append("Last opened \(DateFormat.relative(lastUsed))") }
        if let size = model.appSizes[app.id] { parts.append(ByteFormat.string(size)) }
        return parts.joined(separator: " · ")
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
                    .buttonStyle(BubbleButtonStyle())
                    .disabled(model.appsLoading)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6, pinnedViews: [.sectionHeaders]) {
                    Section {
                        if apps.isEmpty {
                            Text("No apps have gone unopened that long.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(10)
                        }
                        ForEach(apps) { app in
                            ProAppRow(app: app)
                        }
                    } header: {
                        SectionHeader(title: "Unused apps · \(apps.count)")
                    }

                    Section {
                        if model.leftovers.isEmpty {
                            Text("No leftover app data found.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(10)
                        }
                        ForEach(model.leftovers) { group in
                            LeftoverRow(group: group)
                        }
                        if !model.leftovers.isEmpty {
                            HStack {
                                Spacer()
                                Button("Move \(ByteFormat.string(model.selectedLeftoverBytes)) to Trash") {
                                    model.removeSelectedLeftovers()
                                }
                                .buttonStyle(BubbleButtonStyle(kind: .primary))
                                .disabled(model.selectedLeftovers.isEmpty || model.appsBusy)
                            }
                            .padding(.top, 4)
                        }
                    } header: {
                        SectionHeader(title: "Left behind by deleted apps · \(model.leftovers.count)")
                    }

                    Text("Apps without a recorded last-use date are not listed. Apple apps and apps that are open can't be removed here.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 60)
            }
        }
        .onChange(of: model.unusedThresholdDays) { _, _ in model.computeSizes(for: model.unusedApps) }
    }
}

private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                Image(nsImage: SystemIntegration.icon(for: app.url))
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .semibold))
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
                        .monospacedDigit()
                }
            }
            .padding(10)
            .contentShape(Rectangle())
            .onTapGesture {
                let willExpand = !expanded
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expanded = willExpand }
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
                                .buttonStyle(BubbleButtonStyle())
                            Button("Move to Trash") {
                                confirming = false
                                let files = (related ?? []).filter { included.contains($0.id) }
                                model.uninstall(app, including: files)
                            }
                            .buttonStyle(BubbleButtonStyle(kind: .danger))
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(isRunning ? "Quit \(app.name) to uninstall it." : "Everything goes to the Trash, so you can put it back.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 4)
                            Button("Uninstall…") { confirming = true }
                                .buttonStyle(BubbleButtonStyle())
                                .disabled(isRunning || related == nil || model.appsBusy)
                        }
                    }
                }
                .padding(.leading, 30)
                .padding(.trailing, 10)
                .padding(.bottom, 10)
            }
        }
        .glassCard(radius: 14)
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
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .padding(.top, 4)
                Checkbox(isOn: model.selectedLeftovers.contains(group.id)) { model.toggleLeftover(group) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(SystemIntegration.appName(for: group.bundleID) ?? group.bundleID)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("\(group.bundleID) · \(group.items.count) item\(group.items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(ByteFormat.string(group.totalBytes))
                    .monospacedDigit()
            }
            .padding(10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expanded.toggle() }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.items) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
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
        .glassCard(radius: 14)
    }
}
