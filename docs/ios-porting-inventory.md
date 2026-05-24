# Android → iOS porting inventory

**Source of truth (read-only):** `/Users/Safelight/Veneappi`  
**Target:** this repo (`marine-weather-ios`)

Last aligned with Android `versionName` **0.2.2** (`versionCode` 4).

## App identity

| | Android | iOS (planned) |
|---|---------|----------------|
| Package / bundle | `fi.veneappi.app` | `fi.veneappi.MarineWeather` (confirm in Xcode) |
| Display name | Marine Weather | Marine Weather |
| User-Agent | `MarineWeather/0.1.0 (fi.veneappi.app; planning app)` | Bump version in `AppConfig` |
| Privacy | [privacy.html](https://joniwinsten-lab.github.io/marine-weather/privacy.html) | Same URL |
| Support | support@safelight.fi | Same |

## Premium boundaries (must match Android)

| Feature | Free | Premium |
|---------|------|---------|
| Map + multi-source weather compare | ✓ | |
| Storm radar & lightning | ✓ | |
| Marine text forecasts | ✓ | |
| Route planning | | ✓ |
| 12-day wind outlook | | ✓ |

**Billing product IDs (Play / App Store):** `route-premium-lifetime`, `route-premium-monthly`

## Map & basemap

| Android | URL / constant |
|---------|----------------|
| `MapConfig.STYLE_URL` | `https://tiles.openfreemap.org/styles/liberty` |
| Vector tiles | `https://tiles.openfreemap.org/planet/{z}/{x}/{y}.pbf` |
| NE2 raster | `https://tiles.openfreemap.org/natural_earth/ne2sr/{z}/{x}/{y}.png` |
| Default zoom | 12.5 (Helsinki area) |

**iOS:** MapLibre Native + same style URL.

## Weather & marine APIs (representative)

| Area | Android file(s) | Endpoint / notes |
|------|-----------------|------------------|
| MET location forecast | `MetNowcastRadarRepository` | `https://api.met.no/weatherapi/locationforecast/2.0/compact` |
| MET nowcast | same | `https://api.met.no/weatherapi/nowcast/2.0/complete` |
| MET radar | `MetNorwayRadarRepository` | `https://api.met.no/weatherapi/radar/2.0/` |
| MET marine text | `MarineTextRepository` | `https://api.met.no/weatherapi/textforecast/3.0/sea_en.json` |
| FMI WFS (multipoint, lightning) | `FmiForecastRadarRepository`, `FmiLightningRepository` | `https://opendata.fmi.fi/wfs` |
| FMI HARMONIE GRIB | `FmiHarmonieGribParser` | `https://opendata.fmi.fi/download?producer=harmonie_scandinavia_surface` |
| FMI radar WMS | `FmiRadarConfig` | `https://openwms.fmi.fi/geoserver/wms` |
| SMHI radar files | `SmhiRadarRepository` | `https://data-download.smhi.se/data/meteorology/radar` |
| SMHI marine text | `MarineTextRepository` | `https://data-download.smhi.se/data/meteorology/texts/sea_report_sweden_sv.json` |
| SMHI lightning | `SmhiLightningRepository` | `https://opendata-download-lightning.smhi.se/api/version/latest/` |
| EE marine XML | `MarineTextRepository` | `https://ilmateenistus.ee/ilma_andmed/xml/forecast.php?lang=eng` |

**Requirement:** send `User-Agent` (and respect MET [terms](https://api.met.no/doc/TermsOfService)) on every HTTP client.

## UI modules to port (by phase)

| Android module | iOS target | Notes |
|----------------|------------|--------|
| `VeneappiRoot` / tabs | `MainTabView` (TBD) | Do not change Android stable views from iOS repo |
| Map compare | Phase 2 | `ComparePane`, `WeatherPane` |
| Route | Phase 5 | `RoutePane`, OSRM if enabled |
| Storm map | Phase 4 | `StormMapViewModel`, radar repos |
| Marine drawer | Phase 3 | `MarineTextRepository` |
| Billing | Phase 5 | Play Billing → StoreKit 2 |

## Android-only (no iOS port)

- Gradle, `keystore.properties`, Play `friends` flavor
- `requiresSmallestWidthDp=600` manifest filter → use Xcode **iPad only** + landscape
- R8 / native debug metadata Play warnings

## Reference docs in Android repo

- `docs/privacy.html`, `docs/data-safety-play-console.md`, `docs/store-listing-en.md`
- Use for App Store copy and privacy questionnaire; edit only in Android repo if Play-specific.
