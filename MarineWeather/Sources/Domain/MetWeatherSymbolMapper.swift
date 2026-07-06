import Foundation

/// Maps MET Norway `symbol_code` strings to FMI smart-symbol integers for icon CDN.
enum MetWeatherSymbolMapper {
    private static let dayCodes: [String: Int] = [
        "clearsky": 1,
        "fair": 2,
        "partlycloudy": 4,
        "mostlycloudy": 6,
        "cloudy": 7,
        "fog": 9,
        "lightrain": 11,
        "freezingdrizzle": 14,
        "freezingrain": 17,
        "lightsleet": 22,
        "sleet": 23,
        "lightsleetshowers": 24,
        "sleetshowers": 25,
        "lightrainshowers": 26,
        "rainshowers": 29,
        "heavyrainshowers": 30,
        "rain": 32,
        "heavyrain": 34,
        "thunder": 33,
        "rainandthunder": 33,
        "heavyrainandthunder": 33,
        "lightrainandthunder": 33,
        "sleetandthunder": 33,
        "lightsnowshowers": 72,
        "snowshowers": 73,
        "lightsnow": 71,
        "snow": 75,
        "heavysnow": 77,
        "snowandthunder": 86,
    ]

    static func fmiCode(from metSymbolCode: String) -> Int {
        let lowered = metSymbolCode.lowercased()
        let isNight = lowered.contains("_night") || lowered.contains("polartwilight")
        let base = lowered
            .replacingOccurrences(of: "_day", with: "")
            .replacingOccurrences(of: "_night", with: "")
            .replacingOccurrences(of: "_polartwilight", with: "")

        if let day = dayCodes[base] {
            return isNight ? day + 100 : day
        }

        let sortedKeys = dayCodes.keys.sorted { $0.count > $1.count }
        for key in sortedKeys {
            if base.hasPrefix(key) {
                let day = dayCodes[key]!
                return isNight ? day + 100 : day
            }
        }

        return isNight ? 107 : 7
    }
}
