import XCTest
@testable import SweepCore

final class UninstallPlannerTests: XCTestCase {
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

    private func makeFile(_ path: String) throws {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: 4096).write(to: url)
    }

    private func makeBundle(_ path: String, id: String) throws -> URL {
        let url = home.appendingPathComponent(path)
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id], format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        return url
    }

    func testFindsDataByIdentifierNameAndHelpers() throws {
        let appURL = try makeBundle("Applications/Notely.app", id: "com.example.Notely")
        _ = try makeBundle("Applications/Notely.app/Contents/Library/LoginItems/Launcher.app", id: "com.example.NotelyLauncher")
        _ = try makeBundle("Applications/Notely.app/Contents/XPCServices/Updater.xpc", id: "org.sparkle-project.Downloader")

        try makeFile("Library/Containers/com.example.Notely/data")
        try makeFile("Library/Containers/com.example.Notely.ShareExtension/data")
        try makeFile("Library/Preferences/com.example.Notely.plist")
        try makeFile("Library/Preferences/ByHost/com.example.Notely.0123-4567.plist")
        try makeFile("Library/Group Containers/group.com.example.Notely/data")
        try makeFile("Library/Caches/com.example.NotelyLauncher/data")
        try makeFile("Library/Application Support/Notely/data")
        try makeFile("Library/Logs/DiagnosticReports/Notely-2026-01-01-120000.ips")
        // Not this app's.
        try makeFile("Library/Preferences/com.example.NotelyPro.plist")
        try makeFile("Library/Caches/org.sparkle-project.Downloader/data")
        try makeFile("Library/Application Support/Notes/data")

        let app = InstalledApp(url: appURL, name: "Notely", bundleName: "Notely", bundleID: "com.example.Notely",
                               version: "1.0", lastUsed: nil)
        let items = UninstallPlanner.relatedFiles(for: app, environment: ScanEnvironment(home: home),
                                                  safety: SafetyGuard(home: home))
        let found = Set(items.map { ScanEnvironment(home: home).abbreviate($0.url) })

        XCTAssertEqual(found, [
            "~/Library/Containers/com.example.Notely",
            "~/Library/Containers/com.example.Notely.ShareExtension",
            "~/Library/Preferences/com.example.Notely.plist",
            "~/Library/Preferences/ByHost/com.example.Notely.0123-4567.plist",
            "~/Library/Group Containers/group.com.example.Notely",
            "~/Library/Caches/com.example.NotelyLauncher",
            "~/Library/Application Support/Notely",
            "~/Library/Logs/DiagnosticReports/Notely-2026-01-01-120000.ips",
        ])
    }

    func testSkipsAppleApps() throws {
        try makeFile("Library/Containers/com.apple.Notes/data")
        let app = InstalledApp(url: home.appendingPathComponent("Applications/Notes.app"), name: "Notes", bundleName: "Notes",
                               bundleID: "com.apple.Notes", version: nil, lastUsed: nil)
        XCTAssertTrue(UninstallPlanner.relatedFiles(for: app, environment: ScanEnvironment(home: home),
                                                    safety: SafetyGuard(home: home)).isEmpty)
    }
}
