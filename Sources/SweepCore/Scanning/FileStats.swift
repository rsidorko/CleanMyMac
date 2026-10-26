import Foundation

public struct FileStats: Sendable, Equatable {
    /// Space actually used on disk (APFS allocated size), not the logical file length.
    public var allocatedBytes: Int64
    public var fileCount: Int
    /// The most recent modification anywhere inside the item.
    public var newestModification: Date?
}

public enum FileStatsCalculator {
    private static let keys: [URLResourceKey] = [
        .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .contentModificationDateKey,
    ]

    /// Walks `url` once, collecting size and freshness together. Symlinks are counted but not followed.
    public static func stats(for url: URL) -> FileStats {
        var stats = FileStats(allocatedBytes: 0, fileCount: 0, newestModification: nil)
        let keySet = Set(keys)

        func visit(_ item: URL) {
            guard let values = try? item.resourceValues(forKeys: keySet) else { return }
            if let date = values.contentModificationDate, date > (stats.newestModification ?? .distantPast) {
                stats.newestModification = date
            }
            if values.isRegularFile == true || values.isSymbolicLink == true {
                stats.allocatedBytes += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                stats.fileCount += 1
            }
        }

        visit(url)
        let rootValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard rootValues?.isDirectory == true, rootValues?.isSymbolicLink != true,
              let enumerator = FileManager.default.enumerator(
                  at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true })
        else { return stats }

        for case let child as URL in enumerator {
            visit(child)
        }
        return stats
    }

    /// Newest modification among the other entries next to `url` (not recursive).
    static func newestSiblingModification(of url: URL) -> Date? {
        let parent = url.deletingLastPathComponent()
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: parent.path) else { return nil }
        return names
            .filter { $0 != url.lastPathComponent && $0 != ".DS_Store" }
            .compactMap { try? parent.appendingPathComponent($0).resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
    }
}
