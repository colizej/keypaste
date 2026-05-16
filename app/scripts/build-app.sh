#!/usr/bin/env bash
# Build a proper KeyPaste.app bundle from the SwiftPM artifact.
#
# Raw `.build/debug/KeyPaste` exits immediately when launched: NSApplication
# expects a real bundle (Info.plist, CFBundleIdentifier, NSPrincipalClass).
# This script wraps `swift build` and assembles the .app layout that macOS
# (and TCC) expect, bakes ../keypaste.png into AppIcon.icns, then ad-hoc-
# signs it with a stable identifier so the Accessibility grant survives
# rebuilds.
#
# Usage:
#   ./scripts/build-app.sh           # debug build
#   ./scripts/build-app.sh -c release
#
# Output:
#   dist/KeyPaste.app   (gitignored)

set -euo pipefail

cd "$(dirname "$0")/.."   # → app/

swift build "$@"

BIN_DIR="$(swift build --show-bin-path "$@")"
BIN="$BIN_DIR/KeyPaste"
[ -x "$BIN" ] || { echo "error: $BIN missing or not executable" >&2; exit 1; }

APP="dist/KeyPaste.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICON_SRC="../keypaste.png"
BUNDLE_ID="com.dramius.keypaste"

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BIN" "$MACOS/KeyPaste"
cp scripts/Info.plist "$CONTENTS/Info.plist"

if [ -f "$ICON_SRC" ]; then
    echo "Baking icon from $ICON_SRC"
    ICONSET="dist/AppIcon.iconset"
    ICNS="dist/AppIcon.icns"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"

    sips -z 16   16   "$ICON_SRC" --out "$ICONSET/icon_16x16.png"      >/dev/null
    sips -z 32   32   "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
    sips -z 32   32   "$ICON_SRC" --out "$ICONSET/icon_32x32.png"      >/dev/null
    sips -z 64   64   "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
    sips -z 128  128  "$ICON_SRC" --out "$ICONSET/icon_128x128.png"    >/dev/null
    sips -z 256  256  "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256  256  "$ICON_SRC" --out "$ICONSET/icon_256x256.png"    >/dev/null
    sips -z 512  512  "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512  512  "$ICON_SRC" --out "$ICONSET/icon_512x512.png"    >/dev/null
    sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

    iconutil -c icns "$ICONSET" -o "$ICNS"
    cp "$ICNS" "$RESOURCES/AppIcon.icns"
else
    echo "warning: $ICON_SRC not found, .app will use default icon"
fi

# Stable identifier so TCC sees the same KeyPaste across rebuilds.
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP" 2>&1 \
    | grep -v "replacing existing signature" || true

echo
echo "Built: $APP"
echo "Run:   open $APP"
echo "Tail:  log stream --predicate 'subsystem == \"com.dramius.keypaste\"' --info"
