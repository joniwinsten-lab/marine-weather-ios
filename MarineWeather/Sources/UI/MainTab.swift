import Foundation

/// Main navigation destinations (Android `MainDest`).
enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case compare
    case route
    case extendedWind
    case marineText
    case stormRadar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compare: String(localized: "tab_compare")
        case .route: String(localized: "tab_route")
        case .extendedWind: String(localized: "tab_extended_wind")
        case .marineText: String(localized: "tab_marine_text")
        case .stormRadar: String(localized: "tab_storm_radar")
        }
    }

    var systemImage: String {
        switch self {
        case .compare: "map"
        case .route: "location.north.line"
        case .extendedWind: "calendar"
        case .marineText: "water.waves"
        case .stormRadar: "cloud.bolt.rain"
        }
    }

    var isPremium: Bool {
        switch self {
        case .route, .extendedWind: true
        case .compare, .marineText, .stormRadar: false
        }
    }

    var railLabel: String {
        switch self {
        case .compare: String(localized: "nav_compare")
        case .route: String(localized: "nav_route")
        case .extendedWind: String(localized: "nav_extended_wind")
        case .marineText: String(localized: "nav_marine_text")
        case .stormRadar: String(localized: "nav_storm_radar")
        }
    }
}
