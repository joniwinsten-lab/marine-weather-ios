import Foundation

/// FMI WFS/WMS time parameters — no fractional seconds (Android `FmiInstantFormat.kt`).
enum FmiInstantFormat {
    private static let paramFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func toParam(_ date: Date) -> String {
        let wholeSeconds = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970))
        return paramFormatter.string(from: wholeSeconds)
    }

    static func toDisplayHHmm(_ date: Date) -> String {
        displayFormatter.string(from: date)
    }
}
