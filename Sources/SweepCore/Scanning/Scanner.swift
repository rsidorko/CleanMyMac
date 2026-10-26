import Foundation

/// Finds reclaimable space by evaluating cleanup rules against the file system.
///
/// Only the locations named by rules are visited, which is what makes a scan take seconds rather than
/// walking the whole disk. Rules run concurrently in two phases: specific rules first, then broad
/// catch-all rules (priority <= 0) that skip anything a specific rule already claimed, so nothing is
/// counted twice and specialised policies (like "protect shader caches") can't be bypassed.
public struct Scanner: Sendable {
    public let rules: [CleanupRule]
    public let environment: ScanEnvironment
    public let safety: SafetyGuard

    public init(rules: [CleanupRule], environment: ScanEnvironment) {
        self.rules = rules
        self.environment = environment
        self.safety = SafetyGuard(home: environment.home)
    }

    public func scan(profiles: Set<UsageProfile>,
                     progress: (@Sendable (_ fraction: Double, _ ruleName: String) -> Void)? = nil) async -> ScanReport {
        let started = Date()
        let planned = rules
            .map { (rule: $0, policy: PolicyResolver.resolve($0, profiles: profiles)) }
            .filter { $0.policy.mode != .protect }
        let phases = [
            planned.filter { $0.rule.effectivePriority > 0 },
            planned.filter { $0.rule.effectivePriority <= 0 },
        ]

        var results: [RuleResult] = []
        var unreadable: [String] = []
        var claimed: [String] = []
        var completed = 0

        for phase in phases {
            let claimedSoFar = ClaimedPaths(claimed)
            await withTaskGroup(of: RuleScan.self) { group in
                for entry in phase {
                    group.addTask { self.scanRule(entry.rule, policy: entry.policy, claimed: claimedSoFar) }
                }
                for await scan in group {
                    completed += 1
                    progress?(Double(completed) / Double(max(planned.count, 1)), scan.result.rule.name)
                    unreadable += scan.unreadable
                    claimed += scan.claimedPaths
                    if !scan.result.items.isEmpty {
                        results.append(scan.result)
                    }
                }
            }
        }

        let categoryOrder = Dictionary(uniqueKeysWithValues: RuleCategory.allCases.enumerated().map { ($0.element, $0.offset) })
        results.sort { lhs, rhs in
            let l = categoryOrder[lhs.rule.category] ?? 0
            let r = categoryOrder[rhs.rule.category] ?? 0
            return l != r ? l < r : lhs.totalBytes > rhs.totalBytes
        }
        return ScanReport(results: results, unreadableLocations: unreadable.sorted(), profiles: profiles,
                          duration: Date().timeIntervalSince(started))
    }

    // MARK: - Per rule

    struct RuleScan: Sendable {
        let result: RuleResult
        let unreadable: [String]
        /// Roots and candidates this rule owns; catch-all rules must not pick them up.
        let claimedPaths: [String]
    }

    struct Candidate {
        let url: URL
        let rawRoot: String
        let root: URL
    }

