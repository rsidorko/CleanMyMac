import Foundation

public struct CleanupRequest: Sendable, Hashable {
    public let url: URL
    public let bytes: Int64
    public let ruleID: String
    /// `.trash` or `.permanent`; `.automatic` is treated as `.trash`.
    public let method: DeletionMethod

    public init(url: URL, bytes: Int64, ruleID: String, method: DeletionMethod) {
        self.url = url
        self.bytes = bytes
        self.ruleID = ruleID
        self.method = method
    }
}

public struct CleanupFailure: Sendable, Hashable, Identifiable {
    public var id: String { path }
    public let path: String
    public let reason: String
}

public struct CleanupRecord: Codable, Identifiable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Hashable {
        public let originalPath: String
        /// Where the item went in the Trash; nil when it was deleted permanently or has been restored.
        public var trashedPath: String?
        public let bytes: Int64
        public let ruleID: String
    }

    public let id: UUID
    public let date: Date
    public var entries: [Entry]

    public var totalBytes: Int64 { entries.reduce(0) { $0 + $1.bytes } }
    public var restorableEntries: [Entry] { entries.filter { $0.trashedPath != nil } }
}

public struct CleanupOutcome: Sendable {
    /// Space freed immediately by permanent deletion.
    public var freedBytes: Int64 = 0
    /// Space that will be freed once the Trash is emptied.
    public var trashedBytes: Int64 = 0
    public var failures: [CleanupFailure] = []
    public var record: CleanupRecord
}

public protocol FileRemoving: Sendable {
    /// Moves the item to the Trash and returns its new location.
    func moveToTrash(_ url: URL) throws -> URL?
    func removePermanently(_ url: URL) throws
}

public struct FileManagerRemover: FileRemoving {
    public init() {}

    public func moveToTrash(_ url: URL) throws -> URL? {
        #if os(macOS)
        var resulting: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
        return resulting as URL?
        #else
        try FileManager.default.removeItem(at: url)
        return nil
        #endif
    }

    public func removePermanently(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}

public struct Cleaner: Sendable {
    public let safety: SafetyGuard
    public let remover: any FileRemoving

    public init(safety: SafetyGuard, remover: any FileRemoving = FileManagerRemover()) {
        self.safety = safety
        self.remover = remover
    }

    public func clean(_ requests: [CleanupRequest], progress: (@Sendable (Double) -> Void)? = nil) -> CleanupOutcome {
        var outcome = CleanupOutcome(record: CleanupRecord(id: UUID(), date: Date(), entries: []))
        let fm = FileManager.default

        for (index, request) in requests.enumerated() {
            defer { progress?(Double(index + 1) / Double(requests.count)) }
            let path = request.url.path

            // Already gone (the owning app may have cleared it since the scan). attributesOfItem doesn't
            // follow symlinks, so a dangling link still counts as present.
            guard (try? fm.attributesOfItem(atPath: path)) != nil else { continue }

            // Checked again here, not just at scan time, in case something changed in between.
            if let violation = safety.check(request.url) {
                outcome.failures.append(CleanupFailure(path: path, reason: violation.description))
                continue
            }

            do {
                switch request.method {
                case .permanent:
                    try remover.removePermanently(request.url)
                    outcome.freedBytes += request.bytes
                    outcome.record.entries.append(.init(originalPath: path, trashedPath: nil, bytes: request.bytes, ruleID: request.ruleID))
                case .trash, .automatic:
                    let trashed = try remover.moveToTrash(request.url)
                    outcome.trashedBytes += request.bytes
                    outcome.record.entries.append(.init(originalPath: path, trashedPath: trashed?.path, bytes: request.bytes, ruleID: request.ruleID))
                }
            } catch {
                outcome.failures.append(CleanupFailure(path: path, reason: error.localizedDescription))
            }
        }
        return outcome
    }
}
