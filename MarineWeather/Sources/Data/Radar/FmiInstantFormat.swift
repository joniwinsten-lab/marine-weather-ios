import Foundation

enum FmiInstantFormat {
    private static let paramFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "HH:mm"
        return f
    }()

    static func toParam(_ date: Date) -> String {
        paramFormatter.string(from: date)
    }

    static func toDisplayHHmm(_ date: Date) -> String {
        displayFormatter.string(from: date)
    }
}
