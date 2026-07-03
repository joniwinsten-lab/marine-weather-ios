import Foundation

enum FmiRadarTimeSeries {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func wmsUrl(forTimeIso iso: String) -> String {
        let encoded = iso.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? iso
        return FmiRadarConfig.wmsTileURLTemplate + "&TIME=" + encoded
    }

    static func buildStormTimelineFrames(anchor: Date = Date()) -> [RadarAnimationFrame] {
        StormRadarTimeline.offsetsMinutes.map { offset in
            let t = utcCalendar.date(byAdding: .minute, value: offset, to: anchor) ?? anchor
            return frame(at: t, offsetMinutesFromNow: offset)
        }
    }

    static func parseDimensionEnd(_ dimension: String) -> Date? {
        let endIso = dimension.split(separator: "/").dropFirst().first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let endIso else { return nil }
        return ISO8601Parser.epochMillis(endIso).map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
    }

    private static func frame(at date: Date, offsetMinutesFromNow: Int) -> RadarAnimationFrame {
        let iso = FmiInstantFormat.toParam(date)
        let wms =
            offsetMinutesFromNow == 0
            ? FmiRadarConfig.wmsTileURLTemplate
            : wmsUrl(forTimeIso: iso)
        return RadarAnimationFrame(
            sourceId: .fmi,
            kind: .wmsTiles,
            timeIso: iso,
            timeLabel: FmiInstantFormat.toDisplayHHmm(date),
            offsetMinutesFromNow: offsetMinutesFromNow,
            wmsTileUrlTemplate: wms,
            geoImageUrl: nil,
            geoBounds: nil
        )
    }
}
