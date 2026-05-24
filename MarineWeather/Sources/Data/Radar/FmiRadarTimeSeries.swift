import Foundation

enum FmiRadarTimeSeries {
    static func wmsUrl(forTimeIso iso: String) -> String {
        FmiRadarConfig.wmsTileURLTemplate + "&TIME=" + (iso.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? iso)
    }

    static func buildStormTimelineFrames(now: Date = Date()) -> [RadarAnimationFrame] {
        StormRadarTimeline.offsetsMinutes.map { offset in
            let t = Calendar.current.date(byAdding: .minute, value: offset, to: now) ?? now
            return frame(at: t, offsetMinutesFromNow: offset)
        }
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
