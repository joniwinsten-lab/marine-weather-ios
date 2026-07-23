import Foundation

/// Shared constants ported from Android `MapConfig` and `BuildConfig`.
enum AppConfig {
    static let appDisplayName = "Marine Weather"
    static let marketingVersion = "0.3.10"

    /// Match Android `WEATHER_USER_AGENT`; bump version when shipping.
    static let weatherUserAgent = "MarineWeather/0.3.10 (fi.veneappi.MarineWeather; planning app)"

    // Map — OpenFreeMap (see Android `MapConfig.kt`)
    static let mapStyleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    static let defaultCompareZoom: Double = 12.5
    static let vectorTilesTemplate = "https://tiles.openfreemap.org/planet/{z}/{x}/{y}.pbf"
    static let ne2RasterTemplate = "https://tiles.openfreemap.org/natural_earth/ne2sr/{z}/{x}/{y}.png"

    // Default map center — Suomenlinna, Helsinki (Android MainViewModel default)
    static let defaultLatitude = 60.1453
    static let defaultLongitude = 24.9884

    // StoreKit product IDs (App Store Connect: alphanumerics, periods, underscores only)
    static let billingRoutePremiumLifetime = "route_premium_lifetime"
    static let billingRoutePremiumMonthly = "route_premium_monthly"

    /// Finland gross price (VAT 25.5% included) — fallback label if StoreKit fails to load.
    static let premiumLifetimeReferenceDisplay = "59,99 €"
    static let premiumMonthlyReferenceDisplay = "2,99 €"

    static let privacyPolicyURL = URL(string: "https://safelight.fi/marine-weather/privacy.html")!
    static let termsOfUseURL = URL(string: "https://safelight.fi/marine-weather/terms.html")!
    static let supportEmail = "support@safelight.fi"

    // Fintraffic Digitraffic AIS (Baltic / Finland) — https://meri.digitraffic.fi
    static let digitrafficBaseURL = URL(string: "https://meri.digitraffic.fi/api/ais/v1")!
    static let digitrafficUser = "MarineWeather/0.3.10 (fi.veneappi.MarineWeather)"
    /// REST poll interval while AIS overlay is on (no MQTT).
    static let aisRestPollIntervalSeconds: TimeInterval = 60
    /// Metadata-only REST heartbeat while MQTT live (positions come from MQTT).
    static let aisRestMetadataPollIntervalSecondsWhenMqttLive: TimeInterval = 600
    /// Re-download vessel names/metadata every N position polls (not every 60 s).
    static let aisMetadataRefreshEveryNPolls = 10
    static let aisMaxVesselsOnMap = 600
    /// Live MQTT topic subscriptions (nearest vessels in viewport).
    static let aisMaxMqttSubscriptions = 80
    /// iPhone uses REST viewport polling only until CocoaMQTT WebSocket is stable on device.
    static let aisMqttLiveOnPhone = false
    /// Debounce REST reload when the map viewport changes (pan/zoom).
    static let aisViewportRefreshDebounceSeconds: TimeInterval = 0.45
    /// Course vector length from SOG × COG (API has no pre-drawn track).
    static let aisCourseVectorMinutes: Double = 2
    static let aisMinSogForVectorKn: Double = 0.4
}
