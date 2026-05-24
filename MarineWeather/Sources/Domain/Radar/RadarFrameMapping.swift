import Foundation

enum RadarFrameMapping {
    static let lightningFrameLookbackMs: Int64 = 2 * 60 * 60 * 1000

    static func toActiveOverlay(_ frame: RadarAnimationFrame, sourceLabel: String) -> ActiveRadarOverlay {
        let wms: String? = switch frame.kind {
        case .wmsTiles:
            frame.wmsTileUrlTemplate ?? FmiRadarTimeSeries.wmsUrl(forTimeIso: frame.timeIso)
        case .geoImage:
            frame.wmsTileUrlTemplate
        }
        return ActiveRadarOverlay(
            sourceId: frame.sourceId,
            kind: frame.kind,
            sourceLabel: sourceLabel,
            timeLabel: frame.timeLabel,
            wmsTileUrlTemplate: wms,
            geoImageUrl: frame.geoImageUrl,
            geoBounds: frame.geoBounds
        )
    }

    static func epochMs(_ frame: RadarAnimationFrame) -> Int64? {
        ISO8601Parser.epochMillis(frame.timeIso)
    }

    static func filterLightning(
        strikes: [LightningStrike],
        frame: RadarAnimationFrame,
        lookbackBeforeFrameMs: Int64 = lightningFrameLookbackMs
    ) -> [LightningStrike] {
        if frame.offsetMinutesFromNow > 0 { return [] }
        guard let frameMs = epochMs(frame) else { return strikes }
        return strikes.filter {
            $0.observedAtEpochMs <= frameMs &&
            $0.observedAtEpochMs >= frameMs - lookbackBeforeFrameMs
        }
    }

    static func nowFrameIndex(in frames: [RadarAnimationFrame]) -> Int {
        if let idx = frames.firstIndex(where: { $0.offsetMinutesFromNow == 0 }) {
            return idx
        }
        return min(StormRadarTimeline.nowFrameIndex, max(frames.count - 1, 0))
    }

    static func frameRole(_ frame: RadarAnimationFrame) -> RadarFrameRole {
        if frame.offsetMinutesFromNow > 0 { return .forecast }
        if frame.offsetMinutesFromNow == 0 { return .now }
        return .observation
    }

    static func minutesBeforeNow(frames: [RadarAnimationFrame], index: Int) -> Int? {
        guard !frames.isEmpty else { return nil }
        let nowIdx = nowFrameIndex(in: frames)
        guard let nowMs = epochMs(frames[nowIdx]),
              let frameMs = epochMs(frames[min(max(index, 0), frames.count - 1)]) else {
            return nil
        }
        return max(0, Int((nowMs - frameMs) / 60_000))
    }

    static func minutesAfterNow(frames: [RadarAnimationFrame], index: Int) -> Int? {
        guard !frames.isEmpty else { return nil }
        let nowIdx = nowFrameIndex(in: frames)
        guard let nowMs = epochMs(frames[nowIdx]),
              let frameMs = epochMs(frames[min(max(index, 0), frames.count - 1)]) else {
            return nil
        }
        return max(0, Int((frameMs - nowMs) / 60_000))
    }
}
