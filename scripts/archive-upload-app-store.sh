#!/usr/bin/env bash
# Archive Marine Weather (Release) and upload to App Store Connect.
# Prerequisite: Xcode → MarineWeather target → Signing & Capabilities → Team selected.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARCHIVE_PATH="$ROOT/build/MarineWeather.xcarchive"
EXPORT_PLIST="$ROOT/scripts/AppStoreExportOptions.plist"
DERIVED="$ROOT/.derivedDataArchive"

team="$(xcodebuild -showBuildSettings -scheme MarineWeather -configuration Release -destination 'generic/platform=iOS' 2>/dev/null \
  | awk -F' = ' '/^    DEVELOPMENT_TEAM =/{print $2; exit}')"

if [[ -z "$team" ]]; then
  echo "ERROR: DEVELOPMENT_TEAM is not set."
  echo "Open MarineWeather.xcodeproj in Xcode → target MarineWeather → Signing & Capabilities → choose your Team, then run this script again."
  exit 1
fi

echo "→ Team: $team"
echo "→ Archiving Release build…"
xcodebuild archive \
  -scheme MarineWeather \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$team"

echo "→ Uploading to App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$ROOT/build/app-store-export" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$team"

echo ""
echo "Done. Check App Store Connect → TestFlight / Activity for the build (may take 5–30 min)."
