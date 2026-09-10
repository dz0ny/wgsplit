#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/WGSplit.app"
# The in-app updater compares CFBundleShortVersionString against release tags,
# so the bundled version has to come from the tag, not a constant in the plist.
VERSION="${VERSION:-$(git -C "$ROOT" describe --tags --always 2>/dev/null || echo 0.0.0)}"
SIGN_ID="${SIGN_ID:--}"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/WGSplitApp" "$APP/Contents/MacOS/WGSplitApp"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
sed "s/__VERSION__/${VERSION#v}/g" "$ROOT/Scripts/Info.plist" > "$APP/Contents/Info.plist"
# Ship everything the in-app installer needs, so the bundle is self-contained
# and can live in /Applications (which SMAppService also wants).
cp "$ROOT/.build/release/wgsplitd"            "$APP/Contents/Resources/wgsplitd"
cp "$ROOT/Scripts/install-daemon.sh"          "$APP/Contents/Resources/install-daemon.sh"
cp "$ROOT/Scripts/co.niteo.wgsplit.plist"     "$APP/Contents/Resources/co.niteo.wgsplit.plist"
chmod +x "$APP/Contents/Resources/install-daemon.sh"
[ -x "$ROOT/Resources/sing-box" ] && cp "$ROOT/Resources/sing-box" "$APP/Contents/Resources/sing-box"

# Notarization requires the hardened runtime and a secure timestamp on every
# nested executable, so sign them individually rather than with --deep.
sign_options=(--force --sign "$SIGN_ID")
[ "$SIGN_ID" != "-" ] && sign_options+=(--options runtime --timestamp)
for nested in wgsplitd sing-box; do
  [ -e "$APP/Contents/Resources/$nested" ] &&
    codesign "${sign_options[@]}" "$APP/Contents/Resources/$nested"
done
codesign "${sign_options[@]}" "$APP"
codesign --verify --verbose "$APP"
echo "built $APP ($VERSION)"
