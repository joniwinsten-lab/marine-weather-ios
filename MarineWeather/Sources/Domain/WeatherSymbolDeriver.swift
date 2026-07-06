import Foundation

/// Derives FMI smart-symbol codes when the provider does not supply one (e.g. SMHI).
enum WeatherSymbolDeriver {
    static func fmiCode(
        precipitationMm: Double?,
        thunderProb: Double?,
        instantUtc: Int64,
        timeZone: TimeZone = .current
    ) -> Int {
        let precip = precipitationMm ?? 0
        let thunder = thunderProb ?? 0
        let night = isNight(instantUtc: instantUtc, timeZone: timeZone)

        let dayCode: Int
        if thunder >= 30 {
            dayCode = 33
        } else if precip >= 4 {
            dayCode = 32
        } else if precip >= 1 {
            dayCode = 26
        } else if precip >= 0.1 {
            dayCode = 11
        } else {
            dayCode = 4
        }

        return night ? dayCode + 100 : dayCode
    }

    private static func isNight(instantUtc: Int64, timeZone: TimeZone) -> Bool {
        let date = Date(timeIntervalSince1970: TimeInterval(instantUtc) / 1000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        return hour < 6 || hour >= 21
    }
}
