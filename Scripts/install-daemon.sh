#!/usr/bin/env bash
# One-time privileged install. Run with sudo.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="/Library/PrivilegedHelperTools/wgsplit"
PLIST="/Library/LaunchDaemons/co.niteo.wgsplit.plist"

[ -x "$ROOT/.build/release/wgsplitd" ] || { echo "build first: swift build -c release" >&2; exit 1; }
[ -x "$ROOT/Resources/sing-box" ] || { echo "vendor first: ./Scripts/vendor-singbox.sh" >&2; exit 1; }

launchctl bootout system "$PLIST" 2>/dev/null || true

install -d -m 0755 -o root -g wheel "$DEST"
install -m 0755 -o root -g wheel "$ROOT/.build/release/wgsplitd" "$DEST/wgsplitd"
install -m 0755 -o root -g wheel "$ROOT/Resources/sing-box" "$DEST/sing-box"
install -d -m 0700 -o root -g wheel "/Library/Application Support/WGSplit"
install -m 0644 -o root -g wheel "$ROOT/Scripts/co.niteo.wgsplit.plist" "$PLIST"

launchctl bootstrap system "$PLIST"
sleep 1
launchctl print system/co.niteo.wgsplit | grep -E "state|pid" | head -3
echo "installed."
