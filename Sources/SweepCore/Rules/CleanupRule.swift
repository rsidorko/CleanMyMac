import Foundation

/// Broad grouping used for presentation and for deciding how a usage profile treats a rule.
public enum RuleCategory: String, Codable, CaseIterable, Sendable {
    case system
    case downloads
    case developer
    case creative
    case gaming

    public var title: String {
        switch self {
        case .system: return "System & App Junk"
        case .downloads: return "Downloads"
        case .developer: return "Developer"
        case .creative: return "Creative Apps"
        case .gaming: return "Games"
        }
    }

    public var symbolName: String {
        switch self {
        case .system: return "gearshape.2"
        case .downloads: return "arrow.down.circle"
        case .developer: return "hammer"
        case .creative: return "paintbrush"
        case .gaming: return "gamecontroller"
        }
    }
}

public enum Safety: String, Codable, Sendable {
    /// Disposable or rebuilt automatically; may be pre-selected.
    case safe
    /// Might hold something the user wants; shown but never pre-selected.
    case review
}

/// How painful it is to get the data back after deleting it (rebuild time, re-downloads).
public enum RegenerationCost: String, Codable, Sendable, Comparable {
    case low
    case medium
    case high

    private var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

public enum DeletionMethod: String, Codable, Sendable {
    /// Permanently delete data that rebuilds itself, move everything else to the Trash.
    case automatic
    case trash
    case permanent
}

/// Describes which file system items under a rule's paths are cleanup candidates.
public struct MatchSpec: Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Every entry directly inside each path is a separate item.
        case contents
        /// Each path is a single item.
        case itself
        /// Search below each path for directories named `nestedName`.
        case nested
    }

    public var kind: Kind
    /// Shell-style patterns an entry name must match (contents and nested kinds).
    public var include: [String]?
    /// Shell-style patterns that exclude an entry name.
    public var exclude: [String]?
    /// Directory name (or pattern) to look for when `kind` is `nested`.
    public var nestedName: String?
    /// Nested matches only count when a sibling with this name exists, e.g. `package.json` next to `node_modules`.
    public var requiresSibling: String?
    /// Nested matches only count when their path contains this string, e.g. `.fcpbundle/`.
    public var pathContains: String?
    public var maxDepth: Int?
    /// Measure staleness from the parent folder's other contents instead of the item itself.
    /// A project's `node_modules` is stale when the project hasn't been touched, not when the install is old.
    public var ageFromParent: Bool?

    public init(kind: Kind, include: [String]? = nil, exclude: [String]? = nil, nestedName: String? = nil,
                requiresSibling: String? = nil, pathContains: String? = nil, maxDepth: Int? = nil, ageFromParent: Bool? = nil) {
        self.kind = kind
        self.include = include
        self.exclude = exclude
        self.nestedName = nestedName
        self.requiresSibling = requiresSibling
        self.pathContains = pathContains
        self.maxDepth = maxDepth
        self.ageFromParent = ageFromParent
    }
}

/// One kind of reclaimable data. Rules are data (see `DefaultRules`) so they can be reviewed,
/// tested and extended without touching the scanning code.
public struct CleanupRule: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var summary: String
    public var category: RuleCategory
    /// Locations, written with a leading `~/` for the user's home folder.
    public var paths: [String]
    public var match: MatchSpec
    public var safety: Safety
    public var regenerates: Bool
    public var regenCost: RegenerationCost
    /// Items modified more recently than this are left alone (before profile adjustments).
    public var minAgeDays: Int
    /// Apps whose data this rule removes; items are flagged as in use while one of them runs.
    /// Identifiers ending in "." match any identifier with that prefix.
    public var appBundleIDs: [String]?
    /// Per-path owning app, for rules that cover several apps.
    public var pathOwners: [String: String]?
    /// Rules with priority 0 or less run after all others and skip anything those already claimed.
    public var priority: Int?
    public var deletion: DeletionMethod?
    /// Overrides of the default policy, keyed by `UsageProfile` raw value.
    public var profileModes: [String: PolicyMode]?

    public init(id: String, name: String, summary: String, category: RuleCategory, paths: [String], match: MatchSpec,
                safety: Safety, regenerates: Bool, regenCost: RegenerationCost, minAgeDays: Int,
                appBundleIDs: [String]? = nil, pathOwners: [String: String]? = nil, priority: Int? = nil,
                deletion: DeletionMethod? = nil, profileModes: [String: PolicyMode]? = nil) {
        self.id = id
        self.name = name
        self.summary = summary
        self.category = category
        self.paths = paths
        self.match = match
        self.safety = safety
        self.regenerates = regenerates
        self.regenCost = regenCost
        self.minAgeDays = minAgeDays
        self.appBundleIDs = appBundleIDs
        self.pathOwners = pathOwners
        self.priority = priority
        self.deletion = deletion
        self.profileModes = profileModes
    }

    public var effectivePriority: Int { priority ?? 10 }

    /// The concrete method used when cleaning this rule's items.
    public func resolvedDeletion(alwaysUseTrash: Bool) -> DeletionMethod {
        switch deletion ?? .automatic {
        case .permanent:
            return .permanent
        case .trash:
            return .trash
        case .automatic:
            return (!alwaysUseTrash && regenerates && safety == .safe) ? .permanent : .trash
        }
    }
}
