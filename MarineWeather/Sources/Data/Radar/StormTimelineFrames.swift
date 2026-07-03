import Foundation

/// Adjust storm timeline frames for forecast display (Android `StormTimelineFrames.kt`).
enum StormTimelineFrames {
    static func enrichWithForecast(
        _ frames: [RadarAnimationFrame],
        forecastOverlays: [Int: ForecastRasterOverlay] = [:]
    ) -> [RadarAnimationFrame] {
        guard !frames.isEmpty else { return frames }

        return frames.map { frame in
            if frame.offsetMinutesFromNow == 0 {
                return RadarAnimationFrame(
                    sourceId: frame.sourceId,
                    kind: .wmsTiles,
                    timeIso: frame.timeIso,
                    timeLabel: frame.timeLabel,
                    offsetMinutesFromNow: frame.offsetMinutesFromNow,
                    wmsTileUrlTemplate: FmiRadarConfig.wmsTileURLTemplate,
                    geoImageUrl: nil,
                    geoBounds: nil
                )
            }
            if frame.offsetMinutesFromNow < 0 {
                return frame
            }
            if let overlay = forecastOverlays[frame.offsetMinutesFromNow] {
                return RadarAnimationFrame(
                    sourceId: frame.sourceId,
                    kind: .geoImage,
                    timeIso: frame.timeIso,
                    timeLabel: frame.timeLabel,
                    offsetMinutesFromNow: frame.offsetMinutesFromNow,
                    wmsTileUrlTemplate: nil,
                    geoImageUrl: overlay.fileURL,
                    geoBounds: overlay.bounds
                )
            }
            // FMI WMS has no future radar tiles — show latest mosaic (not empty TIME=).
            return RadarAnimationFrame(
                sourceId: frame.sourceId,
                kind: .wmsTiles,
                timeIso: frame.timeIso,
                timeLabel: frame.timeLabel,
                offsetMinutesFromNow: frame.offsetMinutesFromNow,
                wmsTileUrlTemplate: FmiRadarConfig.wmsTileURLTemplate,
                geoImageUrl: nil,
                geoBounds: nil
            )
        }
    }
}

struct ForecastRasterOverlay: Equatable {
    let fileURL: String
    let bounds: RadarGeoBounds
}
