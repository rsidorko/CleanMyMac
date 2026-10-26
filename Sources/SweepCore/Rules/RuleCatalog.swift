import Foundation

/// The set of cleanup rules the scanner works from.
public struct RuleCatalog: Sendable {
    private struct RuleFile: Codable {
        var version: Int
        var rules: [CleanupRule]
    }

    public let rules: [CleanupRule]

    public init(rules: [CleanupRule]) {
        self.rules = rules
    }

    public static func builtIn() throws -> RuleCatalog {
        try decode(Data(DefaultRules.json.utf8))
    }

    public static func decode(_ data: Data) throws -> RuleCatalog {
        RuleCatalog(rules: try JSONDecoder().decode(RuleFile.self, from: data).rules)
    }

    /// Built-in rules, with rules from an optional override file replacing built-ins that share an id
    /// and adding any new ones. An unreadable override file is ignored.
    public static func load(overrideURL: URL?) -> RuleCatalog {
        let builtIn = (try? builtIn().rules) ?? []
        guard let overrideURL,
              let data = try? Data(contentsOf: overrideURL),
              let overrides = try? decode(data).rules else {
            return RuleCatalog(rules: builtIn)
        }
        let overrideIDs = Set(overrides.map(\.id))
        return RuleCatalog(rules: builtIn.filter { !overrideIDs.contains($0.id) } + overrides)
    }
}
