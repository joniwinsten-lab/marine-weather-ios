# Marine Weather (iOS)

Native **iPad / landscape** marine planning app for App Store. Android lives in a separate repo — do not mix release pipelines.

| Repo | Platform | Store |
|------|----------|--------|
| [marine-weather](https://github.com/joniwinsten-lab/marine-weather) | Android | Google Play (`fi.veneappi.app`) |
| **marine-weather-ios** (this) | iOS | App Store (`fi.veneappi.MarineWeather`) |

## Start here

1. [docs/SETUP.md](docs/SETUP.md) — install Xcode, Apple Developer, generate project
2. [docs/ROADMAP.md](docs/ROADMAP.md) — phased delivery checklist
3. [docs/ios-porting-inventory.md](docs/ios-porting-inventory.md) — Android → iOS feature & API map

## Open in Cursor

Open **this folder only** as the workspace root (not the Android `Veneappi` folder):

```text
/Users/Safelight/marine-weather-ios
```

Or open `marine-weather-ios.code-workspace`.

## Status (v0.3.0)

| Area | Status |
|------|--------|
| Compare tab | Map + 3-source wind (MET/SMHI/FMI), Traficom overlay, forecast pin |
| Marine text tab | 4-country summaries (NO/SE/FI/EE) at map centre |
| Storm radar tab | FMI WMS radar timeline ±3 h, lightning (FMI + SMHI), play/pause |
| Attribution | Footer + licenses dialog |
| Offline cache | SwiftData forecast cache per source & location |
| Localization | English (`en.lproj/Localizable.strings`) |
| Route / 12-day wind | Premium placeholders (Phase 5) |

**Build:** `./scripts/setup-macos.sh` then open `MarineWeather.xcodeproj` in Xcode (iPad simulator, landscape).

See [docs/SETUP.md](docs/SETUP.md) — **Docker is not used** for iOS builds.
