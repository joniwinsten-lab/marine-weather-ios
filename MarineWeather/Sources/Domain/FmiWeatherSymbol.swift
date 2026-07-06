import Foundation

/// FMI smart weather symbols — https://www.ilmatieteenlaitos.fi/saamerkkien-selitykset
enum FmiWeatherSymbol {
    /// Day codes that exist on the public CDN (PNG). HARMONIE may emit gaps (e.g. 3, 103).
    private static let availableDayCodes = [
        1, 2, 4, 6, 7, 9, 11, 14, 17, 21, 24, 27,
        31, 32, 33, 34, 35, 36, 37, 38, 39,
        41, 42, 43, 44, 45, 46, 47, 48, 49,
        51, 52, 53, 54, 55, 56, 57, 58, 59,
        61, 64, 67, 71, 74, 77,
    ]

    static func imageURL(code: Int) -> URL? {
        URL(string: "https://cdn.fmi.fi/symbol-images/smartsymbol/v3/p/\(normalizedCDNCode(code)).png")
    }

    /// Maps HARMONIE symbol integers to the nearest CDN asset.
    static func normalizedCDNCode(_ code: Int) -> Int {
        let isNight = code >= 100
        let dayCode = isNight ? code - 100 : code
        let normalizedDay = nearestAvailableDayCode(dayCode)
        return isNight ? normalizedDay + 100 : normalizedDay
    }

    private static func nearestAvailableDayCode(_ dayCode: Int) -> Int {
        if availableDayCodes.contains(dayCode) { return dayCode }
        if let lower = availableDayCodes.last(where: { $0 <= dayCode }) { return lower }
        return availableDayCodes.first ?? 7
    }
}
