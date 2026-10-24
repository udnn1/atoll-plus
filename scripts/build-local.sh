#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="${ATOLL_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData/Atoll-local}"
LOG="$DERIVED.log"

cd "$ROOT"
START=$(date +%s)
caffeinate -i xcodebuild build \
  -project DynamicIsland.xcodeproj \
  -scheme DynamicIsland \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED" \
  SWIFT_COMPILATION_MODE=singlefile \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=YES > "$LOG" 2>&1 || {
    grep -E 'error:' "$LOG" | sort -u | head -20
    echo "Build nieudany, log: $LOG"
    exit 1
  }
echo "Build OK w $(( $(date +%s) - START ))s"

if [[ "${1:-}" != "--no-install" ]]; then
  "$ROOT/scripts/install-local.sh" "$DERIVED/Build/Products/Release/Atoll.app"
fi
