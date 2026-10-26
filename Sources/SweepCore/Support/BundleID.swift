import Foundation

public enum BundleID {
    /// True for reverse-DNS names such as `com.vendor.App`. Folder names like `Google` or `Slack` are not.
    public static func looksLikeBundleID(_ name: String) -> Bool {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        }
    }

    /// Strips the decorations macOS adds around bundle identifiers in `~/Library` entry names:
    /// `com.foo.App.plist`, `com.foo.App.savedState`, `group.com.foo.App`, `ABCDE12345.com.foo.App`.
    public static func normalize(_ entryName: String) -> String {
        var name = entryName
        for suffix in [".plist", ".savedState", ".binarycookies"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
        }
        if name.hasPrefix("group.") {
            name = String(name.dropFirst("group.".count))
        }
        let parts = name.split(separator: ".", maxSplits: 1)
        if parts.count == 2, parts[0].count == 10, parts[0].allSatisfy({ $0.isUppercase || $0.isNumber }) {
            name = String(parts[1])
        }
        return name
    }

    /// Case-insensitive match. Patterns ending in "." match any identifier with that prefix.
    public static func matches(_ id: String, pattern: String) -> Bool {
        let id = id.lowercased()
        let pattern = pattern.lowercased()
        return pattern.hasSuffix(".") ? id.hasPrefix(pattern) : id == pattern
    }

    /// The first two components, e.g. `com.microsoft` for `com.microsoft.Word`.
    public static func vendor(of id: String) -> String {
        id.lowercased().split(separator: ".").prefix(2).joined(separator: ".")
    }
}
