import XCTest
@testable import SweepCore

final class SafetyGuardTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/tester")
    private var safety: SafetyGuard { SafetyGuard(home: home) }

    func testAllowsCacheFolders() {
        XCTAssertNil(safety.check(home.appendingPathComponent("Library/Caches/com.example.App")))
    }

    func testRejectsPathsOutsideHome() {
        XCTAssertEqual(safety.check(URL(fileURLWithPath: "/System/Library/Caches/x")),
                       .outsideAllowedLocations("/System/Library/Caches/x"))
    }

    func testRejectsTopLevelFolders() {
        XCTAssertNotNil(safety.check(home.appendingPathComponent("Documents")))
        XCTAssertNotNil(safety.check(home.appendingPathComponent("Library/Caches")))
    }

    func testRejectsProtectedData() {
        XCTAssertNotNil(safety.check(home.appendingPathComponent("Library/Keychains/login.keychain-db")))
        XCTAssertNotNil(safety.check(home.appendingPathComponent(".ssh/id_ed25519")))
        XCTAssertNotNil(safety.check(home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/a")))
    }

    func testRejectsPhotoLibraries() {
        XCTAssertNotNil(safety.check(home.appendingPathComponent("Pictures/Photos Library.photoslibrary")))
    }

    func testApplicationsNeedsExplicitPermission() {
        let app = URL(fileURLWithPath: "/Applications/Example.app")
        XCTAssertNotNil(safety.check(app))
        XCTAssertNil(SafetyGuard(home: home, additionalAllowedRoots: [URL(fileURLWithPath: "/Applications")]).check(app))
    }
}
