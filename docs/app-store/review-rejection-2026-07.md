# App Review rejection fixes (July 2026)

## 5.1.1(ii) — Location purpose string

**Fixed in app build:** `NSLocationWhenInUseUsageDescription` in `project.yml` + localized `InfoPlist.strings` (en/fi/sv/nb).

Example (English): explains map centre, forecasts, and recenter while sailing.

## 2.3.2 — Duplicate IAP promotional images

**Fix in App Store Connect** (not only in binary):

1. Open **Subscriptions / In-App Purchases** in App Store Connect.
2. **`route_premium_lifetime`** → Promotional Image → upload `docs/app-store/iap/route_premium_lifetime-1024.png`
3. **`route_premium_monthly`** → Promotional Image → upload `docs/app-store/iap/route_premium_monthly-1024.png` (different image)
4. Or delete promotional images if you are not promoting IAPs on the store.

Regenerate images: `python3 scripts/generate-iap-promo-images.py`

## 3.1.2(c) — Subscription pricing prominence

**Fixed in app build:** Paywall shows **monthly billed amount** large and primary; local 3-day trial is optional small text below purchases.

## Resubmission checklist

- [ ] Upload new build (location string + paywall)
- [ ] Upload **unique** IAP promotional images (or remove them)
- [ ] App Description still includes Terms + Privacy URLs (see `subscription-metadata.md`)
- [ ] App Review Notes: mention paywall shows monthly price prominently; attach EULA screen recording if needed
