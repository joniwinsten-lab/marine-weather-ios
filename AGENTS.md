# Agent instructions (Marine Weather iOS)

- Work **only** in this repository unless the user explicitly asks about Android.
- Never edit `/Users/Safelight/Veneappi` **except** `docs/feature-parity.md` (parity tracker).
- Read **`/Users/Safelight/Veneappi/docs/feature-parity.md`** before and after user-facing changes; update matrix + changelog.
- Read `docs/ios-porting-inventory.md` before porting features from Android (API URLs, file paths).
- Local pointer: `docs/feature-parity.md`.

## Feature parity (required)

On any user-facing change: update the canonical parity doc (see `.cursor/rules/feature-parity.mdc`).

Premium: route + 12-day wind + AIS + route-on-compare + offline pack = paid; map, radar, marine text = free.

## Stack

- Swift 5.9+, SwiftUI, MapLibre Native iOS (SPM)
- **Devices:** iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`); UI is iPad-first, iPhone polish later
- Match API URLs and User-Agent in `AppConfig.swift`
