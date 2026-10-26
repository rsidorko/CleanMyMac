import Foundation

public struct ResolvedPolicy: Sendable, Equatable {
    public let mode: PolicyMode
    /// Items modified within this many days are skipped.
    public let minAgeDays: Int
    /// Whether the rule's items start out checked in the results.
    public let preselect: Bool
}

/// Turns a rule plus the user's profiles into concrete behavior.
public enum PolicyResolver {
    public static func defaultMode(for profile: UsageProfile, category: RuleCategory) -> PolicyMode {
        switch category {
        case .system, .downloads:
            return .standard
        case .developer, .creative, .gaming:
            return profile.focusCategory == category ? .careful : .aggressive
        }
    }

    /// With several profiles selected the most conservative treatment wins, so a "developer who also
    /// edits photos" never loses Lightroom previews because the developer profile considers them junk.
    public static func resolve(_ rule: CleanupRule, profiles: Set<UsageProfile>) -> ResolvedPolicy {
        let active: [UsageProfile] = profiles.isEmpty ? [.general] : Array(profiles)
        let mode = active
            .map { rule.profileModes?[$0.rawValue] ?? defaultMode(for: $0, category: rule.category) }
            .max() ?? .standard

        let minAge: Int
        let allowedRegenCost: RegenerationCost
        switch mode {
        case .aggressive:
            minAge = rule.minAgeDays / 2
            allowedRegenCost = .high
        case .standard, .protect:
            minAge = rule.minAgeDays
            allowedRegenCost = .medium
        case .careful:
            minAge = rule.minAgeDays == 0 ? 0 : max(rule.minAgeDays * 2, 30)
            allowedRegenCost = .low
        }

        let preselect = mode != .protect && rule.safety == .safe && rule.regenCost <= allowedRegenCost
        return ResolvedPolicy(mode: mode, minAgeDays: minAge, preselect: preselect)
    }
}
