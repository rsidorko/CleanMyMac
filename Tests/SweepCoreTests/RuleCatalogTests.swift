import XCTest
@testable import SweepCore

final class RuleCatalogTests: XCTestCase {
    func testBuiltInRulesDecode() throws {
        let catalog = try RuleCatalog.builtIn()
        XCTAssertGreaterThan(catalog.rules.count, 20)
    }

    func testRuleIDsAreUnique() throws {
        let ids = try RuleCatalog.builtIn().rules.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testPathsAreInsideHome() throws {
        for rule in try RuleCatalog.builtIn().rules {
            for path in rule.paths {
                XCTAssertTrue(path.hasPrefix("~/"), "\(rule.id): \(path)")
            }
        }
    }

    func testProfileModeKeysAreKnownProfiles() throws {
        let known = Set(UsageProfile.allCases.map(\.rawValue))
        for rule in try RuleCatalog.builtIn().rules {
            for key in (rule.profileModes ?? [:]).keys {
                XCTAssertTrue(known.contains(key), "\(rule.id) uses unknown profile \(key)")
            }
        }
    }

    func testNestedRulesNameWhatTheyLookFor() throws {
        for rule in try RuleCatalog.builtIn().rules where rule.match.kind == .nested {
            XCTAssertNotNil(rule.match.nestedName, rule.id)
        }
    }

    func testRuleRootsPassTheSafetyGuardChildCheck() throws {
        let home = URL(fileURLWithPath: "/Users/tester")
        let environment = ScanEnvironment(home: home)
        let safety = SafetyGuard(home: home)
        for rule in try RuleCatalog.builtIn().rules {
            for path in rule.paths {
                // Something inside each rule root must be removable; the root itself may be protected.
                let child = environment.expand(path).appendingPathComponent("example-item")
                XCTAssertNil(safety.check(child), "\(rule.id): \(path)")
            }
        }
    }
}
