#!/usr/bin/env bash
# Capture App Store screenshots from iOS Simulator (Debug build with -tab= launch args).
# iPhone exports: 1242×2688, 2688×1242, 1284×2778, 2778×1284 (resize from nearest simulator).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT_BASE="$ROOT/docs/app-store-screenshots"
OUT_IPAD="$OUT_BASE/ipad"
OUT_RAW="$OUT_BASE/iphone/_raw"
OUT_65P="$OUT_BASE/iphone/1242x2688"
OUT_65L="$OUT_BASE/iphone/2688x1242"
OUT_67P="$OUT_BASE/iphone/1284x2778"
OUT_67L="$OUT_BASE/iphone/2778x1284"
APP="$ROOT/.derivedData/Build/Products/Debug-iphonesimulator/MarineWeather.app"
BUNDLE_ID="fi.veneappi.MarineWeather"
IPHONE_SIM="${IPHONE_SIM:-iPhone 17 Pro Max}"
WAIT="${SCREENSHOT_WAIT_SECONDS:-10}"
CAPTURE_IPAD="${CAPTURE_IPAD:-1}"

mkdir -p "$OUT_IPAD" "$OUT_RAW" "$OUT_65P" "$OUT_65L" "$OUT_67P" "$OUT_67L"

echo "→ Building Debug for simulator…"
xcodebuild \
  -scheme MarineWeather \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/.derivedData" \
  build | tail -3

export_iphone_sizes() {
  local src="$1"
  local name="$2"
  local tmp
  tmp="$(mktemp /tmp/mw-shot.XXXXXX.png)"

  # 6.7" portrait — 1284 × 2778
  sips -z 2778 1284 "$src" --out "$OUT_67P/$name" >/dev/null

  # 6.7" landscape — 2778 × 1284
  sips -z 2778 1284 "$src" --out "$tmp" >/dev/null
  sips -r 90 "$tmp" --out "$OUT_67L/$name" >/dev/null

  # 6.5" portrait — 1242 × 2688
  sips -z 2688 1242 "$src" --out "$OUT_65P/$name" >/dev/null

  # 6.5" landscape — 2688 × 1242
  sips -z 2688 1242 "$src" --out "$tmp" >/dev/null
  sips -r 90 "$tmp" --out "$OUT_65L/$name" >/dev/null

  rm -f "$tmp"
}

capture_device() {
  local device_name="$1"
  local out_dir="$2"
  local udid
  udid="$(xcrun simctl list devices available -j \
    | python3 -c "
import json, sys
name = sys.argv[1]
for d in json.load(sys.stdin).get('devices', {}).values():
    for dev in d:
        if dev.get('name') == name and dev.get('isAvailable'):
            print(dev['udid']); raise SystemExit(0)
raise SystemExit(f'No simulator: {name!r}')
" "$device_name")"

  echo ""
  echo "=== $device_name ($udid) ==="
  xcrun simctl boot "$udid" 2>/dev/null || true
  open -a Simulator
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl privacy "$udid" grant location "$BUNDLE_ID"
  xcrun simctl location "$udid" set 60.1453,24.9884
  xcrun simctl ui "$udid" appearance light 2>/dev/null || true
  xcrun simctl status_bar "$udid" override \
    --time 10:00 \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularBars 4 2>/dev/null || true

  xcrun simctl install "$udid" "$APP"

  shot() {
    local file="$1"
    local tab="${2:-}"
    local premium="${3:-}"
    local args=()
    [[ -n "$tab" ]] && args+=("-tab=$tab")
    [[ "$premium" == "1" ]] && args+=("-screenshotPremium")

    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    if ((${#args[@]})); then
      xcrun simctl launch "$udid" "$BUNDLE_ID" "${args[@]}" >/dev/null
    else
      xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
    fi
    sleep "$WAIT"
    xcrun simctl io "$udid" screenshot "$out_dir/$file"
    echo "  captured $out_dir/$file"
  }

  shot "01-compare-map-weather.png"
  shot "02-storm-radar.png" "stormRadar"
  shot "03-marine-text.png" "marineText"
  shot "04-route-planning.png" "route" 1
  shot "05-extended-wind.png" "extendedWind" 1
  shot "06-ais-track.png" "track" 1
}

if [[ "$CAPTURE_IPAD" == "1" ]]; then
  capture_device "iPad Pro 13-inch (M5)" "$OUT_IPAD"
fi

capture_device "$IPHONE_SIM" "$OUT_RAW"

echo ""
echo "→ Exporting iPhone App Store sizes…"
for f in "$OUT_RAW"/*.png; do
  name="$(basename "$f")"
  export_iphone_sizes "$f" "$name"
  w67=$(sips -g pixelWidth "$OUT_67P/$name" | awk '/pixelWidth/{print $2}')
  h67=$(sips -g pixelHeight "$OUT_67P/$name" | awk '/pixelHeight/{print $2}')
  wl67=$(sips -g pixelWidth "$OUT_67L/$name" | awk '/pixelWidth/{print $2}')
  hl67=$(sips -g pixelHeight "$OUT_67L/$name" | awk '/pixelHeight/{print $2}')
  echo "  $name → ${w67}x${h67}, landscape ${wl67}x${hl67}"
done

echo ""
echo "Done."
echo "iPhone 6.7 portrait:  $OUT_67P"
echo "iPhone 6.7 landscape: $OUT_67L"
echo "iPhone 6.5 portrait:  $OUT_65P"
echo "iPhone 6.5 landscape: $OUT_65L"
[[ "$CAPTURE_IPAD" == "1" ]] && echo "iPad: $OUT_IPAD"
