#!/usr/bin/env bash
# Installs the wgsplit LaunchDaemon. Run with sudo, or via the app's
# "Install Helper…" menu item which elevates through osascript.
#
# Sources binaries from an app bundle when it lives in Contents/Resources,
# otherwise from a development checkout.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="/Library/PrivilegedHelperTools/wgsplit"
PLIST="/Library/LaunchDaemons/co.niteo.wgsplit.plist"

if [ -x "$HERE/wgsplitd" ] && [ -x "$HERE/sing-box" ]; then
  SRC_DAEMON="$HERE/wgsplitd"; SRC_SINGBOX="$HERE/sing-box"; SRC_PLIST="$HERE/co.niteo.wgsplit.plist"
else
  ROOT="$(cd "$HERE/.." && pwd)"
  SRC_DAEMON="$ROOT/.build/release/wgsplitd"
  SRC_SINGBOX="$ROOT/Resources/sing-box"
  SRC_PLIST="$ROOT/Scripts/co.niteo.wgsplit.plist"
  [ -x "$SRC_DAEMON" ] || { echo "build first: swift build -c release" >&2; exit 1; }
  [ -x "$SRC_SINGBOX" ] || { echo "vendor first: ./Scripts/vendor-singbox.sh" >&2; exit 1; }
fi

launchctl bootout system "$PLIST" 2>/dev/null || true

install -d -m 0755 -o root -g wheel "$DEST"
install -m 0755 -o root -g wheel "$SRC_DAEMON" "$DEST/wgsplitd"
install -m 0755 -o root -g wheel "$SRC_SINGBOX" "$DEST/sing-box"
install -d -m 0700 -o root -g wheel "/Library/Application Support/WGSplit"
install -m 0644 -o root -g wheel "$SRC_PLIST" "$PLIST"

launchctl bootstrap system "$PLIST"
echo "installed."
