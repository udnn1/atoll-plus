#!/bin/zsh
set -euo pipefail

REPO="udnn1/atoll-plus"
IDENTITY="Atoll Local Signing"
KEYCHAIN="$HOME/Library/Keychains/atoll-signing.keychain-db"
PASS_FILE="$HOME/.config/atoll-signing/keychain-pass"
APP_DEST="/Applications/Atoll.app"

if [[ $# -ge 1 && "$1" == *.app ]]; then
  SOURCE_APP="$1"
else
  RUN_ID="${1:-$(gh run list -R "$REPO" -w build-app.yml -s success -L 1 --json databaseId --jq '.[0].databaseId')}"
  WORK="$(mktemp -d)"
  gh run download "$RUN_ID" -R "$REPO" -n Atoll-app -D "$WORK"
  ditto -x -k "$WORK/Atoll.zip" "$WORK/out"
  SOURCE_APP="$WORK/out/Atoll.app"
fi

security unlock-keychain -p "$(cat "$PASS_FILE")" "$KEYCHAIN"
codesign --force --deep --preserve-metadata=identifier,entitlements,flags --keychain "$KEYCHAIN" -s "$IDENTITY" "$SOURCE_APP"
codesign --verify --deep "$SOURCE_APP"

osascript -e 'quit app "Atoll"' 2>/dev/null || true
sleep 2
rm -rf "$APP_DEST"
ditto "$SOURCE_APP" "$APP_DEST"
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true
FRONT_APP="$(lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null | grep -o 'bundleID="[^"]*"' | cut -d'"' -f2 || true)"
open -g "$APP_DEST"
if [[ -n "$FRONT_APP" && "$FRONT_APP" != "com.Ebullioscopic.Atoll" ]]; then
  sleep 2
  NOW_APP="$(lsappinfo info -only bundleid "$(lsappinfo front)" 2>/dev/null | grep -o 'bundleID="[^"]*"' | cut -d'"' -f2 || true)"
  if [[ "$NOW_APP" != "$FRONT_APP" ]]; then
    open -b "$FRONT_APP" 2>/dev/null || true
  fi
fi
echo "Zainstalowano: $(codesign -dv "$APP_DEST" 2>&1 | grep Authority || echo podpisane)"
