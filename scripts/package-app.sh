#!/bin/bash
# Packages the SwiftPM build into a proper .app bundle.
# Usage: scripts/package-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_DIR=".build/OpenRouterWidget.app"

echo "Building ($CONFIG)…"
swift build -c "$CONFIG"

echo "Assembling ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp ".build/$CONFIG/OpenRouterWidget" "$APP_DIR/Contents/MacOS/OpenRouterWidget"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>OpenRouter Widget</string>
    <key>CFBundleDisplayName</key>
    <string>OpenRouter Widget</string>
    <key>CFBundleIdentifier</key>
    <string>dev.gsingh.openrouter-widget</string>
    <key>CFBundleExecutable</key>
    <string>OpenRouterWidget</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>OpenRouter Widget — open-source macOS menu-bar utility</string>
</dict>
</plist>
PLIST

echo "Ad-hoc codesigning…"
codesign --force --sign - "$APP_DIR"

echo
echo "Done: $APP_DIR"
echo "Move it to /Applications (or anywhere outside .build), then open it:"
echo "  open $APP_DIR"
echo "Launch at Login requires the app to live outside .build — move or copy it first."
