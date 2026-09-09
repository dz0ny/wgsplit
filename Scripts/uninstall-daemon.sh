#!/usr/bin/env bash
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
launchctl bootout system /Library/LaunchDaemons/co.niteo.wgsplit.plist 2>/dev/null || true
rm -f /Library/LaunchDaemons/co.niteo.wgsplit.plist
rm -rf /Library/PrivilegedHelperTools/wgsplit
echo "removed. State kept at /Library/Application Support/WGSplit — delete manually if wanted."
