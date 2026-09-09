#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/WGSplit.app"
swift build -c release --product WGSplitApp
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/WGSplitApp" "$APP/Contents/MacOS/WGSplitApp"
cp "$ROOT/Scripts/Info.plist" "$APP/Contents/Info.plist"
[ -x "$ROOT/Resources/sing-box" ] && cp "$ROOT/Resources/sing-box" "$APP/Contents/Resources/sing-box"
codesign --force --deep --sign - "$APP"
echo "built $APP"
