import Foundation

/// Local departure time helpers for route weather (15-minute grid, no past times).
enum RouteDepartureTime {
    static let snapIntervalMillis: Int64 = 15 * 60 * 1000

    static func snapToQuarterHour(millis: Int64) -> Int64 {
        (millis / snapIntervalMillis) * snapIntervalMillis
    }

    /// Smallest selectable departure: current time rounded up to the next 15-minute mark.
    static func minimumSelectableMillis(now: Date = Date()) -> Int64 {
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        let snapped = snapToQuarterHour(millis: ms)
        if snapped < ms { return snapped + snapIntervalMillis }
        return snapped
    }

    static func clampScheduledMillis(_ millis: Int64, now: Date = Date()) -> Int64 {
        max(snapToQuarterHour(millis: millis), minimumSelectableMillis(now: now))
    }

    static func effectiveDepartureMillis(isNow: Bool, scheduledMillis: Int64, now: Date = Date()) -> Int64 {
        if isNow {
            return Int64(now.timeIntervalSince1970 * 1000)
        }
        return scheduledMillis
    }

    static func formatLocalDateTime(millis: Int64, calendar: Calendar = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        let today = calendar.startOfDay(for: Date())
        let day = calendar.startOfDay(for: date)
        let time = date.formatted(date: .omitted, time: .shortened)
        if day == today { return time }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), day == tomorrow {
            return String(format: String(localized: "route_time_tomorrow_fmt"), time)
        }
        return date.formatted(
            .dateTime
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
                .hour()
                .minute()
        )
    }

    static func formatLocalDateTimeFull(millis: Int64, calendar: Calendar = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
