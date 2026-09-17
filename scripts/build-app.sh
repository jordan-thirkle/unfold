#!/usr/bin/env bash
#
# Assembles Unfold.app.
#
# The bundle is required for two things a bare SPM executable cannot do:
#   * Launch at login via SMAppService.mainApp (needs a bundle identifier)
#   * behaving like an agent app rather than a terminal process (LSUIElement)
#
# Ad-hoc signing is enough for your own Mac. Giving the app to other people
# needs a Developer ID certificate and notarisation, or Gatekeeper warns them.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="Unfold"
BUNDLE_ID="com.byjtt.unfold"
VERSION="0.1.0"
MIN_MACOS="14.0"
OUT="$ROOT/build/$APP_NAME.app"

echo "==> Building the release binary"
swift build -c release --product "$APP_NAME"

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/$APP_NAME"

if [ ! -f "$BIN" ]; then
  echo "error: expected a binary at $BIN and found none" >&2
  exit 1
fi

echo "==> Assembling $OUT"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$APP_NAME"

cat > "$OUT/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT licensed. By JTT.</string>
</dict>
</plist>
PLIST

echo "==> Signing ad-hoc"
codesign --force --sign - --identifier "$BUNDLE_ID" "$OUT"

echo "==> Verifying the signature"
codesign --verify --verbose=2 "$OUT"

echo
echo "Built: $OUT"
echo "Open it with:  open \"$OUT\""
echo
echo "Unfold lives in the menu bar. If you don't see it, check that the app"
echo "is running:  pgrep -fl Unfold"
