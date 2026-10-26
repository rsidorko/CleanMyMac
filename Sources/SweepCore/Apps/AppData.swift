import Foundation

/// Data in ~/Library left behind by an app that is no longer installed.
public struct LeftoverGroup: Identifiable, Sendable, Hashable {
    public var id: String { bundleID }
    public let bundleID: String
    public let items: [ScanItem]

    public var totalBytes: Int64 { items.reduce(0) { $0 + $1.bytes } }
}

public enum LeftoverFinder {
    static let locations = [
        "Library/Application Support", "Library/Containers", "Library/Group Containers", "Library/Preferences",
        "Library/Saved Application State", "Library/HTTPStorages", "Library/WebKit",
    ]

    /// Data is only considered orphaned when no installed or running app comes from the same vendor:
    /// suites share data between apps and helpers have their own identifiers, so matching by exact
    /// identifier would flag things that are still in use.
    public static func isOrphaned(_ id: String, installedIDs: Set<String>, runningIDs: Set<String> = []) -> Bool {
        let id = id.lowercased()
        if id.contains("com.apple.") || id.hasPrefix("apple.") { return false }
        let vendor = BundleID.vendor(of: id)
        let known = installedIDs.union(runningIDs.map { $0.lowercased() })
        return !known.contains { BundleID.vendor(of: $0) == vendor }
    }

    public static func find(environment: ScanEnvironment, installedIDs: Set<String>, safety: SafetyGuard,
                            minimumAgeDays: Int = 30) -> [LeftoverGroup] {
        // If we couldn't see the installed apps (Spotlight off, no access), everything would look orphaned.
        guard installedIDs.count >= 10 else { return [] }
        let fm = FileManager.default
        let cutoff = environment.now.addingTimeInterval(-Double(minimumAgeDays) * 86_400)
        var byID: [String: [ScanItem]] = [:]

        for location in locations {
            let root = environment.home.appendingPathComponent(location)
            guard let names = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
            for name in names {
                let id = BundleID.normalize(name)
                guard BundleID.looksLikeBundleID(id),
                      isOrphaned(id, installedIDs: installedIDs, runningIDs: environment.runningBundleIDs) else { continue }
                let url = root.appendingPathComponent(name)
                guard safety.check(url) == nil else { continue }
                let stats = FileStatsCalculator.stats(for: url)
                // Recently written data means something is still using it (a CLI tool, a background agent).
                if let modified = stats.newestModification, modified > cutoff { continue }
                guard stats.allocatedBytes > 0 else { continue }
                byID[id.lowercased(), default: []].append(ScanItem(
                    url: url, ruleID: "app-leftovers",
                    displayName: location.replacingOccurrences(of: "Library/", with: ""),
                    location: environment.abbreviate(url), bytes: stats.allocatedBytes, fileCount: stats.fileCount,
                    lastModified: stats.newestModification, ownerBundleIDs: [id]))
            }
        }

        return byID
            .map { LeftoverGroup(bundleID: $0.key, items: $0.value.sorted { $0.bytes > $1.bytes }) }
            .sorted { $0.totalBytes > $1.totalBytes }
    }
}

/// Finds the files an app keeps outside its bundle, so uninstalling removes all of it.
public enum UninstallPlanner {
    static let locations = [
        "Library/Application Support", "Library/Caches", "Library/Containers", "Library/Group Containers",
        "Library/Preferences", "Library/Preferences/ByHost", "Library/Saved Application State",
        "Library/HTTPStorages", "Library/WebKit", "Library/Logs", "Library/LaunchAgents",
    ]

    public static func relatedFiles(for app: InstalledApp, environment: ScanEnvironment, safety: SafetyGuard) -> [ScanItem] {
        guard let bundleID = app.bundleID?.lowercased(), !app.isAppleApp else { return [] }
        let names = [app.name, app.bundleName].compactMap { $0 }
        let fm = FileManager.default
        var items: [ScanItem] = []

        for location in locations {
            let root = environment.home.appendingPathComponent(location)
            guard let entries = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
            for entry in entries {
                let normalized = BundleID.normalize(entry).lowercased()
                // Helpers and ByHost preferences use "<bundle id>.<suffix>".
                let matchesID = normalized == bundleID || normalized.hasPrefix(bundleID + ".")
                let matchesName = location == "Library/Application Support"
                    && names.contains { $0.caseInsensitiveCompare(entry) == .orderedSame }
                guard matchesID || matchesName else { continue }
                let url = root.appendingPathComponent(entry)
                guard safety.check(url) == nil else { continue }
                let stats = FileStatsCalculator.stats(for: url)
                items.append(ScanItem(
                    url: url, ruleID: "uninstall", displayName: entry, location: environment.abbreviate(url),
                    bytes: stats.allocatedBytes, fileCount: stats.fileCount, lastModified: stats.newestModification,
                    ownerBundleIDs: [bundleID]))
            }
        }
        return items.sorted { $0.bytes > $1.bytes }
    }
}
