# AIS data (iOS)

## Source

**Fintraffic Digitraffic Marine AIS** — open API for Finnish and Baltic vessel positions.

| | |
|---|---|
| REST locations | `GET https://meri.digitraffic.fi/api/ais/v1/locations` (GeoJSON FeatureCollection) |
| REST metadata | `GET https://meri.digitraffic.fi/api/ais/v1/vessels` (JSON array, names by MMSI) |
| Required header | `Digitraffic-User: MarineWeather/0.3.0 (fi.veneappi.MarineWeather)` |
| Compression | `Accept-Encoding: gzip` |

Docs: [meri.digitraffic.fi](https://meri.digitraffic.fi/)

MQTT live stream (`wss://meri.digitraffic.fi:443/mqtt`) is **deferred** — v0.3.x uses REST only.

## Product boundary

| Tier | AIS on map |
|------|------------|
| Free (Compare, storm, marine text) | Chip visible, locked — same premium as route |
| Premium | Toggle on Compare + Route maps |

MarineTraffic and similar commercial APIs are **not** used (paid / different licensing).

## iOS implementation (v0.3.0)

- `DigitrafficAisRepository` — REST locations + vessel metadata
- `AisMapViewModel` — ~60 s poll while AIS on; debounced REST reload on viewport pan/zoom
- `MapAisOverlay` — MapLibre circles + **COG/SOG course vectors** (2 min, computed client-side; API has no track geometry)
- Tap vessel → detail sheet (name, MMSI/IMO, speed, course, heading, type, status, destination, draught, ETA)
- Attribution in `AttributionDialogView`

## Android follow-up

Port the same REST + premium gate after iOS validation on device/simulator.
