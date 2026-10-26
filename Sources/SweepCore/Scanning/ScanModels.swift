import Foundation

public struct ScanEnvironment: Sendable {
    public var home: URL
    public var now: Date
    /// Bundle identifiers of apps running when the scan started.
    public var runningBundleIDs: Set<String>

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, now: Date = Date(),
                runningBundleIDs: Set<String> = []) {
        self.home = home
        self.now = now
        self.runningBundleIDs = runningBundleIDs
    }

    /// Expands a leading `~/` to the home folder.
    public func expand(_ path: String) -> URL {
        if path == "~" { return home }
        if path.hasPrefix("~/") { return home.appendingPathComponent(String(path.dropFirst(2)), isDirectory: true) }
        return URL(fileURLWithPath: path)
    }

    /// The inverse of `expand`, for display.
    public func abbreviate(_ url: URL) -> String {
        let path = url.path
        let home = home.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}

public struct ScanItem: Identifiable, Hashable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let ruleID: String
    public let displayName: String
    /// Abbreviated path for display.
    public let location: String
    public let bytes: Int64
    public let fileCount: Int
    public let lastModified: Date?
    /// Apps this data belongs to, when known.
    public let ownerBundleIDs: [String]
    /// The running app this data belongs to, if any. Such items are never pre-selected.
    public let inUseBy: String?

    public init(url: URL, ruleID: String, displayName: String, location: String, bytes: Int64, fileCount: Int,
                lastModified: Date?, ownerBundleIDs: [String] = [], inUseBy: String? = nil) {
        self.url = url
        self.ruleID = ruleID
        self.displayName = displayName
        self.location = location
        self.bytes = bytes
        self.fileCount = fileCount
        self.lastModified = lastModified
        self.ownerBundleIDs = ownerBundleIDs
        self.inUseBy = inUseBy
    }
}

public struct RuleResult: Identifiable, Sendable {
    public var id: String { rule.id }
    public let rule: CleanupRule
    public let policy: ResolvedPolicy
    /// Largest first.
    public let items: [ScanItem]
    /// Items left alone because they were used more recently than the policy's age limit.
    public let skippedRecentCount: Int

    public var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

public struct ScanReport: Sendable {
    /// Rules that found something, ordered by category and then size.
    public let results: [RuleResult]
    /// Folders that exist but couldn't be read, usually because Full Disk Access hasn't been granted.
    public let unreadableLocations: [String]
    public let profiles: Set<UsageProfile>
    public let duration: TimeInterval

    public var totalBytes: Int64 { results.reduce(0) { $0 + $1.totalBytes } }

    public var categories: [RuleCategory] {
        RuleCategory.allCases.filter { category in results.contains { $0.rule.category == category } }
    }

    public func results(in category: RuleCategory) -> [RuleResult] {
        results.filter { $0.rule.category == category }
    }
}
