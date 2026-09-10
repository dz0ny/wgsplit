#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/WGSplit.app"
DMG="$ROOT/dist/WGSplit.dmg"
if [ ! -d "$APP" ]; then
  echo "error: $APP is missing. Copy your signed app to dist/WGSplit.app, or run make build first." >&2
  exit 1
fi
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/WGSplit.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname WGSplit -srcfolder "$STAGE" -ov -format UDZO "$DMG"
# Notarization checks the image itself, not only the app inside it.
SIGN_ID="${SIGN_ID:--}"
[ "$SIGN_ID" != "-" ] && codesign --force --sign "$SIGN_ID" --timestamp "$DMG"
echo "built $DMG"
