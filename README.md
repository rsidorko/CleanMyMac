# Sweep

A macOS menu bar app that frees up storage. You tell it what you use your Mac for (everyday use, office work, development, creative work, gaming) and it cleans thoroughly where that's safe and carefully where your work depends on the files.

Sweep lives in the menu bar next to Control Center. It opens in a simple mode: one Scan button, an on/off card for each kind of junk, and one Clean button. Tap **Pro** for every rule and file, items that need review, app support files, leftovers from deleted apps, settings and undo history.

## Install

Requires macOS 14 (Sonoma) or later.

**From a build:** download `Sweep.zip` from the [latest build](https://github.com/rsidorko/CleanMyMac/releases/tag/latest-build), then run:

```sh
./scripts/install.sh ~/Downloads/Sweep.zip
```

If your browser already unzipped it, pass `~/Downloads/Sweep.app` instead. Without a checkout of this repo, the same thing by hand:

```sh
ditto -x -k ~/Downloads/Sweep.zip /Applications && xattr -dr com.apple.quarantine /Applications/Sweep.app && open /Applications/Sweep.app
```

Builds are ad-hoc signed and not notarized, so the quarantine flag has to be removed before macOS will open the app.

**With the GitHub CLI:** `./scripts/install.sh --download`

**From source** (needs Xcode or the Command Line Tools, Swift 5.9+):

```sh
git clone https://github.com/rsidorko/CleanMyMac.git
cd CleanMyMac
./scripts/install.sh
```

### After installing

- **Put it next to Control Center:** macOS places new menu bar icons itself. Hold ⌘ and drag the sparkles icon next to Control Center; macOS remembers the spot.
- **Full Disk Access:** setup asks for it so Sweep can read the Trash, Mail downloads and app containers. System Settings › Privacy & Security › Full Disk Access › turn on Sweep. Installing a new build resets this, because each build has a new ad-hoc signature.

## How profiles work

Every cleanup rule belongs to a category. Your profiles decide how each category is treated:

| Treatment | Age limit | Checked by default |
|---|---|---|
| Aggressive (data from tools you don't use) | half | even when costly to rebuild |
| Standard (system junk, downloads) | as written | unless costly to rebuild |
| Careful (your own tools' data) | doubled, at least 30 days | only if cheap to rebuild |
| Protect | not scanned | never |

With several profiles selected, the most careful treatment wins.

## Safety

- Every path is checked against a fixed guard when it's found and again right before removal: only inside your home folder (and `/Applications` for uninstalls), never Keychains, iCloud Drive, Mail, Messages, `.ssh`, photo or music libraries, and symlinked parents are resolved.
- Caches of apps that are open are left unchecked.
- Data that rebuilds itself is deleted right away so the space comes back immediately. Everything else goes to the Trash and can be put back with Undo. "Always use the Trash" in Pro › Settings changes this.

## Development

```sh
swift build
swift test
swift run Sweep              # runs without the .app bundle
./scripts/build-app.sh       # builds build/Sweep.app (UNIVERSAL=1 for arm64 + x86_64)
```

- `Sources/SweepCore`: rules, profiles, scanner, cleaner, history, app inventory. No UI.
- `Sources/Sweep`: the SwiftUI menu bar app.
- Rules live in `Sources/SweepCore/Rules/DefaultRules.swift` as JSON. A file at `~/Library/Application Support/Sweep/rules.json` with the same shape overrides rules by id.
- `docs/sweep-prototype.html`: an interactive browser prototype of the panel.

CI on GitHub Actions builds, tests and publishes the app to the `latest-build` pre-release on every push.

## Roadmap

Simulator cleanup via `simctl`, Docker images, duplicate finder, a privileged helper for system-wide caches, scheduled cleaning.

Sweep is not affiliated with MacPaw or CleanMyMac.
