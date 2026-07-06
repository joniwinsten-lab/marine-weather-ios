#!/usr/bin/env bash
# Build, install, and launch Marine Weather on the iPad simulator with Helsinki GPS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIM_NAME="${SIM_NAME:-iPad Pro 13-inch (M5)}"
BUNDLE_ID="fi.veneappi.MarineWeather"
HELSINKI_LAT="60.1453"
HELSINKI_LON="24.9884"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.derivedData}"
APP="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/MarineWeather.app"

echo "→ Building for iOS Simulator ($SIM_NAME)…"
xcodebuild \
  -scheme MarineWeather \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=${SIM_NAME}" \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  | tail -3

UDID="$(xcrun simctl list devices available -j \
  | python3 -c "
import json, sys
name = sys.argv[1]
for d in json.load(sys.stdin).get('devices', {}).values():
    for dev in d:
        if dev.get('name') == name and dev.get('isAvailable'):
            print(dev['udid'])
            raise SystemExit(0)
raise SystemExit(f'No available simulator named {name!r}')
" "$SIM_NAME")"

echo "→ Booting simulator $SIM_NAME ($UDID)…"
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

echo "→ Helsinki location + location permission…"
xcrun simctl privacy "$UDID" grant location "$BUNDLE_ID"
xcrun simctl location "$UDID" set "${HELSINKI_LAT},${HELSINKI_LON}"

echo "→ Installing app…"
xcrun simctl install "$UDID" "$APP"

echo "→ Launching ${BUNDLE_ID}..."
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID"

echo ""
echo "Done. Simulator is at Suomenlinna ($HELSINKI_LAT, $HELSINKI_LON)."
echo "Tip: Run from Xcode (Cmd+R) for StoreKit testing via Products.storekit."
