import XCTest
@testable import SweepCore

final class BundleIDTests: XCTestCase {
    func testRecognizesBundleIDs() {
        XCTAssertTrue(BundleID.looksLikeBundleID("com.spotify.client"))
        XCTAssertFalse(BundleID.looksLikeBundleID("Google"))
        XCTAssertFalse(BundleID.looksLikeBundleID("com.example"))
    }

    func testNormalizesLibraryEntryNames() {
        XCTAssertEqual(BundleID.normalize("com.example.App.plist"), "com.example.App")
        XCTAssertEqual(BundleID.normalize("com.example.App.savedState"), "com.example.App")
        XCTAssertEqual(BundleID.normalize("group.com.example.App"), "com.example.App")
        XCTAssertEqual(BundleID.normalize("ABCDE12345.com.example.App"), "com.example.App")
    }

    func testPrefixPatterns() {
        XCTAssertTrue(BundleID.matches("com.jetbrains.intellij", pattern: "com.jetbrains."))
        XCTAssertFalse(BundleID.matches("com.jetbrainsx.tool", pattern: "com.jetbrains."))
        XCTAssertTrue(BundleID.matches("COM.Example.App", pattern: "com.example.app"))
    }

    func testLeftoversNeedAnUnknownVendor() {
        let installed: Set<String> = ["com.microsoft.Word", "com.spotify.client"]
        XCTAssertTrue(LeftoverFinder.isOrphaned("com.evernote.Evernote", installedIDs: installed))
        XCTAssertFalse(LeftoverFinder.isOrphaned("com.microsoft.Teams", installedIDs: installed))
        XCTAssertFalse(LeftoverFinder.isOrphaned("com.apple.Safari", installedIDs: installed))
    }
}
