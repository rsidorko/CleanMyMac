// The built-in cleanup knowledge base. Kept as JSON (rather than Swift values) so it stays plain data
// that can be validated, diffed and overridden by a file in Application Support. It is embedded as a
// string instead of a bundle resource so the app works the same from `swift run` and from a signed .app.
//
// Every path must live inside the home folder; `SafetyGuard` enforces this again at scan and delete time.
enum DefaultRules {
    static let json = #"""
{
  "version": 1,
  "rules": [
    {
      "id": "user-caches",
      "name": "App caches",
      "summary": "Temporary files apps rebuild on their own. Caches of running apps are left unchecked.",
      "category": "system",
      "paths": ["~/Library/Caches"],
      "match": { "kind": "contents", "exclude": ["com.apple.*", "CloudKit", "Metadata", "FamilyCircle", "GeoServices", "io.github.rsidorko.sweep"] },
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 0, "priority": 0
    },
    {
      "id": "user-logs",
      "name": "Log files",
      "summary": "Diagnostic logs written by apps. Only logs older than the age limit are included.",
      "category": "system",
      "paths": ["~/Library/Logs"],
      "match": { "kind": "contents" },
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 7, "priority": 0
    },
    {
      "id": "browser-caches",
      "name": "Browser caches",
      "summary": "Website files cached by Chrome, Firefox, Brave and Edge. Sign-ins, history and bookmarks are not touched.",
      "category": "system",
      "paths": [
        "~/Library/Caches/Google/Chrome",
        "~/Library/Caches/Firefox",
        "~/Library/Caches/BraveSoftware",
        "~/Library/Caches/Microsoft Edge"
      ],
      "pathOwners": {
        "~/Library/Caches/Google/Chrome": "com.google.Chrome",
        "~/Library/Caches/Firefox": "org.mozilla.firefox",
        "~/Library/Caches/BraveSoftware": "com.brave.Browser",
        "~/Library/Caches/Microsoft Edge": "com.microsoft.edgemac"
      },
      "match": { "kind": "itself" },
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 0
    },
    {
      "id": "chat-app-caches",
      "name": "Chat app caches",
      "summary": "Web caches kept by Slack and Discord. They refill as you use the apps.",
      "category": "system",
      "paths": [
        "~/Library/Application Support/Slack/Cache",
        "~/Library/Application Support/Slack/Code Cache",
        "~/Library/Application Support/Slack/Service Worker/CacheStorage",
        "~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/Cache",
        "~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/Service Worker/CacheStorage",
        "~/Library/Application Support/discord/Cache",
        "~/Library/Application Support/discord/Code Cache"
      ],
      "pathOwners": {
        "~/Library/Application Support/Slack/Cache": "com.tinyspeck.slackmacgap",
        "~/Library/Application Support/Slack/Code Cache": "com.tinyspeck.slackmacgap",
        "~/Library/Application Support/Slack/Service Worker/CacheStorage": "com.tinyspeck.slackmacgap",
        "~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/Cache": "com.tinyspeck.slackmacgap",
        "~/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/Service Worker/CacheStorage": "com.tinyspeck.slackmacgap",
        "~/Library/Application Support/discord/Cache": "com.hnc.Discord",
        "~/Library/Application Support/discord/Code Cache": "com.hnc.Discord"
      },
      "match": { "kind": "itself" },
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 0
    },
    {
      "id": "trash",
      "name": "Trash",
      "summary": "Items already in the Trash. Removing them is permanent.",
      "category": "system",
      "paths": ["~/.Trash"],
      "match": { "kind": "contents" },
      "safety": "review", "regenerates": false, "regenCost": "low", "minAgeDays": 0, "deletion": "permanent"
    },
    {
      "id": "ios-backups",
      "name": "iPhone & iPad backups",
      "summary": "Local device backups made by Finder. Make sure you have a newer or iCloud backup before removing one.",
      "category": "system",
      "paths": ["~/Library/Application Support/MobileSync/Backup"],
      "match": { "kind": "contents" },
      "safety": "review", "regenerates": false, "regenCost": "high", "minAgeDays": 30
    },
    {
      "id": "ios-firmware",
      "name": "iOS software updates",
      "summary": "Downloaded iPhone and iPad system updates (.ipsw) that are no longer needed once installed.",
      "category": "system",
      "paths": ["~/Library/iTunes/iPhone Software Updates", "~/Library/iTunes/iPad Software Updates"],
      "match": { "kind": "contents", "include": ["*.ipsw"] },
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 0
    },
    {
      "id": "mail-downloads",
      "name": "Mail attachment copies",
      "summary": "Copies of attachments you opened in Mail. The originals stay in your mailbox.",
      "category": "system",
      "paths": ["~/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"],
      "match": { "kind": "contents" },
      "appBundleIDs": ["com.apple.mail"],
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 14
    },
    {
      "id": "old-installers",
      "name": "Old installers",
      "summary": "Disk images and installer packages in Downloads that have most likely been installed already.",
      "category": "downloads",
      "paths": ["~/Downloads"],
      "match": { "kind": "contents", "include": ["*.dmg", "*.pkg", "*.mpkg", "*.xip"] },
      "safety": "safe", "regenerates": false, "regenCost": "medium", "minAgeDays": 14
    },
    {
      "id": "old-downloads",
      "name": "Forgotten downloads",
      "summary": "Files in Downloads you haven't touched in months. Review before removing.",
      "category": "downloads",
      "paths": ["~/Downloads"],
      "match": { "kind": "contents" },
      "safety": "review", "regenerates": false, "regenCost": "high", "minAgeDays": 90, "priority": 0
    },
    {
      "id": "xcode-derived-data",
      "name": "Xcode build data",
      "summary": "DerivedData for projects you haven't built recently. Xcode rebuilds it on the next build.",
      "category": "developer",
      "paths": ["~/Library/Developer/Xcode/DerivedData"],
      "match": { "kind": "contents" },
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 14,
      "profileModes": { "developer": "standard" }
    },
    {
      "id": "xcode-caches",
      "name": "Xcode caches",
      "summary": "Xcode's own cache folder and SwiftUI preview data.",
      "category": "developer",
      "paths": ["~/Library/Caches/com.apple.dt.Xcode", "~/Library/Developer/Xcode/UserData/Previews"],
      "match": { "kind": "itself" },
      "appBundleIDs": ["com.apple.dt.Xcode"],
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 0
    },
    {
      "id": "xcode-device-support",
      "name": "Old device support files",
      "summary": "Debug symbols for iOS, watchOS and tvOS versions you haven't connected a device with recently. Xcode copies them again if needed.",
      "category": "developer",
      "paths": [
        "~/Library/Developer/Xcode/iOS DeviceSupport",
        "~/Library/Developer/Xcode/watchOS DeviceSupport",
        "~/Library/Developer/Xcode/tvOS DeviceSupport",
        "~/Library/Developer/Xcode/visionOS DeviceSupport"
      ],
      "match": { "kind": "contents" },
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 90,
      "profileModes": { "developer": "standard" }
    },
    {
      "id": "xcode-archives",
      "name": "Xcode archives",
      "summary": "Old app archives. You need them to symbolicate crash reports from those builds, so review first.",
      "category": "developer",
      "paths": ["~/Library/Developer/Xcode/Archives"],
      "match": { "kind": "contents" },
      "safety": "review", "regenerates": false, "regenCost": "high", "minAgeDays": 180
    },
    {
      "id": "simulator-caches",
      "name": "Simulator caches",
      "summary": "Shared caches built by the iOS Simulator.",
      "category": "developer",
      "paths": ["~/Library/Developer/CoreSimulator/Caches"],
      "match": { "kind": "contents" },
      "appBundleIDs": ["com.apple.iphonesimulator"],
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 0
    },
    {
      "id": "package-caches",
      "name": "Package manager caches",
      "summary": "Download caches for npm, Yarn, Bun, pip, uv, CocoaPods, Swift packages, Homebrew, Go and Cargo. Packages are downloaded again when needed.",
      "category": "developer",
      "paths": [
        "~/.npm/_cacache",
        "~/Library/Caches/Yarn",
        "~/.bun/install/cache",
        "~/Library/Caches/pip",
        "~/.cache/uv",
        "~/Library/Caches/CocoaPods",
        "~/Library/Caches/org.swift.swiftpm",
        "~/Library/Caches/Homebrew",
        "~/Library/Caches/go-build",
        "~/.cargo/registry/cache"
      ],
      "match": { "kind": "itself" },
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 0
    },
    {
      "id": "jvm-caches",
      "name": "Gradle & Maven caches",
      "summary": "Downloaded Java/Kotlin dependencies and build caches. Re-downloading them can take a while.",
      "category": "developer",
      "paths": ["~/.gradle/caches", "~/.m2/repository"],
      "match": { "kind": "itself" },
      "safety": "safe", "regenerates": true, "regenCost": "high", "minAgeDays": 0
    },
    {
      "id": "ide-caches",
      "name": "Editor caches",
      "summary": "Caches from VS Code, Cursor and old JetBrains IDE versions.",
      "category": "developer",
      "paths": [
        "~/Library/Application Support/Code/Cache",
        "~/Library/Application Support/Code/CachedData",
        "~/Library/Application Support/Code/CachedExtensionVSIXs",
        "~/Library/Application Support/Code/Code Cache",
        "~/Library/Application Support/Cursor/Cache",
        "~/Library/Application Support/Cursor/CachedData"
      ],
      "pathOwners": {
        "~/Library/Application Support/Code/Cache": "com.microsoft.VSCode",
        "~/Library/Application Support/Code/CachedData": "com.microsoft.VSCode",
        "~/Library/Application Support/Code/CachedExtensionVSIXs": "com.microsoft.VSCode",
        "~/Library/Application Support/Code/Code Cache": "com.microsoft.VSCode",
        "~/Library/Application Support/Cursor/Cache": "com.todesktop.230313mzl4w4u92",
        "~/Library/Application Support/Cursor/CachedData": "com.todesktop.230313mzl4w4u92"
      },
      "match": { "kind": "itself" },
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 0
    },
    {
      "id": "jetbrains-caches",
      "name": "JetBrains IDE caches",
      "summary": "Index caches for JetBrains IDE versions you haven't opened recently.",
      "category": "developer",
      "paths": ["~/Library/Caches/JetBrains"],
      "match": { "kind": "contents" },
      "appBundleIDs": ["com.jetbrains."],
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 30
    },
    {
      "id": "stale-node-modules",
      "name": "node_modules in idle projects",
      "summary": "Installed JavaScript dependencies in projects you haven't touched in a while. Run npm install to restore.",
      "category": "developer",
      "paths": [
        "~/Developer", "~/Projects", "~/Code", "~/dev", "~/src", "~/repos", "~/GitHub",
        "~/Documents/GitHub", "~/Documents/Projects", "~/Documents/Code", "~/Desktop"
      ],
      "match": { "kind": "nested", "nestedName": "node_modules", "requiresSibling": "package.json", "maxDepth": 5, "ageFromParent": true },
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 60,
      "profileModes": { "developer": "standard" }
    },
    {
      "id": "stale-rust-targets",
      "name": "Rust build folders in idle projects",
      "summary": "Cargo target folders in projects you haven't touched in a while. They are rebuilt by cargo build.",
      "category": "developer",
      "paths": [
        "~/Developer", "~/Projects", "~/Code", "~/dev", "~/src", "~/repos", "~/GitHub",
        "~/Documents/GitHub", "~/Documents/Projects", "~/Documents/Code", "~/Desktop"
      ],
      "match": { "kind": "nested", "nestedName": "target", "requiresSibling": "Cargo.toml", "maxDepth": 5, "ageFromParent": true },
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 60,
      "profileModes": { "developer": "standard" }
    },
    {
      "id": "final-cut-render-files",
      "name": "Final Cut Pro render files",
      "summary": "Rendered previews inside Final Cut libraries you haven't edited recently. Final Cut re-renders them when needed.",
      "category": "creative",
      "paths": ["~/Movies"],
      "match": { "kind": "nested", "nestedName": "Render Files", "pathContains": ".fcpbundle/", "maxDepth": 4 },
      "appBundleIDs": ["com.apple.FinalCut"],
      "safety": "safe", "regenerates": true, "regenCost": "high", "minAgeDays": 30
    },
    {
      "id": "adobe-media-cache",
      "name": "Adobe media caches",
      "summary": "Media Cache, peak files and Camera Raw cache used by Premiere Pro, After Effects, Audition and Photoshop.",
      "category": "creative",
      "paths": [
        "~/Library/Application Support/Adobe/Common/Media Cache Files",
        "~/Library/Application Support/Adobe/Common/Media Cache",
        "~/Library/Application Support/Adobe/Common/Peak Files",
        "~/Library/Caches/Adobe Camera Raw 2",
        "~/Library/Caches/Adobe Camera Raw"
      ],
      "match": { "kind": "itself" },
      "appBundleIDs": ["com.adobe.PremierePro.", "com.adobe.AfterEffects", "com.adobe.Audition", "com.adobe.Photoshop", "com.adobe.LightroomClassicCC7"],
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 30
    },
    {
      "id": "lightroom-previews",
      "name": "Lightroom Classic previews",
      "summary": "Preview caches for Lightroom catalogs you haven't opened recently. Smart Previews are kept.",
      "category": "creative",
      "paths": ["~/Pictures"],
      "match": { "kind": "nested", "nestedName": "*Previews.lrdata", "exclude": ["*Smart Previews.lrdata"], "maxDepth": 4 },
      "appBundleIDs": ["com.adobe.LightroomClassicCC7"],
      "safety": "safe", "regenerates": true, "regenCost": "high", "minAgeDays": 60
    },
    {
      "id": "steam-shader-cache",
      "name": "Steam shader cache",
      "summary": "Pre-compiled graphics shaders. Removing them causes stutter the next time each game is played.",
      "category": "gaming",
      "paths": ["~/Library/Application Support/Steam/steamapps/shadercache"],
      "match": { "kind": "contents" },
      "appBundleIDs": ["com.valvesoftware.steam"],
      "safety": "safe", "regenerates": true, "regenCost": "medium", "minAgeDays": 30,
      "profileModes": { "gamer": "protect" }
    },
    {
      "id": "steam-leftovers",
      "name": "Steam temporary files",
      "summary": "Unfinished downloads, temp files and Steam's web cache.",
      "category": "gaming",
      "paths": [
        "~/Library/Application Support/Steam/steamapps/downloading",
        "~/Library/Application Support/Steam/steamapps/temp",
        "~/Library/Application Support/Steam/appcache/httpcache",
        "~/Library/Application Support/Steam/config/htmlcache"
      ],
      "match": { "kind": "itself" },
      "appBundleIDs": ["com.valvesoftware.steam"],
      "safety": "safe", "regenerates": true, "regenCost": "low", "minAgeDays": 7
    }
  ]
}
"""#
}
