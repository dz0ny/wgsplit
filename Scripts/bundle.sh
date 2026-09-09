#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/WGSplit.app"
swift build -c release --product WGSplitApp --product wgsplitd
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/WGSplitApp" "$APP/Contents/MacOS/WGSplitApp"
cp "$ROOT/Scripts/Info.plist" "$APP/Contents/Info.plist"
# Ship everything the in-app installer needs, so the bundle is self-contained
# and can live in /Applications (which SMAppService also wants).
cp "$ROOT/.build/release/wgsplitd"            "$APP/Contents/Resources/wgsplitd"
cp "$ROOT/Scripts/install-daemon.sh"          "$APP/Contents/Resources/install-daemon.sh"
cp "$ROOT/Scripts/co.niteo.wgsplit.plist"     "$APP/Contents/Resources/co.niteo.wgsplit.plist"
chmod +x "$APP/Contents/Resources/install-daemon.sh"
[ -x "$ROOT/Resources/sing-box" ] && cp "$ROOT/Resources/sing-box" "$APP/Contents/Resources/sing-box"
codesign --force --deep --sign - "$APP"
echo "built $APP"
