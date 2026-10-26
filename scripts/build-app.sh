#!/bin/bash
# Builds build/Sweep.app from the Swift package.
#   UNIVERSAL=1      build for both Apple silicon and Intel
#   SIGN_IDENTITY=…  sign with a Developer ID instead of ad hoc ("-")
set -euo pipefail

cd "$(dirname "$0")/.."

ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="build/Sweep.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Sweep" "$APP/Contents/MacOS/Sweep"
cp Bundle/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --options runtime --timestamp=none --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --verbose=1 "$APP"

echo "Built $APP"
