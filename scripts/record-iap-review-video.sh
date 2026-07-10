#!/usr/bin/env bash
# Record App Review screen video: Premium paywall → Terms of Use (EULA) in Safari.
# Uses -openTermsForReview (Debug) to open the terms URL after showing the paywall links.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
BUNDLE_ID="fi.veneappi.MarineWeather"
DERIVED="${DERIVED_DATA:-$ROOT/.derivedData}"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/MarineWeather.app"
OUT_DIR="$ROOT/docs/app-store/review"
OUT_VIDEO="$OUT_DIR/iap-eula-screen-recording.mov"

mkdir -p "$OUT_DIR"

echo "→ Building Debug ($SIM_NAME)…"
xcodebuild \
  -scheme MarineWeather \
  -configuration Debug \
  -destination "platform=iOS Simulator,name=${SIM_NAME}" \
  -derivedDataPath "$DERIVED" \
  build | tail -3

UDID="$(xcrun simctl list devices available -j \
  | python3 -c "
import json, sys
name = sys.argv[1]
for d in json.load(sys.stdin).get('devices', {}).values():
    for dev in d:
        if dev.get('name') == name and dev.get('isAvailable'):
            print(dev['udid']); raise SystemExit(0)
raise SystemExit(f'No simulator: {name!r}')
" "$SIM_NAME")"

echo "→ Booting $SIM_NAME ($UDID)…"
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$UDID" -b
xcrun simctl privacy "$UDID" grant location "$BUNDLE_ID"
xcrun simctl ui "$UDID" appearance light 2>/dev/null || true

echo "→ Installing & launching paywall…"
xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

rm -f "$OUT_VIDEO"

echo "→ Recording video to $OUT_VIDEO …"
xcrun simctl io "$UDID" recordVideo --force "$OUT_VIDEO" &
REC_PID=$!
sleep 1

xcrun simctl launch "$UDID" "$BUNDLE_ID" \
  -tab=route \
  -iapReviewScreenshot \
  -openTermsForReview

echo "→ Capturing paywall + Safari (≈12 s)…"
sleep 12

echo "→ Stopping recording…"
kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true

if [[ ! -f "$OUT_VIDEO" ]]; then
  echo "ERROR: Recording file was not created." >&2
  exit 1
fi

BYTES=$(stat -f%z "$OUT_VIDEO" 2>/dev/null || stat -c%s "$OUT_VIDEO")
if [[ "$BYTES" -lt 10000 ]]; then
  echo "ERROR: Recording looks too small ($BYTES bytes)." >&2
  exit 1
fi

# Verify Safari shows terms page
xcrun simctl io "$UDID" screenshot "$OUT_DIR/iap-eula-final-frame.png" 2>/dev/null || true

echo ""
echo "Done."
echo "Video:  $OUT_VIDEO"
echo "Frame:  $OUT_DIR/iap-eula-final-frame.png"
echo "Upload the .mov in App Store Connect → App Review Information."
