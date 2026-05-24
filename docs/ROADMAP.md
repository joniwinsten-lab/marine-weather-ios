# iOS roadmap

Phases keep parity with Android **without** sharing one Gradle/Xcode monorepo.

## Phase 0 — Workspace (done)

- [x] Separate git repo `marine-weather-ios`
- [x] Cursor rule: do not edit Android `Veneappi`
- [x] Porting inventory doc
- [x] SwiftUI shell sources + `project.yml` for XcodeGen

## Phase 1 — MVP shell (done)

- [x] Xcode project on Mac (iPad, landscape)
- [x] MapLibre map + OpenFreeMap style
- [x] Three-source weather fetch (MET, SMHI, FMI) in Compare pane
- [x] User-Agent header on all API calls
- [x] Main navigation shell (5 tabs, icon rail)
- [x] Location permission + recenter
- [x] App icon (Android `ic_launcher` layers)
- [x] Attribution dialog (MET, SMHI, FMI, Traficom)

## Phase 2 — Map & weather compare (done)

- [x] Three-source compare UI + forecast strip
- [x] Two-pane layout 65/35 (`UiBreakpoints`)
- [x] Traficom nautical WMTS overlay
- [x] Forecast location pin on map
- [x] SwiftData offline forecast cache
- [x] English localization (`Localizable.strings`)
- [ ] Scale bar on map
- [ ] Map tile warmup on splash

## Phase 3 — Marine text (done)

- [x] `MarineTextRepository` (MET sea, SMHI/FMI fallbacks, EE XML)
- [x] `MarineTextOverviewPane` 2×2 country grid
- [x] Summarizer + alert classifier
- [x] `MarineServiceUrls` — open full forecast in browser
- [x] Manual refresh + map-centre coordinate hint

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

## Later

- [ ] Localization FI / SV / NB
- [ ] Harbors (Overpass) if added to product nav
