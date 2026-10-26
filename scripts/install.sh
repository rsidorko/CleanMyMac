#!/bin/bash
# Installs Sweep into /Applications and opens it.
#
#   ./scripts/install.sh                 build from this checkout (needs Xcode or the Command Line Tools)
#   ./scripts/install.sh ~/Downloads/Sweep.zip   install a downloaded build (a .zip or a .app)
#   ./scripts/install.sh --download      download the latest build with the GitHub CLI (gh)
set -euo pipefail

REPO="rsidorko/CleanMyMac"
DEST="/Applications/Sweep.app"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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
        command -v gh >/dev/null || { echo "The GitHub CLI isn't installed. Get it with: brew install gh"; exit 1; }
        gh release download latest-build --repo "$REPO" --pattern Sweep.zip --dir "$WORK"
        ditto -x -k "$WORK/Sweep.zip" "$WORK"
        source_app="$WORK/Sweep.app"
        ;;
    "")
        command -v swift >/dev/null || { echo "Swift isn't installed. Run: xcode-select --install"; exit 1; }
        "$ROOT/scripts/build-app.sh"
        source_app="$ROOT/build/Sweep.app"
        ;;
    *)
        echo "Usage: $0 [path/to/Sweep.zip | path/to/Sweep.app | --download]"
        exit 1
        ;;
esac

[ -d "$source_app" ] || { echo "Couldn't find Sweep.app in what was given."; exit 1; }

# Quit a running copy so it can be replaced.
osascript -e 'tell application id "io.github.rsidorko.sweep" to quit' >/dev/null 2>&1 || true
sleep 1

rm -rf "$DEST"
ditto "$source_app" "$DEST"
# Builds from GitHub aren't notarized; this stops Gatekeeper from blocking the first launch.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

open "$DEST"
echo "Installed $DEST. Look for the sparkles icon in your menu bar."
