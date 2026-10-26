import XCTest
@testable import SweepCore

final class CleanerTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("SweepCleanerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        home = home.resolvingSymlinksInPath()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private struct RecordingRemover: FileRemoving {
        func moveToTrash(_ url: URL) throws -> URL? {
            let trashed = url.deletingLastPathComponent().appendingPathComponent("trashed-" + url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: trashed)
            return trashed
        }

        func removePermanently(_ url: URL) throws {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func makeItem(_ path: String) throws -> URL {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: 1000).write(to: url)
        return url
    }

    func testDeletesPermanently() throws {
        let url = try makeItem("Library/Caches/com.example.App")
        let cleaner = Cleaner(safety: SafetyGuard(home: home), remover: RecordingRemover())
        let outcome = cleaner.clean([CleanupRequest(url: url, bytes: 1000, ruleID: "caches", method: .permanent)])

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(outcome.freedBytes, 1000)
        XCTAssertTrue(outcome.failures.isEmpty)
    }

    func testTrashedItemsCanBeRestored() throws {
        let url = try makeItem("Downloads/Installer.dmg")
        let cleaner = Cleaner(safety: SafetyGuard(home: home), remover: RecordingRemover())
        let outcome = cleaner.clean([CleanupRequest(url: url, bytes: 1000, ruleID: "installers", method: .trash)])

        XCTAssertEqual(outcome.trashedBytes, 1000)
        XCTAssertEqual(outcome.record.restorableEntries.count, 1)
    }

    func testRefusesProtectedPaths() throws {
        let url = try makeItem("Library/Keychains/login.keychain-db")
        let cleaner = Cleaner(safety: SafetyGuard(home: home), remover: RecordingRemover())
        let outcome = cleaner.clean([CleanupRequest(url: url, bytes: 1000, ruleID: "bad", method: .permanent)])

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(outcome.failures.count, 1)
    }
}
