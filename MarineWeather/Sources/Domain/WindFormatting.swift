import Foundation

enum WindFormatting {
    static func speed(_ ms: Double?, unit: WindUnit) -> String? {
        guard let ms else { return nil }
        switch unit {
        case .metersPerSecond:
            return String(format: "%.1f", ms)
        case .knots:
            return String(format: "%.0f", ms.msToKnots)
        }
    }

    static func cardinal(fromDegrees deg: Double) -> String {
        let dirs = [
            "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
            "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
        ]
        let x = ((deg.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let idx = Int(((x + 11.25) / 22.5).rounded(.down)) % 16
        return dirs[idx]
    }
}
