import Foundation

enum CompositeRadarRepository {
    static func loadActiveOverlay(lat: Double, lon: Double) async -> ActiveRadarOverlay {
        let now = Date()
        return ActiveRadarOverlay(
            sourceId: .fmi,
            kind: .wmsTiles,
            sourceLabel: "FMI",
            timeLabel: FmiInstantFormat.toDisplayHHmm(now),
            wmsTileUrlTemplate: FmiRadarConfig.wmsTileURLTemplate,
            geoImageUrl: nil,
            geoBounds: nil
        )
    }

    static func loadAnimation(lat: Double, lon: Double) async -> [RadarAnimationFrame] {
        _ = (lat, lon)
        return FmiRadarTimeSeries.buildStormTimelineFrames()
    }
}
