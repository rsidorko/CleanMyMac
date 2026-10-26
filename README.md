# Sweep

A menu bar storage cleaner for macOS that tunes itself to what you use your Mac for. Cleaning takes one click, and every detail is one switch away in Pro.

Sweep sits in the menu bar next to Control Center and looks like it: a compact Liquid Glass panel with rounded corners (on macOS 26 and later; earlier versions get the vibrant popover material), your accent color, and standard switches, buttons and grouped lists. Tell it what the Mac is for (everyday use, office and school, development, creative work, gaming). It cleans thoroughly where that's safe and carefully where your work depends on the files.

## Using Sweep

- **Scan and clean.** Click **Scan**, switch off any kind of junk you want to keep, then click **Clean**. Simple mode only offers safe data that rebuilds itself, and nothing is removed until you confirm.
- **Turn on Pro.** The Pro switch in the header shows every rule and file, items that need review, app support files, leftovers from deleted apps, settings and undo history.
- **Change profiles.** In Pro › Settings, add or remove a profile and scan again. Each rule's treatment follows the table below.
- **Undo.** Anything that went to the Trash can be put back from the finished screen or from Pro › Settings › Recent cleanups.
- **Uninstall any app.** The Uninstall tab lists every app in Applications, searchable and sortable by name, size or last use. Choose one to see everything it keeps, grouped by kind: app data, sandboxed and shared containers, caches, preferences, background items, web data, saved window state, logs and crash reports. That includes data of its login items and extensions. One click moves the app and all of it to the Trash. Pro mode lets you leave individual items out. Sweep stops the app's background agents first. If an app belongs to the system (App Store and admin installs), Finder asks for your password. Shared data under a developer's team ID is only removed when no other app from that developer is installed.
- **Remove unused apps.** The Unused tab lists apps you haven't opened in months, plus data left behind by apps you've already deleted. Removing one moves the app and its support files to the Trash together.

## How your profiles shape each rule

Every cleanup rule belongs to a category, and your profiles decide how that category is treated:

| Treatment | Age limit | Checked by default |
|---|---|---|
| Aggressive: data from tools you don't use | half | even when costly to rebuild |
| Standard: system junk and downloads | as written | unless costly to rebuild |
| Careful: your own tools' data | doubled, at least 30 days | only if cheap to rebuild |
| Protect | not scanned | never |

Developer, creative and game data is treated **carefully** by the profile that uses it and **aggressively** by everyone else. System junk and downloads are always **standard**. A few rules have their own settings:

- With Development, Xcode build data, old device support files and idle `node_modules` and Rust build folders stay **standard**. They rebuild, and they are usually the biggest wins.
- With Gaming, the Steam shader cache is **protected**, because removing it makes games stutter.

When you pick several profiles and they disagree, the most careful treatment wins. A developer who also edits photos keeps their Lightroom previews.

Rules marked **Review** (Trash, iPhone backups, Xcode archives, forgotten downloads) are never checked for you, whatever the profile.

## Safety

- Every path is checked against a fixed guard when it's found and again right before removal. Sweep only works inside your home folder (and `/Applications` for uninstalls). It never touches Keychains, iCloud Drive, Mail, Messages, `.ssh`, or photo and music libraries, and it resolves symlinked parent folders before deciding.
- Caches of apps that are open are left unchecked.
- Data that rebuilds itself is deleted right away so the space comes back immediately. Everything else goes to the Trash and can be put back with Undo. "Always use the Trash" in Pro › Settings changes this.
- Leftovers from deleted apps are only offered when no installed app from the same developer remains and nothing has written to them for 30 days.

## Install

Requires macOS 14 (Sonoma) or later.

**One command** (downloads the latest build, installs it in /Applications and opens it):

```sh
curl -fsSL https://raw.githubusercontent.com/rsidorko/CleanMyMac/claude/menu-bar-app/scripts/install.sh | bash
```

**From a downloaded build:** download `Sweep.zip` from the [latest build](https://github.com/rsidorko/CleanMyMac/releases/tag/latest-build), then run:

```sh
./scripts/install.sh ~/Downloads/Sweep.zip
```

If your browser already unzipped it, pass `~/Downloads/Sweep.app` instead. Without a checkout of this repo, the same thing by hand:

```sh
ditto -x -k ~/Downloads/Sweep.zip /Applications && xattr -dr com.apple.quarantine /Applications/Sweep.app && open /Applications/Sweep.app
```

Builds are ad-hoc signed and not notarized, so the quarantine flag has to be removed before macOS will open the app.

**From source** (needs Xcode or the Command Line Tools, Swift 5.9+):

```sh
git clone https://github.com/rsidorko/CleanMyMac.git
cd CleanMyMac
./scripts/install.sh
```

### After installing

- **Put it next to Control Center.** macOS places new menu bar icons itself. Hold ⌘ and drag the trash can icon next to Control Center, and macOS remembers the spot.
- **Allow Full Disk Access.** Setup asks for it so Sweep can read the Trash, Mail downloads and app containers: System Settings › Privacy & Security › Full Disk Access › turn on Sweep. Installing a new build resets this, because each build has a new ad-hoc signature.

## Development

```sh
./scripts/dev.sh             # live: rebuilds and relaunches Sweep in the menu bar on every save
swift build
swift test                   # needs Xcode (XCTest isn't in the Command Line Tools)
swift run Sweep              # runs once without the .app bundle
./scripts/build-app.sh       # builds build/Sweep.app (UNIVERSAL=1 for arm64 + x86_64)
```

`scripts/dev.sh` quits any installed copy and runs a debug build in the menu bar. It also opens the panel at launch and keeps it open when you click elsewhere, so you can see changes without clicking the icon. After a failed build the previous build keeps running and the errors are printed. It uses `fswatch` if installed (`brew install fswatch`) and otherwise checks for changes every second. Run `SWEEP_PREVIEW=0 ./scripts/dev.sh` to have the panel behave normally. The debug build runs as a bare binary started from your terminal, so macOS checks the terminal's Full Disk Access, not Sweep's. Test the permission flow with `./scripts/install.sh`.

- `Sources/SweepCore`: rules, profiles, scanner, cleaner, history and app inventory. No UI.
- `Sources/Sweep`: the SwiftUI menu bar app. `Support/StatusPanel.swift` owns the menu bar icon and the glass panel. `Views/Style.swift` holds the shared look (sizes, grouped rows, section titles, the capacity bar).
- Rules live in `Sources/SweepCore/Rules/DefaultRules.swift` as JSON. A file at `~/Library/Application Support/Sweep/rules.json` with the same shape overrides rules by id.
- `docs/sweep-prototype.html`: an interactive browser prototype of the panel, with a table of how your profiles treat every rule.

CI on GitHub Actions builds, tests and publishes the app to the `latest-build` pre-release on every push.

## Roadmap

Simulator cleanup via `simctl`, Docker images, duplicate finder, a privileged helper for system-wide caches, scheduled cleaning.

Sweep is not affiliated with MacPaw or CleanMyMac.
