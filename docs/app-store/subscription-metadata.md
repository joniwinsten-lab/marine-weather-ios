# App Store subscription metadata (Guideline 3.1.2)

Apple rejected submissions when **App Store Connect metadata** is missing a **functional Terms of Use (EULA)** link for auto-renewable subscriptions — even if the in-app paywall already links to terms.

The app paywall links to:

- **Terms of Use:** https://safelight.fi/marine-weather/terms.html
- **Privacy Policy:** https://safelight.fi/marine-weather/privacy.html

Both pages are live and include iOS subscription terms (monthly auto-renew, cancellation, restore).

## Fix in App Store Connect (required)

### 1. Privacy Policy URL

**App Store Connect → Your app → App Information → General Information**

Set **Privacy Policy URL** to:

```
https://safelight.fi/marine-weather/privacy.html
```

### 2. Terms of Use (EULA) — pick one method

**Option A — Recommended: append to App Description (all locales you use)**

Add these lines at the **end** of the description (English example):

```
Terms of Use (EULA): https://safelight.fi/marine-weather/terms.html
Privacy Policy: https://safelight.fi/marine-weather/privacy.html

Marine Weather Premium (monthly) is an auto-renewable subscription. Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings → Apple ID → Subscriptions.
```

Finnish example:

```
Käyttöehdot (EULA): https://safelight.fi/marine-weather/terms.html
Tietosuojakäytäntö: https://safelight.fi/marine-weather/privacy.html

Marine Weather Premium (kuukausitilaus) uusiutuu automaattisesti, ellei sitä peruuteta vähintään 24 h ennen jakson päättymistä. Hallitse tilauksia: Asetukset → Apple ID → Tilaukset.
```

**Option B — Custom EULA field**

**App Store Connect → Your app → App Information → License Agreement → Custom App License Agreement**

Paste the contents of https://safelight.fi/marine-weather/terms.html (or a short EULA that references Apple’s standard EULA and your subscription rules).

If you use **Option B**, you may still add the URLs in the description for clarity.

### 3. Subscription product metadata

**App Store Connect → Subscriptions → `route_premium_monthly`**

Confirm **Subscription Display Name** and **Description** mention:

- Auto-renewable monthly subscription
- Features unlocked (route, 12-day wind, AIS, offline pack)
- Link or reference to terms (some teams paste the terms URL in the subscription description)

### 4. App Review Information (resubmission)

**App Store Connect → App Review Information → Notes**

Paste:

```
Subscription compliance (3.1.2):

- Privacy Policy: https://safelight.fi/marine-weather/privacy.html
- Terms of Use (EULA): https://safelight.fi/marine-weather/terms.html

In-app: open Route or Track tab → Premium paywall → “Privacy Policy” and “Terms of Use (EULA)” at the bottom (functional Safari links).

Products: route_premium_lifetime (non-consumable), route_premium_monthly (auto-renewable monthly).

Attached screen recording shows paywall legal links opening in Safari.
```

Upload a **short screen recording** (Route tab → Premium → tap Terms of Use → page loads).

## In-app (already implemented)

- Paywall shows subscription price from StoreKit before purchase
- Auto-renew hint and restore purchases
- Functional Privacy Policy and Terms of Use links (`RoutePremiumPaywall.swift`)

## Resubmit

1. Save metadata changes in App Store Connect (no new binary required if only metadata was missing).
2. Reply in Resolution Center with the note above + screen recording, **or** submit a new build if you also changed the app.
3. If you ship a new build, bump version and run `./scripts/archive-upload-app-store.sh`, then commit and push.

## References

- [Apple Guideline 3.1.2 — Subscriptions](https://developer.apple.com/app-store/review/guidelines/#subscriptions)
- [Standard Apple EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) (also referenced on our terms page)
