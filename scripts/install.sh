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

# Quit a running copy so it can be replaced.
osascript -e 'tell application id "io.github.rsidorko.sweep" to quit' >/dev/null 2>&1 || true
sleep 1

rm -rf "$DEST"
ditto "$source_app" "$DEST"
# Builds from GitHub aren't notarized; this stops Gatekeeper from blocking the first launch.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

open "$DEST"
echo "Installed $DEST. Look for the sparkles icon in your menu bar."
