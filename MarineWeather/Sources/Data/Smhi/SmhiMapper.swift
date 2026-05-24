import Foundation

enum SmhiMapper {
    static func toUnified(_ response: SmhiPointResponse, fetchedAtUtc: Int64) -> UnifiedForecast {
        var modelInfo = "SNOW1g"
        if let ref = response.referenceTime {
            modelInfo += " ref=\(ref)"
        }

        let points = response.timeSeries.compactMap { ts -> UnifiedTimePoint? in
            guard let instant = ISO8601Parser.epochMillis(ts.time) else { return nil }
            let d = ts.data
            return UnifiedTimePoint(
                instantUtc: instant,
                airTempC: d.airTemperature,
                windSpeedMs: d.windSpeed,
                windFromDeg: d.windFromDirection,
                windGustMs: d.windSpeedOfGust,
                precipitationMmPerH: d.precipitationAmountMeanDeterministic ?? d.precipitationAmountMean,
                thunderProbPercent: d.thunderstormProbability
            )
        }

        return UnifiedForecast(
            source: WeatherSources.smhi,
            fetchedAtUtc: fetchedAtUtc,
            modelInfo: modelInfo,
            points: points
        )
    }
}
