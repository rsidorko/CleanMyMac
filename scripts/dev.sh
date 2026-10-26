#!/bin/bash
# Live development: rebuilds Sweep and relaunches it in the menu bar every time a source file changes.
# The panel also opens in a floating preview window, so changes show up without clicking the icon.
#
#   ./scripts/dev.sh             watch and relaunch (Ctrl-C to stop)
#   SWEEP_PREVIEW=0 ./scripts/dev.sh   menu bar only, no preview window
#
# Uses fswatch when it's installed (brew install fswatch); otherwise checks for changes every second.
#
# Full Disk Access: the debug build is a bare binary started from your terminal, so macOS checks the
# terminal's access, not Sweep's. Test the permission flow with ./scripts/install.sh instead.
set -uo pipefail

cd "$(dirname "$0")/.."

# An installed copy would put a second icon in the menu bar.
osascript -e 'tell application id "io.github.rsidorko.sweep" to quit' >/dev/null 2>&1 || true

BIN="$(swift build --show-bin-path)/Sweep"
pid=""

# Only one loop at a time; a second one would put a second icon in the menu bar.
LOCK=".build/dev.pid"
if [ -f "$LOCK" ] && other="$(cat "$LOCK")" && [ "$other" != "$$" ] && kill -0 "$other" 2>/dev/null; then
    echo "Stopping the dev.sh that was already running (pid $other)."
    kill "$other"
    while kill -0 "$other" 2>/dev/null; do sleep 0.2; done
fi
pkill -f "^$BIN\$" 2>/dev/null || true
echo $$ > "$LOCK"

stop_app() {
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
    fi
    pid=""
}
trap 'stop_app; exit 0' INT TERM

rebuild() {
    printf '\n%s  Building…\n' "$(date +%H:%M:%S)"
    if output="$(swift build 2>&1)"; then
        echo "$output" | grep -E "warning:" || true
        stop_app
        SWEEP_PREVIEW="${SWEEP_PREVIEW:-1}" "$BIN" &
        pid=$!
        echo "Running the new build. Edit any file in Sources/ to rebuild."
    else
        # Keep the last good build running so the menu bar doesn't go empty while you fix the error.
        echo "$output" | grep -E "error|note:" | grep -v "^\[" || echo "$output"
        echo "Build failed. The previous build is still running."
    fi
}

signature() {
    find Sources Package.swift -type f \( -name '*.swift' -o -name 'Package.swift' \) -print0 \
        | xargs -0 stat -f '%m %z %N' | md5
}

rebuild

if command -v fswatch >/dev/null; then
    while read -r _; do
        rebuild
    done < <(fswatch -o --latency 0.3 Sources Package.swift)
else
    last="$(signature)"
    while true; do
        sleep 1
        current="$(signature)"
        if [ "$current" != "$last" ]; then
            last="$current"
            rebuild
        fi
    done
fi
