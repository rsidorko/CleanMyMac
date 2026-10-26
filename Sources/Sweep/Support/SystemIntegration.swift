import AppKit
import ServiceManagement

struct DiskUsage: Equatable {
    let total: Int64
    let available: Int64

    var used: Int64 { max(total - available, 0) }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

/// Thin wrappers over macOS APIs the core library deliberately doesn't depend on.
@MainActor
enum SystemIntegration {
    static func runningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    static func diskUsage() -> DiskUsage? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return DiskUsage(total: Int64(total), available: available)
    }

    /// macOS has no API to ask whether Full Disk Access was granted; reading files it protects is the
    /// standard probe.
    static func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let tccDatabase = home.appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        if let handle = try? FileHandle(forReadingFrom: tccDatabase) {
            try? handle.close()
            return true
        }
        return (try? FileManager.default.contentsOfDirectory(atPath: home.appendingPathComponent("Library/Safari").path)) != nil
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Relaunching only makes sense from the .app bundle; `swift run` and scripts/dev.sh run a bare binary.
    static var canRelaunch: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Quits and reopens the app. macOS sometimes applies a newly granted Full Disk Access only to new processes.
    static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Waits for this copy to exit, then opens the bundle again.
        process.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; open \"$0\"",
                             Bundle.main.bundlePath]
        guard (try? process.run()) != nil else { return }
        NSApp.terminate(nil)
    }

    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func openTrash() {
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash"))
    }

    // MARK: App names and icons

    private static var appURLCache: [String: URL?] = [:]

    static func appURL(for bundleID: String) -> URL? {
        if let cached = appURLCache[bundleID] { return cached }
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        appURLCache[bundleID] = url
        return url
    }

    static func appName(for bundleID: String) -> String? {
        appURL(for: bundleID).map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
    }

    static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    // MARK: Launch at login (only works when running from the .app bundle)

    static var launchesAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

enum DateFormat {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static func relative(_ date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

extension String {
    /// "yesterday" → "Yesterday", for relative dates that start a line.
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
