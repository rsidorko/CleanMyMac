import Foundation

/// Keeps a log of past cleanups so anything moved to the Trash can be put back.
public struct HistoryStore: Sendable {
    public let fileURL: URL
    public let limit: Int

    public init(fileURL: URL, limit: Int = 30) {
        self.fileURL = fileURL
        self.limit = limit
    }

    public static func standard() -> HistoryStore {
        HistoryStore(fileURL: AppPaths.supportDirectory.appendingPathComponent("history.json"))
    }

    /// Newest first.
    public func load() -> [CleanupRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([CleanupRecord].self, from: data)) ?? []
    }

    public func append(_ record: CleanupRecord) {
        save([record] + load())
    }

    public func update(_ record: CleanupRecord) {
        save(load().map { $0.id == record.id ? record : $0 })
    }

    private func save(_ records: [CleanupRecord]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(Array(records.prefix(limit))) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Moves trashed items back to where they came from. Items that were emptied from the Trash, or whose
    /// original location is occupied again, are reported as failures.
    public static func restore(_ record: CleanupRecord) -> (record: CleanupRecord, restored: Int, failures: [CleanupFailure]) {
        let fm = FileManager.default
        var updated = record
        var restored = 0
        var failures: [CleanupFailure] = []

        for index in updated.entries.indices {
            guard let trashedPath = updated.entries[index].trashedPath else { continue }
            let original = URL(fileURLWithPath: updated.entries[index].originalPath)
            guard fm.fileExists(atPath: trashedPath) else {
                failures.append(CleanupFailure(path: original.path, reason: "No longer in the Trash."))
                updated.entries[index].trashedPath = nil
                continue
            }
            guard !fm.fileExists(atPath: original.path) else {
                failures.append(CleanupFailure(path: original.path, reason: "Something new already exists at the original location."))
                continue
            }
            do {
                try fm.createDirectory(at: original.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: URL(fileURLWithPath: trashedPath), to: original)
                updated.entries[index].trashedPath = nil
                restored += 1
            } catch {
                failures.append(CleanupFailure(path: original.path, reason: error.localizedDescription))
            }
        }
        return (updated, restored, failures)
    }
}

public enum AppPaths {
    public static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Sweep", isDirectory: true)
    }

    /// Optional JSON file with extra or replacement rules (same format as `DefaultRules`).
    public static var rulesOverride: URL {
        supportDirectory.appendingPathComponent("rules.json")
    }
}
