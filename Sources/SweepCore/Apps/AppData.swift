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

/// Finds everything an app keeps outside its bundle, so uninstalling leaves nothing behind.
public enum UninstallPlanner {
    /// Folders in ~/Library where apps keep data, usually in an entry named after their bundle identifier.
    static let locations = [
        "Library/Application Support", "Library/Application Scripts", "Library/Caches", "Library/Containers",
        "Library/Group Containers", "Library/Preferences", "Library/Preferences/ByHost", "Library/Saved Application State",
        "Library/HTTPStorages", "Library/WebKit", "Library/Logs", "Library/LaunchAgents",
    ]
    /// Folders where apps often use their name instead, e.g. "~/Library/Application Support/Code".
    static let nameLocations: Set<String> = ["Library/Application Support", "Library/Caches", "Library/Logs"]
    /// Folders where sandboxed apps share data under their team identifier, e.g. "UBF8T346G9.Office".
    static let teamLocations: Set<String> = ["Library/Group Containers", "Library/Application Scripts"]

    /// - Parameter otherApps: The other installed apps. Data under the app's team identifier is only included
    ///   when none of them comes from the same team, since suites (Office, Adobe) share it between apps.
    public static func relatedFiles(for app: InstalledApp, otherApps: [InstalledApp] = [], environment: ScanEnvironment,
                                    safety: SafetyGuard) -> [ScanItem] {
        guard let bundleID = app.bundleID?.lowercased(), !app.isAppleApp else { return [] }
        // Login items, extensions and XPC services have their own identifiers and their own data. Ones from another
        // vendor belong to a bundled framework (e.g. Sparkle) whose data other apps share.
        let vendor = BundleID.vendor(of: bundleID)
        let ids = Set([bundleID] + AppInventory.embeddedBundleIDs(of: app.url).filter { BundleID.vendor(of: $0) == vendor })
        let names = Set([app.name, app.bundleName].compactMap { $0 }.filter { $0.count >= 3 }.map { $0.lowercased() })
        let teamID = CodeSignature.teamID(of: app.url).flatMap { team in
            otherApps.contains { $0.url != app.url && CodeSignature.teamID(of: $0.url) == team } ? nil : team
        }
        let fm = FileManager.default
        var seen: Set<String> = []
        var items: [ScanItem] = []

        func add(_ url: URL, ownerID: String) {
            guard seen.insert(url.path).inserted, safety.check(url) == nil else { return }
            let stats = FileStatsCalculator.stats(for: url)
            items.append(ScanItem(
                url: url, ruleID: "uninstall", displayName: url.lastPathComponent, location: environment.abbreviate(url),
                bytes: stats.allocatedBytes, fileCount: stats.fileCount, lastModified: stats.newestModification,
                ownerBundleIDs: [ownerID]))
        }

        for location in locations {
            let root = environment.home.appendingPathComponent(location)
            guard let entries = try? fm.contentsOfDirectory(atPath: root.path) else { continue }
            for entry in entries {
                let normalized = BundleID.normalize(entry).lowercased()
                // Helpers and ByHost preferences use "<bundle id>.<suffix>".
                let matchesID = ids.contains { normalized == $0 || normalized.hasPrefix($0 + ".") }
                let matchesName = nameLocations.contains(location) && names.contains(entry.lowercased())
                let matchesTeam = teamLocations.contains(location) && teamID.map { entry.hasPrefix($0 + ".") } == true
                guard matchesID || matchesName || matchesTeam else { continue }
                add(root.appendingPathComponent(entry), ownerID: bundleID)
            }
        }

        // Crash reports are files named "<App>-<date>.ips" or "<App>_<date>_<host>.crash".
        let reports = environment.home.appendingPathComponent("Library/Logs/DiagnosticReports")
        for entry in (try? fm.contentsOfDirectory(atPath: reports.path)) ?? [] {
            let lowered = entry.lowercased()
            if names.contains(where: { lowered.hasPrefix($0 + "-") || lowered.hasPrefix($0 + "_") }) {
                add(reports.appendingPathComponent(entry), ownerID: bundleID)
            }
        }

        return items.sorted { $0.bytes > $1.bytes }
    }
}
