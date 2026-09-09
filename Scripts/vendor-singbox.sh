#!/usr/bin/env bash
# Puts the pinned sing-box into Resources/ for bundling and tests.
# Reuses an already-installed binary of the right version; downloads otherwise.
set -euo pipefail
VERSION="1.14.0"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/Resources"
mkdir -p "$DEST"

if local_bin="$(command -v sing-box 2>/dev/null)" \
   && "$local_bin" version 2>/dev/null | grep -q "sing-box version ${VERSION}\b"; then
  echo "reusing $local_bin (version ${VERSION})"
  cp "$local_bin" "$DEST/sing-box"
  chmod +x "$DEST/sing-box"
  "$DEST/sing-box" version | head -1
  exit 0
fi

case "$(uname -m)" in
  arm64) GOARCH=arm64 ;;
  x86_64) GOARCH=amd64 ;;
  *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
esac
TARBALL="sing-box-${VERSION}-darwin-${GOARCH}.tar.gz"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/${TARBALL}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo "downloading ${URL}"
curl -fsSL "$URL" -o "$TMP/$TARBALL"
tar -xzf "$TMP/$TARBALL" -C "$TMP"
find "$TMP" -type f -name sing-box -perm -u+x -exec cp {} "$DEST/sing-box" \;
chmod +x "$DEST/sing-box"
"$DEST/sing-box" version | head -1
