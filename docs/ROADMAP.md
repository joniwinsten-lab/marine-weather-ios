# iOS roadmap

Phases keep parity with Android **without** sharing one Gradle/Xcode monorepo.

**Live parity tracker:** `/Users/Safelight/Veneappi/docs/feature-parity.md` — update on every user-facing change.

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
- [x] Scale bar on map
- [x] Map tile warmup on launch

## Phase 3 — Marine text (done)

- [x] `MarineTextRepository` (MET sea, SMHI/FMI fallbacks, EE XML)
- [x] `MarineTextOverviewPane` 2×2 country grid
- [x] Summarizer + alert classifier
- [x] `MarineServiceUrls` — open full forecast in browser
- [x] Manual refresh + map-centre coordinate hint

## Phase 4 — Storm radar & lightning (MVP done)

- [x] FMI WMS radar overlay + ±3 h / 30 min timeline
- [x] Radar animation play/pause/step + time slider
- [x] Lightning layers (FMI WFS + SMHI CSV), filtered by frame time
- [x] Storm tab UI (`StormRadarPane`, `StormMapViewModel`)
- [x] MET/SMHI geo radar fallback per region (latest overlay)
- [ ] FMI HARMONIE GRIB forecast frames on timeline

## Phase 5 — Route + premium

- [x] Route UI + Väylä routing + weather along route
- [x] Extended 12-day wind outlook
- [x] StoreKit 2: lifetime + subscription (`StoreKitRoutePremiumService`)
- [x] Local 3-day trial + paywall UI
- [x] Navigointidisclaimer (Route-välilehti, info-nappi)
- [ ] App Store Connect products live + sandbox / TestFlight verification
- [x] AIS overlay (Digitraffic REST, premium chip on Compare + Route)
- [x] AIS REST poll (~60 s) + viewport reload (MQTT deferred)
- [x] Offline / stale weather banner (all tabs)
- [x] Offline route pack download (Route tab, premium)
- [x] Route overlay on Compare map (premium)
- [x] Paywall billing diagnostics

## Phase 6 — App Store (blocked: developer account)

- [ ] App Store Connect products live + sandbox / TestFlight verification
- [ ] TestFlight internal → external
- [ ] Screenshots (iPad 12.9" landscape)
- [ ] Privacy nutrition labels (mirror Play data safety)
- [ ] Review notes (weather data sources, no account required for free tier)

## Later (done except harbors)

- [x] Localization FI / SV / NB
- [x] Branded splash + map tile warmup during splash
- [ ] Harbors (Overpass) if added to product nav