    func scanRule(_ rule: CleanupRule, policy: ResolvedPolicy, claimed: ClaimedPaths) -> RuleScan {
        let fm = FileManager.default
        var candidates: [Candidate] = []
        var unreadable: [String] = []
        var claimedPaths: [String] = []

        for rawRoot in rule.paths {
            let root = environment.expand(rawRoot)
            switch rule.match.kind {
            case .itself:
                claimedPaths.append(root.path)
                if fm.fileExists(atPath: root.path) {
                    candidates.append(Candidate(url: root, rawRoot: rawRoot, root: root))
                }
            case .contents:
                // A filtered rule (e.g. only *.dmg in Downloads) owns just its matches, not the whole folder.
                if rule.match.include == nil { claimedPaths.append(root.path) }
                guard fm.fileExists(atPath: root.path) else { continue }
                guard let names = try? fm.contentsOfDirectory(atPath: root.path) else {
                    unreadable.append(environment.abbreviate(root))
                    continue
                }
                for name in names where name != ".DS_Store" && name != ".localized" {
                    if let include = rule.match.include, !Glob.matchesAny(name, include) { continue }
                    if Glob.matchesAny(name, rule.match.exclude) { continue }
                    candidates.append(Candidate(url: root.appendingPathComponent(name), rawRoot: rawRoot, root: root))
                }
            case .nested:
                for url in findNested(under: root, spec: rule.match) {
                    candidates.append(Candidate(url: url, rawRoot: rawRoot, root: root))
                }
            }
        }

        // Search roots like ~/Code and ~/code are the same folder on a case-insensitive volume.
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0.url.path.lowercased()).inserted }
        claimedPaths += candidates.map(\.url.path)

        let cutoff = environment.now.addingTimeInterval(-Double(policy.minAgeDays) * 86_400)
        var items: [ScanItem] = []
        var skippedRecent = 0

        for candidate in candidates {
            if Task.isCancelled { break }
            let url = candidate.url
            if claimed.overlaps(url.path) || safety.check(url) != nil { continue }

            let parentAge = rule.match.ageFromParent == true ? FileStatsCalculator.newestSiblingModification(of: url) : nil
            if policy.minAgeDays > 0, let parentAge, parentAge > cutoff {
                skippedRecent += 1
                continue
            }
            let stats = FileStatsCalculator.stats(for: url)
            let reference = parentAge ?? stats.newestModification
            if policy.minAgeDays > 0, let reference, reference > cutoff {
                skippedRecent += 1
                continue
            }
            guard stats.allocatedBytes > 0 else { continue }

            let owners = ownerIDs(for: candidate, rule: rule)
            let inUseBy = environment.runningBundleIDs.first { running in
                owners.contains { BundleID.matches(running, pattern: $0) }
            }
            items.append(ScanItem(
                url: url, ruleID: rule.id, displayName: displayName(for: candidate, kind: rule.match.kind),
                location: environment.abbreviate(url), bytes: stats.allocatedBytes, fileCount: stats.fileCount,
                lastModified: reference, ownerBundleIDs: owners, inUseBy: inUseBy))
        }

        items.sort { $0.bytes > $1.bytes }
        let result = RuleResult(rule: rule, policy: policy, items: items, skippedRecentCount: skippedRecent)
        return RuleScan(result: result, unreadable: unreadable, claimedPaths: claimedPaths)
    }

    private func ownerIDs(for candidate: Candidate, rule: CleanupRule) -> [String] {
        var owners: [String] = []
        if let owner = rule.pathOwners?[candidate.rawRoot] { owners.append(owner) }
        owners += rule.appBundleIDs ?? []
        if rule.match.kind == .contents {
            let name = BundleID.normalize(candidate.url.lastPathComponent)
            if BundleID.looksLikeBundleID(name) { owners.append(name) }
        }
        return owners
    }

    private func displayName(for candidate: Candidate, kind: MatchSpec.Kind) -> String {
        switch kind {
        case .contents:
            return candidate.url.lastPathComponent
        case .itself:
            return environment.abbreviate(candidate.url)
        case .nested:
            // "my-app/node_modules" reads better than the bare folder name.
            return candidate.url.deletingLastPathComponent().lastPathComponent + "/" + candidate.url.lastPathComponent
        }
    }

    /// Depth-limited search for directories matching `spec.nestedName`. Doesn't follow symlinks, skip
    /// hidden folders, or descend into matches and dependency trees.
    func findNested(under root: URL, spec: MatchSpec) -> [URL] {
        guard let target = spec.nestedName else { return [] }
        let fm = FileManager.default
        let maxDepth = spec.maxDepth ?? 4
        let neverDescend: Set<String> = ["node_modules", "Pods", "vendor", "Carthage"]
        var found: [URL] = []

        func walk(_ dir: URL, depth: Int) {
            guard depth <= maxDepth, !Task.isCancelled,
                  let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
            for name in names where !name.hasPrefix(".") {
                let child = dir.appendingPathComponent(name)
                guard let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      values.isDirectory == true, values.isSymbolicLink != true else { continue }

                let siblingOK = spec.requiresSibling.map { fm.fileExists(atPath: dir.appendingPathComponent($0).path) } ?? true
                let pathOK = spec.pathContains.map { child.path.contains($0) } ?? true
                if Glob.matches(name, pattern: target), !Glob.matchesAny(name, spec.exclude), siblingOK, pathOK {
                    found.append(child)
                    continue
                }
                if neverDescend.contains(name) { continue }
                walk(child, depth: depth + 1)
            }
        }

        walk(root, depth: 0)
        return found
    }
}

struct ClaimedPaths: Sendable {
    private let paths: [String]

    init(_ paths: [String]) {
        self.paths = paths
    }

    /// True when `path` is, contains, or is inside a claimed path.
    func overlaps(_ path: String) -> Bool {
        paths.contains { $0 == path || $0.hasPrefix(path + "/") || path.hasPrefix($0 + "/") }
    }
}
