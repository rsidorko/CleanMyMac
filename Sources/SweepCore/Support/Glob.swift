#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum Glob {
    /// Case-insensitive shell-style match (`*`, `?`, `[...]`) of a single path component.
    /// macOS volumes are case-insensitive by default, so rule patterns are too.
    static func matches(_ name: String, pattern: String) -> Bool {
        fnmatch(pattern.lowercased(), name.lowercased(), 0) == 0
    }

    static func matchesAny(_ name: String, _ patterns: [String]?) -> Bool {
        guard let patterns else { return false }
        return patterns.contains { matches(name, pattern: $0) }
    }
}
