# App Store screenshots (simulator)

## iPhone — App Store Connect sizes

Drag screenshots from **one** portrait folder **or** one landscape folder (6.5" or 6.7") into App Store Connect.

| Folder | Size (W × H) | Display |
|--------|----------------|---------|
| `iphone/1284x2778/` | 1284 × 2778 | 6.7" portrait |
| `iphone/2778x1284/` | 2778 × 1284 | 6.7" landscape |
| `iphone/1242x2688/` | 1242 × 2688 | 6.5" portrait |
| `iphone/2688x1242/` | 2688 × 1242 | 6.5" landscape |

Six screens per folder:

1. `01-compare-map-weather.png` — Map & weather
2. `02-storm-radar.png` — Radar & lightning
3. `03-marine-text.png` — Marine text
4. `04-route-planning.png` — Route (premium)
5. `05-extended-wind.png` — 12-day wind (premium)
6. `06-ais-track.png` — AIS track (premium)

Raw simulator capture: `iphone/_raw/` (resized to the four sizes above).

## iPad (`ipad/`)

13-inch iPad Pro (M5): 2064 × 2752 px. Use for **iPad-only** listing if required separately from iPhone.

## Re-capture

```bash
./scripts/capture-app-store-screenshots.sh
```

iPhone only (faster):

```bash
CAPTURE_IPAD=0 ./scripts/capture-app-store-screenshots.sh
```

Longer load wait: `SCREENSHOT_WAIT_SECONDS=15 ./scripts/capture-app-store-screenshots.sh`
