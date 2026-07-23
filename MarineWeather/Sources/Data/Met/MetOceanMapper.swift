import Foundation

enum MetOceanMapper {
    /// Epoch millis → significant wave height (m).
    static func waveHeightsByInstant(_ feature: MetOceanFeature) -> [(instantUtc: Int64, heightM: Double)] {
        feature.properties.timeseries.compactMap { ts in
            guard let instant = ISO8601Parser.epochMillis(ts.time),
                  let height = ts.data.instant?.details?.seaSurfaceWaveHeight
            else { return nil }
            return (instant, height)
        }
    }

    /// Merge nearest ocean Hs into each weather point (leaves points unchanged when no ocean data).
    static func mergingWaveHeights(
        into forecast: UnifiedForecast,
        ocean: MetOceanFeature
    ) -> UnifiedForecast {
        let waves = waveHeightsByInstant(ocean)
        guard !waves.isEmpty else { return forecast }

        let points = forecast.points.map { point -> UnifiedTimePoint in
            let nearest = waves.min(by: { abs($0.instantUtc - point.instantUtc) < abs($1.instantUtc - point.instantUtc) })
            return UnifiedTimePoint(
                instantUtc: point.instantUtc,
                airTempC: point.airTempC,
                windSpeedMs: point.windSpeedMs,
                windFromDeg: point.windFromDeg,
                windGustMs: point.windGustMs,
                precipitationMmPerH: point.precipitationMmPerH,
                thunderProbPercent: point.thunderProbPercent,
                weatherSymbolCode: point.weatherSymbolCode,
                waveHeightM: nearest?.heightM
            )
        }

        return UnifiedForecast(
            source: forecast.source,
            fetchedAtUtc: forecast.fetchedAtUtc,
            modelInfo: forecast.modelInfo,
            points: points
        )
    }
}
