import Foundation

/// Main navigation destinations (Android `MainDest`).
enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case compare
    case weather
    case route
    case track
    case extendedWind
    case marineText
    case stormRadar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compare: String(localized: "tab_compare")
        case .weather: String(localized: "tab_weather")
        case .route: String(localized: "tab_route")
        case .track: String(localized: "tab_track")
        case .extendedWind: String(localized: "tab_extended_wind")
        case .marineText: String(localized: "tab_marine_text")
        case .stormRadar: String(localized: "tab_storm_radar")
        }
    }

    var systemImage: String {
        switch self {
        case .compare: "map"
        case .weather: "cloud.sun.fill"
        case .route: "location.north.line"
        case .track: "scope"
        case .extendedWind: "calendar"
        case .marineText: "water.waves"
        case .stormRadar: "cloud.bolt.rain"
        }
    }

    var isPremium: Bool {
        switch self {
        case .route, .track, .extendedWind: true
        case .compare, .weather, .marineText, .stormRadar: false
        }
    }

    /// Android `nav_*` strings (multi-line where noted).
    var railLabel: String {
        switch self {
        case .compare: String(localized: "nav_compare")
        case .weather: String(localized: "nav_weather")
        case .route: String(localized: "nav_route")
        case .track: String(localized: "nav_track")
        case .extendedWind: String(localized: "nav_extended_wind")
        case .marineText: String(localized: "nav_marine_text")
        case .stormRadar: String(localized: "nav_storm_radar")
        }
    }
}
