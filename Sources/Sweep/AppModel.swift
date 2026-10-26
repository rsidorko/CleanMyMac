import AppKit
import SweepCore

/// All app state. Lives for the lifetime of the app, so closures capture it strongly.
@MainActor
final class AppModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case clean, apps, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .clean: return "Clean"
            case .apps: return "Apps"
            case .settings: return "Settings"
            }
        }
    }

    enum ScanState: Equatable {
        case idle
        case scanning(progress: Double, current: String)
        case ready
        case cleaning(progress: Double)
        case finished
    }

    enum SelectionState {
        case all, some, none
    }

    /// One on/off card in simple mode: the safe, preselected items of a category.
    struct SimpleGroup: Identifiable {
        let category: RuleCategory
        let items: [ScanItem]
        var id: RuleCategory { category }
        var bytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
    }

    private enum Keys {
        static let profiles = "profiles"
        static let onboarded = "hasOnboarded"
        static let showFreeSpace = "showFreeSpaceInMenuBar"
        static let alwaysUseTrash = "alwaysUseTrash"
        static let proMode = "proMode"
    }

    // MARK: Settings

    @Published var profiles: Set<UsageProfile> {
        didSet {
            UserDefaults.standard.set(profiles.map(\.rawValue), forKey: Keys.profiles)
            unusedThresholdDays = Self.unusedThreshold(for: profiles)
            // Results were computed for the old profiles.
            if scanState == .ready || scanState == .finished { resetScan() }
        }
    }
    @Published var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Keys.onboarded) }
    }
    @Published var showFreeSpaceInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showFreeSpaceInMenuBar, forKey: Keys.showFreeSpace) }
    }
    @Published var alwaysUseTrash: Bool {
        didSet { UserDefaults.standard.set(alwaysUseTrash, forKey: Keys.alwaysUseTrash) }
    }
    @Published private(set) var launchesAtLogin = false
    /// Simple mode shows only safe choices; Pro shows every rule, file and setting.
    @Published var proMode: Bool {
        didSet {
            UserDefaults.standard.set(proMode, forKey: Keys.proMode)
            if !proMode && tab == .settings { tab = .clean }
        }
    }

    var visibleTabs: [Tab] { proMode ? Tab.allCases : [.clean, .apps] }

    // MARK: Clean tab

    @Published var tab: Tab = .clean
    @Published private(set) var scanState: ScanState = .idle
    @Published private(set) var report: ScanReport?
    @Published private(set) var selectedItems: Set<String> = []
    @Published private(set) var lastOutcome: CleanupOutcome?

    // MARK: Apps tab

    @Published private(set) var appsLoading = false
    @Published private(set) var appsLoaded = false
    @Published private(set) var installedApps: [InstalledApp] = []
    @Published private(set) var appSizes: [String: Int64] = [:]
    @Published private(set) var leftovers: [LeftoverGroup] = []
    @Published private(set) var selectedLeftovers: Set<String> = []
    @Published private(set) var appsBusy = false
    @Published var unusedThresholdDays: Int

    // MARK: Shared

    @Published private(set) var history: [CleanupRecord] = []
    @Published private(set) var disk: DiskUsage?
    @Published private(set) var hasFullDiskAccess = false
    @Published private(set) var suggestion: ProfileSuggestion?
    @Published var statusMessage: String?

    private let catalog: RuleCatalog
    private let historyStore = HistoryStore.standard()
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var scanTask: Task<Void, Never>?
    private var diskTimer: Timer?

    init() {
        let defaults = UserDefaults.standard
        let storedProfiles = Set((defaults.stringArray(forKey: Keys.profiles) ?? []).compactMap(UsageProfile.init(rawValue:)))
        let initialProfiles: Set<UsageProfile> = storedProfiles.isEmpty ? [.general] : storedProfiles
        profiles = initialProfiles
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        showFreeSpaceInMenuBar = defaults.bool(forKey: Keys.showFreeSpace)
        alwaysUseTrash = defaults.bool(forKey: Keys.alwaysUseTrash)
        proMode = defaults.bool(forKey: Keys.proMode)
        unusedThresholdDays = Self.unusedThreshold(for: initialProfiles)
        catalog = RuleCatalog.load(overrideURL: AppPaths.rulesOverride)

        history = historyStore.load()
        refreshDisk()
        refreshPermissions()
        diskTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in self.refreshDisk() }
        }
        detectProfiles()
    }

    private static func unusedThreshold(for profiles: Set<UsageProfile>) -> Int {
        profiles.map(\.unusedAppThresholdDays).max() ?? 90
    }

    var isBusy: Bool {
        switch scanState {
        case .scanning, .cleaning: return true
        default: return appsBusy
        }
    }

    // MARK: - System state

    func refreshDisk() {
        disk = SystemIntegration.diskUsage()
    }

    func refreshPermissions() {
        hasFullDiskAccess = SystemIntegration.hasFullDiskAccess()
        launchesAtLogin = SystemIntegration.launchesAtLogin
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try SystemIntegration.setLaunchAtLogin(enabled)
        } catch {
            statusMessage = "Couldn't change the login item: \(error.localizedDescription)"
        }
        launchesAtLogin = SystemIntegration.launchesAtLogin
    }

    func detectProfiles() {
        let home = self.home
        Task {
            let suggestion = await Task.detached(priority: .utility) {
                ProfileDetector.suggest(apps: AppInventory.userApps(home: home), home: home)
            }.value
            self.suggestion = suggestion
            if !self.hasOnboarded, !suggestion.profiles.isEmpty {
                self.profiles = Set(suggestion.profiles)
            }
        }
    }

    func toggle(_ profile: UsageProfile) {
        if profiles.contains(profile) {
            // At least one profile always stays selected.
            guard profiles.count > 1 else { return }
            profiles.remove(profile)
        } else {
            profiles.insert(profile)
        }
    }

    // MARK: - Scanning

    func startScan() {
        guard !isBusy else { return }
        lastOutcome = nil
        statusMessage = nil
        scanState = .scanning(progress: 0, current: "Preparing…")
        let scanner = Scanner(rules: catalog.rules,
                              environment: ScanEnvironment(home: home, runningBundleIDs: SystemIntegration.runningBundleIDs()))
        let profiles = self.profiles
        scanTask = Task {
            let report = await scanner.scan(profiles: profiles) { progress, current in
                Task { @MainActor in
                    guard case .scanning = self.scanState else { return }
                    self.scanState = .scanning(progress: progress, current: current)
                }
            }
            guard !Task.isCancelled else { return }
            self.apply(report)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        resetScan()
    }

    func resetScan() {
        scanTask = nil
        report = nil
        selectedItems = []
        scanState = .idle
    }

    private func apply(_ report: ScanReport) {
        self.report = report
        selectedItems = Set(report.results
            .filter { $0.policy.preselect }
            .flatMap { $0.items.filter { $0.inUseBy == nil }.map(\.id) })
        scanState = .ready
        refreshPermissions()
    }

    // MARK: - Selection

    func isSelected(_ item: ScanItem) -> Bool {
        selectedItems.contains(item.id)
    }

    func toggle(_ item: ScanItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }

    func selectionState(of result: RuleResult) -> SelectionState {
        let count = result.items.filter { selectedItems.contains($0.id) }.count
        if count == 0 { return .none }
        return count == result.items.count ? .all : .some
    }

    func toggleAll(in result: RuleResult) {
        if selectionState(of: result) == .none {
            // Selecting a whole rule still leaves data of running apps alone; those can be ticked one by one.
            selectedItems.formUnion(result.items.filter { $0.inUseBy == nil }.map(\.id))
        } else {
            selectedItems.subtract(result.items.map(\.id))
        }
    }

    /// Simple mode never offers items that need review or belong to an open app.
    var simpleGroups: [SimpleGroup] {
        guard let report else { return [] }
        return report.categories.compactMap { category in
            let items = report.results(in: category)
                .filter { $0.policy.preselect }
                .flatMap { $0.items.filter { $0.inUseBy == nil } }
            return items.isEmpty ? nil : SimpleGroup(category: category, items: items)
        }
    }

    func isOn(_ group: SimpleGroup) -> Bool {
        group.items.contains { selectedItems.contains($0.id) }
    }

    func toggle(_ group: SimpleGroup) {
        if isOn(group) {
            let all = report?.results(in: group.category).flatMap { $0.items.map(\.id) } ?? []
            selectedItems.subtract(all)
        } else {
            selectedItems.formUnion(group.items.map(\.id))
        }
    }

    /// Bytes selected, split by what happens to them.
    var selectionBreakdown: (permanent: Int64, trash: Int64, count: Int) {
        var permanent: Int64 = 0
        var trash: Int64 = 0
        var count = 0
        for result in report?.results ?? [] {
            let method = result.rule.resolvedDeletion(alwaysUseTrash: alwaysUseTrash)
            for item in result.items where selectedItems.contains(item.id) {
                count += 1
                if method == .permanent { permanent += item.bytes } else { trash += item.bytes }
            }
        }
        return (permanent, trash, count)
    }

    // MARK: - Cleaning

    func cleanSelected() {
        guard let report, !selectedItems.isEmpty, !isBusy else { return }
        let requests = report.results.flatMap { result -> [CleanupRequest] in
            let method = result.rule.resolvedDeletion(alwaysUseTrash: alwaysUseTrash)
            return result.items
                .filter { selectedItems.contains($0.id) }
                .map { CleanupRequest(url: $0.url, bytes: $0.bytes, ruleID: result.rule.id, method: method) }
        }
        scanState = .cleaning(progress: 0)
        perform(requests, reportProgress: true) { _ in
            self.report = nil
            self.selectedItems = []
            self.scanState = .finished
        }
    }

    private func perform(_ requests: [CleanupRequest], reportProgress: Bool, completion: @escaping (CleanupOutcome) -> Void) {
        let cleaner = Cleaner(safety: SafetyGuard(home: home, additionalAllowedRoots: [URL(fileURLWithPath: "/Applications")]))
        let progress: @Sendable (Double) -> Void = { fraction in
            guard reportProgress else { return }
            Task { @MainActor in self.scanState = .cleaning(progress: fraction) }
        }
        Task {
            let outcome = await Task.detached(priority: .userInitiated) {
                cleaner.clean(requests, progress: progress)
            }.value
            if !outcome.record.entries.isEmpty {
                self.historyStore.append(outcome.record)
                self.history = self.historyStore.load()
            }
            self.lastOutcome = outcome
            self.refreshDisk()
            completion(outcome)
        }
    }

    func undo(_ record: CleanupRecord) {
        let store = historyStore
        Task {
            let result = await Task.detached(priority: .userInitiated) { HistoryStore.restore(record) }.value
            store.update(result.record)
            self.history = store.load()
            if let outcome = self.lastOutcome, outcome.record.id == record.id {
                self.lastOutcome?.record = result.record
            }
            self.refreshDisk()
            var message = "Restored \(result.restored) item\(result.restored == 1 ? "" : "s")."
            if !result.failures.isEmpty { message += " \(result.failures.count) couldn't be restored." }
            self.statusMessage = message
        }
    }

    // MARK: - Apps

    var unusedApps: [InstalledApp] {
        let cutoff = Date().addingTimeInterval(-Double(unusedThresholdDays) * 86_400)
        // Apps without a recorded last-use date are left out rather than guessed at.
        return installedApps
            .filter { app in app.lastUsed.map { $0 < cutoff } ?? false }
            .sorted { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
    }

    func loadApps(force: Bool = false) {
        guard !appsLoading, force || !appsLoaded else { return }
        appsLoading = true
        let environment = ScanEnvironment(home: home, runningBundleIDs: SystemIntegration.runningBundleIDs())
        let ownBundleID = Bundle.main.bundleIdentifier
        Task {
            let (apps, leftovers) = await Task.detached(priority: .userInitiated) { () -> ([InstalledApp], [LeftoverGroup]) in
                let apps = AppInventory.userApps(home: environment.home)
                    .filter { !$0.isAppleApp && $0.bundleID != ownBundleID }
                let installedIDs = AppInventory.allInstalledBundleIDs(home: environment.home)
                let leftovers = LeftoverFinder.find(environment: environment, installedIDs: installedIDs,
                                                    safety: SafetyGuard(home: environment.home))
                return (apps, leftovers)
            }.value
            self.installedApps = apps
            self.leftovers = leftovers
            self.selectedLeftovers = []
            self.appsLoading = false
            self.appsLoaded = true
            self.computeSizes(for: self.unusedApps)
        }
    }

    func computeSizes(for apps: [InstalledApp]) {
        let missing = apps.filter { appSizes[$0.id] == nil }
        guard !missing.isEmpty else { return }
        Task {
            for app in missing {
                let bytes = await Task.detached(priority: .utility) {
                    FileStatsCalculator.stats(for: app.url).allocatedBytes
                }.value
                self.appSizes[app.id] = bytes
            }
        }
    }

    func relatedFiles(for app: InstalledApp) async -> [ScanItem] {
        let environment = ScanEnvironment(home: home)
        return await Task.detached(priority: .userInitiated) {
            UninstallPlanner.relatedFiles(for: app, environment: environment, safety: SafetyGuard(home: environment.home))
        }.value
    }

    func uninstall(_ app: InstalledApp, including files: [ScanItem]) {
        guard !isBusy else { return }
        if let id = app.bundleID, SystemIntegration.runningBundleIDs().contains(id) {
            statusMessage = "Quit \(app.name) before uninstalling it."
            return
        }
        let requests = [CleanupRequest(url: app.url, bytes: appSizes[app.id] ?? 0, ruleID: "uninstall", method: .trash)]
            + files.map { CleanupRequest(url: $0.url, bytes: $0.bytes, ruleID: "uninstall", method: .trash) }
        appsBusy = true
        perform(requests, reportProgress: false) { outcome in
            self.appsBusy = false
            if FileManager.default.fileExists(atPath: app.url.path) {
                let reason = outcome.failures.first { $0.path == app.url.path }?.reason ?? "Unknown error."
                self.statusMessage = "Couldn't move \(app.name) to the Trash: \(reason) Try dragging it to the Trash in Finder."
            } else {
                self.installedApps.removeAll { $0.id == app.id }
                self.statusMessage = "\(app.name) moved to the Trash with \(files.count) related item\(files.count == 1 ? "" : "s")."
            }
        }
    }

    /// Simple mode removes an app together with all of its support files.
    func uninstallWithSupportFiles(_ app: InstalledApp) {
        Task {
            let files = await relatedFiles(for: app)
            uninstall(app, including: files)
        }
    }

    func removeAllLeftovers() {
        selectedLeftovers = Set(leftovers.map(\.id))
        removeSelectedLeftovers()
    }

    func toggleLeftover(_ group: LeftoverGroup) {
        if selectedLeftovers.contains(group.id) {
            selectedLeftovers.remove(group.id)
        } else {
            selectedLeftovers.insert(group.id)
        }
    }

    var selectedLeftoverBytes: Int64 {
        leftovers.filter { selectedLeftovers.contains($0.id) }.reduce(0) { $0 + $1.totalBytes }
    }

    func removeSelectedLeftovers() {
        guard !isBusy else { return }
        let groups = leftovers.filter { selectedLeftovers.contains($0.id) }
        let requests = groups.flatMap { group in
            group.items.map { CleanupRequest(url: $0.url, bytes: $0.bytes, ruleID: "app-leftovers", method: .trash) }
        }
        guard !requests.isEmpty else { return }
        appsBusy = true
        perform(requests, reportProgress: false) { outcome in
            self.appsBusy = false
            let removedIDs = Set(groups.map(\.id))
            self.leftovers.removeAll { removedIDs.contains($0.id) }
            self.selectedLeftovers = []
            self.statusMessage = "Moved \(ByteFormat.string(outcome.trashedBytes)) of leftovers to the Trash."
                + (outcome.failures.isEmpty ? "" : " \(outcome.failures.count) item(s) couldn't be moved.")
        }
    }
}
