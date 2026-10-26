import XCTest
@testable import SweepCore

final class PolicyResolverTests: XCTestCase {
    private func rule(category: RuleCategory, cost: RegenerationCost = .medium, minAge: Int = 30,
                      safety: Safety = .safe, modes: [String: PolicyMode]? = nil) -> CleanupRule {
        CleanupRule(id: "test", name: "Test", summary: "", category: category, paths: ["~/Library/Caches"],
                    match: MatchSpec(kind: .contents), safety: safety, regenerates: true, regenCost: cost,
                    minAgeDays: minAge, profileModes: modes)
    }

    func testSystemRulesUseStandardMode() {
        let policy = PolicyResolver.resolve(rule(category: .system), profiles: [.developer])
        XCTAssertEqual(policy.mode, .standard)
        XCTAssertEqual(policy.minAgeDays, 30)
        XCTAssertTrue(policy.preselect)
    }

    func testOtherProfilesDataIsCleanedAggressively() {
        let policy = PolicyResolver.resolve(rule(category: .creative, cost: .high), profiles: [.developer])
        XCTAssertEqual(policy.mode, .aggressive)
        XCTAssertEqual(policy.minAgeDays, 15)
        XCTAssertTrue(policy.preselect)
    }

    func testOwnDataIsTreatedCarefully() {
        let policy = PolicyResolver.resolve(rule(category: .creative), profiles: [.creative])
        XCTAssertEqual(policy.mode, .careful)
        XCTAssertEqual(policy.minAgeDays, 60)
        XCTAssertFalse(policy.preselect)
    }

    func testMostConservativeProfileWins() {
        let policy = PolicyResolver.resolve(rule(category: .creative), profiles: [.developer, .creative])
        XCTAssertEqual(policy.mode, .careful)
    }

    func testProtectNeverPreselects() {
        let policy = PolicyResolver.resolve(rule(category: .gaming, cost: .low, modes: ["gamer": .protect]), profiles: [.gamer])
        XCTAssertEqual(policy.mode, .protect)
        XCTAssertFalse(policy.preselect)
    }

    func testReviewRulesAreNeverPreselected() {
        let policy = PolicyResolver.resolve(rule(category: .system, cost: .low, safety: .review), profiles: [.general])
        XCTAssertFalse(policy.preselect)
    }
}
