import Foundation

/// Shared constants ported from Android `MapConfig` and `BuildConfig`.
enum AppConfig {
    static let appDisplayName = "Marine Weather"

    /// Match Android `WEATHER_USER_AGENT`; bump version when shipping.
    static let weatherUserAgent = "MarineWeather/0.2.0 (fi.veneappi.MarineWeather; planning app)"

    // Map — OpenFreeMap (see Android `MapConfig.kt`)
    static let mapStyleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    static let defaultCompareZoom: Double = 12.5
    static let vectorTilesTemplate = "https://tiles.openfreemap.org/planet/{z}/{x}/{y}.pbf"
    static let ne2RasterTemplate = "https://tiles.openfreemap.org/natural_earth/ne2sr/{z}/{x}/{y}.png"

    // Default map center — Suomenlinna, Helsinki (Android MainViewModel default)
    static let defaultLatitude = 60.1453
    static let defaultLongitude = 24.9884

    // StoreKit product IDs (create in App Store Connect; mirror Play hyphen IDs)
    static let billingRoutePremiumLifetime = "route-premium-lifetime"
    static let billingRoutePremiumMonthly = "route-premium-monthly"

    static let privacyPolicyURL = URL(string: "https://joniwinsten-lab.github.io/marine-weather/privacy.html")!
    static let supportEmail = "support@safelight.fi"
}
