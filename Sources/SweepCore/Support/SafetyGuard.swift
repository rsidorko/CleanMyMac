import Foundation

/// The last line of defense: every path is checked here both when it is found and right before it is
/// removed. Rules can be wrong; this list of hard limits is deliberately not configurable.
public struct SafetyGuard: Sendable {
    public enum Violation: Error, Equatable, CustomStringConvertible {
        case outsideAllowedLocations(String)
        case protectedLocation(String)

        public var description: String {
            switch self {
            case .outsideAllowedLocations(let path): return "\(path) is outside the folders Sweep may clean."
            case .protectedLocation(let path): return "\(path) is a protected location."
            }
        }
    }

    private let allowedRoots: [String]
    private let neverExactly: Set<String>
    private let neverInside: [String]

    /// - Parameter additionalAllowedRoots: Extra folders whose contents may be removed, e.g. `/Applications`
    ///   for uninstalling apps. The folders themselves are always protected.
    public init(home: URL, additionalAllowedRoots: [URL] = []) {
        let home = Self.canonical(home)
        let extraRoots = additionalAllowedRoots.map(Self.canonical)
        allowedRoots = [home] + extraRoots

        let exact = [
            "", "Library", "Library/Caches", "Library/Application Support", "Library/Containers",
            "Library/Group Containers", "Library/Preferences", "Library/Logs", "Library/Developer",
            "Applications", "Desktop", "Documents", "Downloads", "Movies", "Music", "Pictures", "Public",
            "Developer", ".Trash",
        ]
        neverExactly = Set(exact.map { $0.isEmpty ? home : home + "/" + $0 } + extraRoots)

        neverInside = [
            "Library/Keychains", "Library/Mobile Documents", "Library/CloudStorage", "Library/Messages",
            "Library/Mail", "Library/Accounts", "Library/Cookies", "Library/Calendars", "Library/Safari",
            "Library/Application Support/AddressBook", "Library/Application Support/com.apple.TCC",
            "Library/Group Containers/group.com.apple.notes", ".ssh", ".gnupg",
        ].map { home + "/" + $0 }
    }

    static func canonical(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    /// Returns why `url` must not be removed, or nil when it may be.
    public func check(_ url: URL) -> Violation? {
        let url = url.standardizedFileURL
        // Resolve the parent so a symlinked folder can't redirect a deletion somewhere else. The item itself
        // may be a symlink; removing it only removes the link.
        let parent = Self.canonical(url.deletingLastPathComponent())
        let path = parent == "/" ? "/" + url.lastPathComponent : parent + "/" + url.lastPathComponent

        guard allowedRoots.contains(where: { path.hasPrefix($0 + "/") }) else {
            return .outsideAllowedLocations(path)
        }
        if neverExactly.contains(path) {
            return .protectedLocation(path)
        }
        if neverInside.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return .protectedLocation(path)
        }
        let libraryPackages = [".photoslibrary", ".musiclibrary", ".tvlibrary"]
        if path.split(separator: "/").contains(where: { component in libraryPackages.contains { component.hasSuffix($0) } }) {
            return .protectedLocation(path)
        }
        return nil
    }
}
