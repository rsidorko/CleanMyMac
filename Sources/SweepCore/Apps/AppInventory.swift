import Foundation
#if canImport(CoreServices)
import CoreServices
#endif

public struct InstalledApp: Identifiable, Hashable, Sendable {
    public var id: String { url.path }
    public let url: URL
    /// The name shown in Finder.
    public let name: String
    /// `CFBundleName`, which apps often use for their Application Support folder.
    public let bundleName: String?
    public let bundleID: String?
    public let version: String?
    /// From Spotlight; nil when macOS has no record of the app being opened.
    public let lastUsed: Date?

    public var isAppleApp: Bool { bundleID?.lowercased().hasPrefix("com.apple.") ?? false }

    public init(url: URL, name: String, bundleName: String?, bundleID: String?, version: String?, lastUsed: Date?) {
        self.url = url
        self.name = name
        self.bundleName = bundleName
        self.bundleID = bundleID
        self.version = version
        self.lastUsed = lastUsed
    }
}

public enum AppInventory {
    /// Apps in /Applications and ~/Applications, including one level of subfolders
    /// (e.g. "/Applications/Adobe Photoshop 2025/").
    public static func userApps(home: URL) -> [InstalledApp] {
        [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
            .flatMap { appBundles(in: $0, depth: 1) }
            .compactMap(readApp(at:))
    }

    /// Every bundle identifier on the system that we can find. Used to decide whether data in ~/Library
    /// still belongs to something installed, so it errs on the side of finding too many.
    public static func allInstalledBundleIDs(home: URL) -> Set<String> {
        let roots = [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"), home.appendingPathComponent("Applications")]
        let urls = spotlightApplicationURLs() + roots.flatMap { appBundles(in: $0, depth: 2) }
        return Set(urls.compactMap { bundleID(of: $0)?.lowercased() })
    }

    public static func readApp(at url: URL) -> InstalledApp? {
        guard let info = infoPlist(of: url) else { return nil }
        return InstalledApp(
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            bundleName: info["CFBundleName"] as? String,
            bundleID: info["CFBundleIdentifier"] as? String,
            version: info["CFBundleShortVersionString"] as? String,
            lastUsed: lastUsedDate(of: url))
    }

    public static func lastUsedDate(of url: URL) -> Date? {
        #if canImport(CoreServices)
        guard let item = MDItemCreateWithURL(kCFAllocatorDefault, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
        #else
        return nil
        #endif
    }

    static func bundleID(of url: URL) -> String? {
        infoPlist(of: url)?["CFBundleIdentifier"] as? String
    }

    private static func infoPlist(of url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url.appendingPathComponent("Contents/Info.plist")) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    static func appBundles(in directory: URL, depth: Int) -> [URL] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        var result: [URL] = []
        for name in names where !name.hasPrefix(".") {
            let url = directory.appendingPathComponent(name)
            if name.hasSuffix(".app") {
                result.append(url)
            } else if depth > 0, (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                result += appBundles(in: url, depth: depth - 1)
            }
        }
        return result
    }

    /// Asks Spotlight for every application bundle it knows about, wherever it lives.
    private static func spotlightApplicationURLs() -> [URL] {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemContentType == 'com.apple.application-bundle'"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map { URL(fileURLWithPath: String($0)) }
        #else
        return []
        #endif
    }
}
