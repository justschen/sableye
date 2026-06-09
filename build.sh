#!/bin/bash
# Builds Sableye.app from Sources/main.swift (no Xcode required).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Sableye"
BUNDLE="${APP_NAME}.app"
BUNDLE_ID="com.local.sableye"

echo "==> Cleaning previous build"
rm -rf "$BUNDLE"

echo "==> Creating bundle layout"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

echo "==> Compiling Swift (universal: arm64 + x86_64)"
swiftc -O \
    -target arm64-apple-macos13.0 \
    -framework Cocoa \
    -o "$BUNDLE/Contents/MacOS/${APP_NAME}-arm64" \
    Sources/main.swift
swiftc -O \
    -target x86_64-apple-macos13.0 \
    -framework Cocoa \
    -o "$BUNDLE/Contents/MacOS/${APP_NAME}-x86_64" \
    Sources/main.swift

echo "==> Creating universal binary"
lipo -create \
    "$BUNDLE/Contents/MacOS/${APP_NAME}-arm64" \
    "$BUNDLE/Contents/MacOS/${APP_NAME}-x86_64" \
    -output "$BUNDLE/Contents/MacOS/$APP_NAME"
rm -f "$BUNDLE/Contents/MacOS/${APP_NAME}-arm64" "$BUNDLE/Contents/MacOS/${APP_NAME}-x86_64"

echo "==> Writing Info.plist"
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Sableye</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Generating app icon"
ICON_SVG="Resources/AppIcon.svg"
if [ -f "$ICON_SVG" ] && command -v qlmanage >/dev/null 2>&1 \
   && command -v sips >/dev/null 2>&1 && command -v iconutil >/dev/null 2>&1; then
    TMPICON="$(mktemp -d)"
    ICONSET="$TMPICON/AppIcon.iconset"
    mkdir -p "$ICONSET"
    # Rasterize the SVG to a 1024px master via QuickLook (WebKit — full SVG fidelity).
    qlmanage -t -s 1024 -o "$TMPICON" "$ICON_SVG" >/dev/null 2>&1 || true
    MASTER="$TMPICON/$(basename "$ICON_SVG").png"
    if [ -f "$MASTER" ]; then
        for spec in 16:16x16 32:16x16@2x 32:32x32 64:32x32@2x \
                    128:128x128 256:128x128@2x 256:256x256 512:256x256@2x \
                    512:512x512 1024:512x512@2x; do
            px="${spec%%:*}"; label="${spec##*:}"
            sips -z "$px" "$px" "$MASTER" --out "$ICONSET/icon_${label}.png" >/dev/null 2>&1
        done
        iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns" \
            && echo "   -> Contents/Resources/AppIcon.icns"
    else
        echo "   (icon render failed; building without a custom icon)"
    fi
    rm -rf "$TMPICON"
else
    echo "   (skipped: need $ICON_SVG plus qlmanage/sips/iconutil)"
fi

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$BUNDLE" 2>/dev/null || echo "   (codesign skipped)"

echo "==> Done: $(pwd)/$BUNDLE"
