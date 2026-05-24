# iOS roadmap

Phases keep parity with Android **without** sharing one Gradle/Xcode monorepo.

## Phase 0 — Workspace (done in repo)

- [x] Separate git repo `marine-weather-ios`
- [x] Cursor rule: do not edit Android `Veneappi`
- [x] Porting inventory doc
- [x] SwiftUI shell sources + optional `project.yml` for XcodeGen

## Phase 1 — MVP shell

- [ ] Xcode project on Mac (iPad, landscape)
- [ ] MapLibre map + OpenFreeMap style (see `AppConfig`)
- [ ] Single weather source tile overlay or side panel (pick FMI or MET first)
- [ ] User-Agent header on all API calls (`AppConfig.weatherUserAgent`)

## Phase 2 — Map & weather compare

- [ ] Three-source compare UI (port logic from Android `ComparePane` / `WeatherPane` — **do not edit Android**; read as reference)
- [ ] Point forecast strip, time slider
- [ ] Localization: EN first, then FI/SV/NB

## Phase 3 — Marine text

- [ ] MET / SMHI / FMI / EE marine text repositories (see inventory URLs)
- [ ] Region picker, external links (`MarineServiceUrls` parity)

## Phase 4 — Storm radar & lightning

- [ ] FMI WMS, MET/SMHI radar, GRIB path (hardest; port last)
- [ ] Lightning layers (FMI WFS, SMHI)

## Phase 5 — Route + premium

- [ ] Route UI (port from `RoutePane` when ready)
- [ ] StoreKit 2: lifetime + subscription
- [ ] **Premium gate:** route + 12-day wind only; radar free (match Android policy)

## Phase 6 — App Store

- [ ] TestFlight internal → external
- [ ] Screenshots (iPad 12.9" landscape)
- [ ] Privacy nutrition labels (mirror Play data safety)
- [ ] Review notes (weather data sources, no account required for free tier)
