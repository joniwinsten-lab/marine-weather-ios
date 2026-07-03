import Foundation

enum AisFormatting {
    static func shipTypeLabel(code: Int?) -> String? {
        guard let code else { return nil }
        switch code {
        case 20...29: return String(localized: "ais_ship_type_wing")
        case 30: return String(localized: "ais_ship_type_fishing")
        case 31, 32: return String(localized: "ais_ship_type_towing")
        case 33: return String(localized: "ais_ship_type_dredging")
        case 34: return String(localized: "ais_ship_type_diving")
        case 35: return String(localized: "ais_ship_type_military")
        case 36: return String(localized: "ais_ship_type_sailing")
        case 37: return String(localized: "ais_ship_type_pleasure")
        case 40...49: return String(localized: "ais_ship_type_high_speed")
        case 50: return String(localized: "ais_ship_type_pilot")
        case 51: return String(localized: "ais_ship_type_sar")
        case 52: return String(localized: "ais_ship_type_tug")
        case 53: return String(localized: "ais_ship_type_port")
        case 54: return String(localized: "ais_ship_type_anti_pollution")
        case 55: return String(localized: "ais_ship_type_law")
        case 58: return String(localized: "ais_ship_type_medical")
        case 60...69: return String(localized: "ais_ship_type_passenger")
        case 70...79: return String(localized: "ais_ship_type_cargo")
        case 80...89: return String(localized: "ais_ship_type_tanker")
        case 90...99: return String(localized: "ais_ship_type_other")
        default:
            return String(format: String(localized: "ais_ship_type_code"), code)
        }
    }

    static func navStatusLabel(code: Int?) -> String? {
        guard let code else { return nil }
        switch code {
        case 0: return String(localized: "ais_nav_underway")
        case 1: return String(localized: "ais_nav_anchor")
        case 2: return String(localized: "ais_nav_nuc")
        case 3: return String(localized: "ais_nav_restricted")
        case 4: return String(localized: "ais_nav_draught")
        case 5: return String(localized: "ais_nav_moored")
        case 6: return String(localized: "ais_nav_aground")
        case 7: return String(localized: "ais_nav_fishing")
        case 8: return String(localized: "ais_nav_sailing")
        case 14: return String(localized: "ais_nav_ais_sart")
        default:
            return String(format: String(localized: "ais_nav_code"), code)
        }
    }

    static func formatSpeedKn(_ kn: Double?) -> String {
        guard let kn, kn.isFinite else { return "—" }
        return String(format: "%.1f kn", locale: Locale(identifier: "en_US_POSIX"), kn)
    }

    static func formatBearing(_ deg: Double?) -> String {
        guard let deg, deg.isFinite, deg >= 0, deg < 360 else { return "—" }
        return String(format: "%.0f°", locale: Locale(identifier: "en_US_POSIX"), deg)
    }

    static func formatHeading(_ deg: Int?) -> String {
        guard let deg, (0...359).contains(deg) else { return "—" }
        return String(format: "%d°", deg)
    }

    static func formatDraughtMeters(_ tenths: Int?) -> String? {
        guard let tenths, tenths > 0 else { return nil }
        let meters = Double(tenths) / 10.0
        return String(format: "%.1f m", locale: Locale(identifier: "en_US_POSIX"), meters)
    }

    static func formatDestination(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// AIS ETA field: MMDDHHMM (month/day/hour/minute, UTC).
    static func formatEta(_ eta: Int?) -> String? {
        guard let eta, eta > 0 else { return nil }
        let s = String(format: "%06d", eta % 1_000_000)
        guard s.count == 6,
              let month = Int(s.prefix(2)),
              let day = Int(s.dropFirst(2).prefix(2)),
              let hour = Int(s.dropFirst(4).prefix(2)),
              let minute = Int(s.suffix(2)),
              (1...12).contains(month),
              (1...31).contains(day),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }
        return String(format: "%02d-%02d %02d:%02d UTC", month, day, hour, minute)
    }
}
