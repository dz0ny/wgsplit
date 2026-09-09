#!/usr/bin/env bash
# Upload the secrets that .github/workflows/release.yml needs.
#
# Run this yourself: every value is read from your terminal (or your
# environment) and piped straight to `gh secret set`, so nothing is written to
# disk, passed on a command line where `ps` could see it, or echoed back.
#
#   ./Scripts/set-release-secrets.sh
#
# Values already exported in the environment are used as-is, which is how to
# drive this from a password manager:
#
#   MACOS_CERT_PASSWORD=$(op read 'op://Private/wgsplit cert/password') \
#     ./Scripts/set-release-secrets.sh
set -euo pipefail

REPO="${REPO:-dz0ny/wgsplit}"

command -v gh >/dev/null || { echo "gh is not installed"; exit 1; }
gh auth status >/dev/null || { echo "run: gh auth login"; exit 1; }

# Prompt only for what the environment does not already provide.
# $1 name, $2 prompt, $3 "hidden" to keep the value off the screen.
ask() {
  local name="$1" prompt="$2" hidden="${3:-}" value="${!1:-}"
  if [ -z "$value" ]; then
    if [ "$hidden" = hidden ]; then
      read -rsp "$prompt: " value < /dev/tty
      echo
    else
      read -rp "$prompt: " value < /dev/tty
    fi
  fi
  [ -n "$value" ] || { echo "$name cannot be empty"; exit 1; }
  printf '%s' "$value" | gh secret set "$name" --repo "$REPO"
}

echo "Setting release secrets on $REPO"

# The workflow decodes this back into a .p12, so upload the base64 of the
# exported certificate rather than the file itself.
if [ -n "${MACOS_CERT_P12:-}" ]; then
  printf '%s' "$MACOS_CERT_P12" | gh secret set MACOS_CERT_P12 --repo "$REPO"
else
  read -rp "Path to the Developer ID .p12: " cert < /dev/tty
  [ -f "$cert" ] || { echo "no such file: $cert"; exit 1; }
  base64 < "$cert" | gh secret set MACOS_CERT_P12 --repo "$REPO"
  echo "✓ MACOS_CERT_P12"
fi

ask MACOS_CERT_PASSWORD "Password for that .p12" hidden

if [ -z "${MACOS_SIGN_ID:-}" ]; then
  echo "Developer ID identities in your keychain:"
  security find-identity -v -p codesigning | grep "Developer ID Application" || true
fi
ask MACOS_SIGN_ID       "Signing identity, e.g. Developer ID Application: NAME (TEAMID)"
ask APPLE_ID            "Apple ID email"
ask APPLE_TEAM_ID       "Apple team id (10 characters)"
ask APPLE_APP_PASSWORD  "App-specific password for notarytool" hidden

echo
echo "Done. Current secrets:"
gh secret list --repo "$REPO"
