#!/bin/bash
# Builds Sableye.app and packages it into a shareable zip.
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Sableye"
BUNDLE="${APP_NAME}.app"
ZIP="${APP_NAME}.zip"

echo "==> Building app"
./build.sh

echo "==> Stripping quarantine attributes"
xattr -cr "$BUNDLE" 2>/dev/null || true

echo "==> Creating $ZIP"
rm -f "$ZIP"
# ditto preserves the bundle structure, symlinks, and code signature.
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE" "$ZIP"

echo "==> Done: $(pwd)/$ZIP ($(du -h "$ZIP" | cut -f1))"
echo
echo "Share $ZIP. The recipient should unzip it, then (because it is not"
echo "signed with a paid Apple Developer ID) clear the download quarantine once:"
echo
echo "    xattr -dr com.apple.quarantine /path/to/${BUNDLE}"
echo
echo "...or right-click the app > Open > Open on first launch."
