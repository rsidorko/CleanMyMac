import XCTest
@testable import SweepCore

final class ScannerTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("SweepTests-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        home = home.resolvingSymlinksInPath()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func makeFile(_ path: String, bytes: Int = 4096, daysOld: Double) throws {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
        try setAge(path, daysOld: daysOld)
    }

    private func setAge(_ path: String, daysOld: Double) throws {
        let date = Date().addingTimeInterval(-daysOld * 86_400)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: home.appendingPathComponent(path).path)
    }

    private func logsRule() -> CleanupRule {
        CleanupRule(id: "logs", name: "Logs", summary: "", category: .system, paths: ["~/Library/Logs"],
                    match: MatchSpec(kind: .contents), safety: .safe, regenerates: true, regenCost: .low, minAgeDays: 7)
    }

    func testSkipsRecentlyModifiedItems() async throws {
        try makeFile("Library/Logs/old.log", daysOld: 30)
        try makeFile("Library/Logs/new.log", daysOld: 1)

        let scanner = Scanner(rules: [logsRule()], environment: ScanEnvironment(home: home))
        let report = await scanner.scan(profiles: [.general])

        let result = try XCTUnwrap(report.results.first)
        XCTAssertEqual(result.items.map(\.displayName), ["old.log"])
        XCTAssertEqual(result.skippedRecentCount, 1)
        XCTAssertGreaterThan(result.totalBytes, 0)
    }

    func testFlagsItemsOfRunningApps() async throws {
        try makeFile("Library/Caches/com.example.Editor/blob", daysOld: 3)
        try setAge("Library/Caches/com.example.Editor", daysOld: 3)
        let rule = CleanupRule(id: "caches", name: "Caches", summary: "", category: .system, paths: ["~/Library/Caches"],
                               match: MatchSpec(kind: .contents), safety: .safe, regenerates: true, regenCost: .low,
                               minAgeDays: 0)

        let environment = ScanEnvironment(home: home, runningBundleIDs: ["com.example.Editor"])
        let report = await Scanner(rules: [rule], environment: environment).scan(profiles: [.general])

        let item = try XCTUnwrap(report.results.first?.items.first)
        XCTAssertEqual(item.inUseBy, "com.example.Editor")
    }
}
