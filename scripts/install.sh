#!/bin/bash
# Installs Sweep into /Applications and opens it.
#
#   ./scripts/install.sh                 build from this checkout (needs Xcode or the Command Line Tools)
#   ./scripts/install.sh ~/Downloads/Sweep.zip   install a downloaded build (a .zip or a .app)
#   ./scripts/install.sh --download      download the latest build
#
# Or, without a checkout:
#   curl -fsSL https://raw.githubusercontent.com/rsidorko/CleanMyMac/claude/menu-bar-app/scripts/install.sh | bash
set -euo pipefail

REPO="rsidorko/CleanMyMac"
DEST="/Applications/Sweep.app"
ZIP_URL="https://github.com/$REPO/releases/download/latest-build/Sweep.zip"
# Empty when the script is piped into bash, so it downloads instead of building.
SCRIPT="${BASH_SOURCE[0]:-}"
ROOT=""
if [ -n "$SCRIPT" ] && [ -f "$(dirname "$SCRIPT")/../Package.swift" ]; then
    ROOT="$(cd "$(dirname "$SCRIPT")/.." && pwd)"
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

source_app=""
case "${1:-}" in
    *.zip)
        ditto -x -k "$1" "$WORK"
        source_app="$WORK/Sweep.app"
        ;;
    *.app|*.app/)
        source_app="${1%/}"
        ;;
    --download)
        echo "Downloading the latest Sweep build…"
        curl -fL --progress-bar -o "$WORK/Sweep.zip" "$ZIP_URL"
        ditto -x -k "$WORK/Sweep.zip" "$WORK"
        source_app="$WORK/Sweep.app"
        ;;
    "")
        if [ -n "$ROOT" ]; then
            command -v swift >/dev/null || { echo "Swift isn't installed. Run: xcode-select --install, or use --download"; exit 1; }
            "$ROOT/scripts/build-app.sh"
            source_app="$ROOT/build/Sweep.app"
        else
            echo "Downloading the latest Sweep build…"
            curl -fL --progress-bar -o "$WORK/Sweep.zip" "$ZIP_URL"
            ditto -x -k "$WORK/Sweep.zip" "$WORK"
            source_app="$WORK/Sweep.app"
        fi
        ;;
    *)
        echo "Usage: $0 [path/to/Sweep.zip | path/to/Sweep.app | --download]"
        exit 1
        ;;
esac

[ -d "$source_app" ] || { echo "Couldn't find Sweep.app in what was given."; exit 1; }

# Uninstall the previous version completely before installing the new one.
BUNDLE_ID="io.github.rsidorko.sweep"
echo "Removing the previous version of Sweep…"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -f "/Sweep.app/Contents/MacOS/Sweep" >/dev/null || break
    sleep 0.5
done
pkill -f "/Sweep.app/Contents/MacOS/Sweep" 2>/dev/null || true
# A scripts/dev.sh loop and its debug build would leave a second icon in the menu bar.
pkill -f "scripts/dev.sh" 2>/dev/null || true
pkill -f "/.build/.*/Sweep$" 2>/dev/null || true
for old in "$DEST" "$HOME/Applications/Sweep.app"; do
    if [ -d "$old" ] && [ "$old" != "$source_app" ]; then
        rm -rf "$old"
        echo "  Removed $old"
    fi
done
# Each build has a new ad-hoc signature, so the old Full Disk Access entry no longer applies. Clearing it
# leaves a single, working Sweep entry in System Settings once access is granted again.
tccutil reset SystemPolicyAllFiles "$BUNDLE_ID" >/dev/null 2>&1 || true

ditto "$source_app" "$DEST"
# Builds from GitHub aren't notarized; this stops Gatekeeper from blocking the first launch.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

open "$DEST"
echo "Installed $DEST. Look for the trash can icon in your menu bar."
echo "Turn on Sweep again in System Settings › Privacy & Security › Full Disk Access when it asks."
