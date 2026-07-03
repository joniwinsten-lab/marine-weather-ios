import Foundation

enum CompositeRadarRepository {
    static func loadActiveOverlay(lat: Double, lon: Double) async -> ActiveRadarOverlay {
        switch RadarRegionSelector.preferredSource(lat: lat, lon: lon) {
        case .fmi:
            return await loadFmiOverlay()
        case .metNordic:
            if let overlay = await MetNorwayRadarRepository.loadLatestOverlay() {
                return overlay
            }
            return await loadFmiOverlay()
        case .smhi:
            if let overlay = await SmhiRadarRepository.loadLatestOverlay() {
                return overlay
            }
            if let overlay = await MetNorwayRadarRepository.loadLatestOverlay() {
                return overlay
            }
            return await loadFmiOverlay()
        }
    }

    private static func loadFmiOverlay() async -> ActiveRadarOverlay {
        let anchor = await FmiRadarRepository.latestRadarInstant() ?? Date()
        return ActiveRadarOverlay(
            sourceId: .fmi,
            kind: .wmsTiles,
            sourceLabel: "FMI",
            timeLabel: FmiInstantFormat.toDisplayHHmm(anchor),
            wmsTileUrlTemplate: FmiRadarConfig.wmsTileURLTemplate,
            geoImageUrl: nil,
            geoBounds: nil
        )
    }

    static func loadAnimation(lat: Double, lon: Double) async -> [RadarAnimationFrame] {
        let anchor = await FmiRadarRepository.latestRadarInstant() ?? Date()
        async let observationFrames = Task {
            FmiRadarTimeSeries.buildStormTimelineFrames(anchor: anchor)
        }.value
        async let forecastOverlays = Task {
            await FmiForecastRadarRepository.buildForecastOverlays(
                anchor: anchor,
                lat: lat,
                lon: lon
            )
        }.value
        let frames = await observationFrames
        let overlays = await forecastOverlays
        return StormTimelineFrames.enrichWithForecast(frames, forecastOverlays: overlays)
    }
}
