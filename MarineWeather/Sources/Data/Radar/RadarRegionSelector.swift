import Foundation

/// Picks primary radar source from map centre (Android `RadarRegionSelector.kt`).
enum RadarRegionSelector {
    static func preferredSource(lat: Double, lon: Double) -> RadarSourceId {
        if lon >= 20.0, lat >= 54.5, lat <= 72.5 { return .fmi }
        if lon < 19.5, lat >= 54.5, lat <= 69.5 { return .metNordic }
        return .fmi
    }
}
