#!/usr/bin/env bash
#
# Assemble a real KeyPaste.app bundle around the SwiftPM binary so TCC
# (Accessibility, Input Monitoring) recognises it. A bare CLI binary
# either fails to appear in the Privacy list or is denied silently;
# wrapping it in a proper .app with a stable CFBundleIdentifier and
# LSUIElement = YES is what makes the toggle stick.
#
# Output: app/.build/debug/KeyPaste.app
# Run with: open app/.build/debug/KeyPaste.app
#
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$REPO/app"
BUILD_DIR="$APP_DIR/.build/debug"
BINARY="$BUILD_DIR/KeyPaste"
APP_BUNDLE="$BUILD_DIR/KeyPaste.app"
BUNDLE_ID="com.dramius.keypaste"

echo "[make-app] swift build…"
swift build --package-path "$APP_DIR"

if [ ! -f "$BINARY" ]; then
    echo "[make-app] expected binary missing: $BINARY" >&2
    exit 1
fi

echo "[make-app] (re)assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/KeyPaste"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.dramius.keypaste</string>
    <key>CFBundleName</key>
    <string>KeyPaste</string>
    <key>CFBundleDisplayName</key>
    <string>KeyPaste</string>
    <key>CFBundleExecutable</key>
    <string>KeyPaste</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT-licensed. github.com/colizej/keypaste</string>
</dict>
</plist>
PLIST

echo "[make-app] ad-hoc codesign with identifier $BUNDLE_ID"
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

echo
echo "Built: $APP_BUNDLE"
echo
echo "Next:"
echo "  open '$APP_BUNDLE'"
echo
echo "If macOS doesn't show KeyPaste in Privacy → Accessibility yet,"
echo "click + and pick:"
echo "  $APP_BUNDLE"
