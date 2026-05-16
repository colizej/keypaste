#!/usr/bin/env bash
# Build a release .dmg of KeyPaste for the given version.
#
# Wraps swift build -c release, assembles the .app bundle with the
# version baked into Info.plist (CFBundleShortVersionString +
# CFBundleVersion), bakes the icon, ad-hoc signs with the stable
# bundle identifier, and finally packs everything into a compressed
# .dmg via hdiutil (no homebrew dependency).
#
# Usage:
#   ./scripts/release.sh 0.1.0      # explicit version
#   ./scripts/release.sh            # derive from `git describe --tags`,
#                                     falling back to a commit-hash dev version
#
# Output:
#   app/dist/KeyPaste-<version>.dmg   (gitignored)

set -euo pipefail

cd "$(dirname "$0")/.."   # → app/

if [ $# -ge 1 ]; then
    VERSION="$1"
elif TAG="$(git describe --tags --abbrev=0 2>/dev/null)"; then
    VERSION="${TAG#v}"
else
    VERSION="0.0.0-$(git rev-parse --short HEAD)"
fi

echo "[release] Building KeyPaste v$VERSION"

# ---- 1. Release Swift build --------------------------------------------------

swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/KeyPaste"
[ -x "$BIN" ] || { echo "error: $BIN missing or not executable" >&2; exit 1; }

# ---- 2. Assemble .app bundle -------------------------------------------------

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

# Patch the version into Info.plist (CFBundleVersion + ShortVersionString).
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION"             "$CONTENTS/Info.plist"

# ---- 3. Bake AppIcon.icns from ../keypaste.png -------------------------------

if [ -f "$ICON_SRC" ]; then
    echo "[release] Baking icon from $ICON_SRC"
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
    echo "[release] warning: $ICON_SRC not found — .app will use default icon"
fi

# ---- 4. Ad-hoc codesign ------------------------------------------------------
# Stable identifier so TCC sees the same KeyPaste across rebuilds. When we
# enrol in the Apple Developer Program we'll swap `-` for the Developer ID
# certificate and notarize.

codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP" 2>&1 \
    | grep -v "replacing existing signature" || true

# ---- 5. Pack into .dmg -------------------------------------------------------

DMG="dist/KeyPaste-$VERSION.dmg"
rm -f "$DMG"

# A two-step build via UDRW (read-write) → UDZO (compressed read-only)
# would let us drop a background image and a Drag-to-Applications symlink
# at the cost of `brew install create-dmg`. For v0.1 the bare UDZO is
# fine: the user double-clicks the .dmg and drags the app to /Applications
# manually.
hdiutil create \
    -volname "KeyPaste $VERSION" \
    -srcfolder "$APP" \
    -ov \
    -format UDZO \
    "$DMG" > /dev/null

echo
echo "Built: app/$DMG"
echo "Size:  $(du -h "$DMG" | awk '{print $1}')"
echo
echo "Local test:   open '$(pwd)/$DMG'"
echo "Publish via:  gh release create v$VERSION '$(pwd)/$DMG' \\"
echo "                --title 'KeyPaste v$VERSION' \\"
echo "                --notes-file ../CHANGELOG.md"
