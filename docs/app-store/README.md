# App Store assets

## Routing App Coverage File

**File:** `RoutingAppCoverage.geojson`

Upload in **App Store Connect → App → App Information → Routing App Coverage File**.

### What it is

Apple asks for this when an app is registered as a **routing app** (integrates with Apple Maps via `MKDirectionsRequest` and `MKDirectionsApplicationSupportedModes` in Info.plist).

Marine Weather is a **marine planning app** with its own route tool (Väylä fairways, weather along track). It is **not** a turn-by-turn Apple Maps routing provider. If you never enabled the Maps “Routing” capability in Xcode, this upload may be **optional** — App Store Connect sometimes still shows the field for navigation/weather apps.

If Review or Connect requires the file, use the one in this folder.

### Coverage area

The polygon covers the **Baltic Sea and adjacent coasts** (roughly 9.5°E–31°E, 53.5°N–66.5°N), matching where the app’s forecasts, radar, AIS, and planning features are intended to be used. Fairway routing is strongest in **Finnish waters**; open-sea passage planning outside fairways is not guaranteed.

### Format (Apple rules)

- Extension: `.geojson`
- Root type: `MultiPolygon` only
- Coordinates: `[longitude, latitude]` (WGS 84)
- Each ring closed (first point = last point)
- No holes; under 20 MB

### If you want to avoid this requirement entirely

In Xcode, check **Signing & Capabilities** → do **not** enable Maps routing modes unless you implement `MKDirectionsRequest` handling. Without `MKDirectionsApplicationSupportedModes` in Info.plist, Apple should not treat the app as a Maps routing alternative.
