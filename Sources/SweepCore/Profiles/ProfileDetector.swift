import Foundation

public struct ProfileSuggestion: Sendable, Equatable {
    /// Strongest first; `[.general]` when nothing stands out.
    public let profiles: [UsageProfile]
    /// Human-readable reasons per profile, e.g. app names.
    public let evidence: [UsageProfile: [String]]
}

/// Guesses what the Mac is used for from installed (and recently used) apps and tool folders.
public enum ProfileDetector {
    /// Identifiers ending in "." match by prefix.
    static let appSignals: [(UsageProfile, String)] = [
        (.developer, "com.apple.dt.Xcode"), (.developer, "com.microsoft.VSCode"), (.developer, "com.jetbrains."),
        (.developer, "com.docker.docker"), (.developer, "com.googlecode.iterm2"), (.developer, "dev.warp.Warp-Stable"),
        (.developer, "com.sublimetext."), (.developer, "com.github.GitHubClient"), (.developer, "com.todesktop.230313mzl4w4u92"),
        (.developer, "com.postmanlabs.mac"), (.developer, "com.google.android.studio"),

        (.creative, "com.apple.FinalCut"), (.creative, "com.apple.motionapp"), (.creative, "com.apple.logic10"),
        (.creative, "com.apple.garageband10"), (.creative, "com.adobe.Photoshop"), (.creative, "com.adobe.PremierePro."),
        (.creative, "com.adobe.AfterEffects"), (.creative, "com.adobe.illustrator"), (.creative, "com.adobe.LightroomClassicCC7"),
        (.creative, "com.adobe.lightroomCC"), (.creative, "com.blackmagic-design.DaVinciResolve"), (.creative, "com.ableton.live"),
        (.creative, "com.figma.Desktop"), (.creative, "com.bohemiancoding.sketch3"), (.creative, "com.seriflabs."),
        (.creative, "com.pixelmatorteam.pixelmator."), (.creative, "org.blenderfoundation.blender"),

        (.gamer, "com.valvesoftware.steam"), (.gamer, "com.epicgames.EpicGamesLauncher"), (.gamer, "com.blizzard."),
        (.gamer, "net.battle."), (.gamer, "com.gog.galaxy"), (.gamer, "com.riotgames."), (.gamer, "com.heroicgameslauncher.hgl"),
        (.gamer, "com.codeweavers.CrossOver"), (.gamer, "com.isaacmarovitz.Whisky"),

        (.office, "com.microsoft.Word"), (.office, "com.microsoft.Excel"), (.office, "com.microsoft.Powerpoint"),
        (.office, "com.microsoft.Outlook"), (.office, "com.apple.iWork.Pages"), (.office, "com.apple.iWork.Numbers"),
        (.office, "com.apple.iWork.Keynote"), (.office, "notion.id"), (.office, "com.tinyspeck.slackmacgap"),
        (.office, "us.zoom.xos"), (.office, "com.microsoft.teams2"),
    ]

    static let folderSignals: [(UsageProfile, String, String)] = [
        (.developer, "Library/Developer/Xcode/DerivedData", "Xcode build data"),
        (.developer, ".npm", "npm"),
        (.developer, ".cargo", "Rust toolchain"),
        (.developer, ".gradle", "Gradle"),
        (.developer, ".docker", "Docker"),
        (.gamer, "Library/Application Support/Steam/steamapps/common", "Installed Steam games"),
    ]

    /// An app opened in the last 30 days counts three times as much as one that is merely installed,
    /// so a profile needs either recent use or several matching tools to be suggested.
    public static func suggest(apps: [InstalledApp], home: URL, now: Date = Date()) -> ProfileSuggestion {
        var scores: [UsageProfile: Int] = [:]
        var evidence: [UsageProfile: [String]] = [:]
        let recent = now.addingTimeInterval(-30 * 86_400)

        for app in apps {
            guard let id = app.bundleID else { continue }
            for (profile, pattern) in appSignals where BundleID.matches(id, pattern: pattern) {
                let usedRecently = (app.lastUsed ?? .distantPast) > recent
                scores[profile, default: 0] += usedRecently ? 3 : 1
                evidence[profile, default: []].append(app.name)
            }
        }
        for (profile, path, label) in folderSignals
        where FileManager.default.fileExists(atPath: home.appendingPathComponent(path).path) {
            scores[profile, default: 0] += 1
            evidence[profile, default: []].append(label)
        }

        let picked = scores
            .filter { $0.value >= 3 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.rawValue < $1.key.rawValue }
            .prefix(3)
            .map { $0.key }
        return ProfileSuggestion(profiles: picked.isEmpty ? [.general] : Array(picked), evidence: evidence)
    }
}
