import Foundation

enum MetMapper {
    static func toUnified(_ feature: MetFeature, fetchedAtUtc: Int64) -> UnifiedForecast {
        let modelInfo: String? = {
            guard let updated = feature.properties.meta?.updatedAt else { return nil }
            return "updated=\(updated)"
        }()

        let points = feature.properties.timeseries.compactMap { ts -> UnifiedTimePoint? in
            guard let instant = ISO8601Parser.epochMillis(ts.time) else { return nil }
            let d = ts.data.instant?.details
            let n1 = ts.data.next1Hours?.details
            let symbolCode = ts.data.next1Hours?.summary?.symbolCode
                .map { MetWeatherSymbolMapper.fmiCode(from: $0) }
            return UnifiedTimePoint(
                instantUtc: instant,
                airTempC: d?.airTemperature,
                windSpeedMs: d?.windSpeed,
                windFromDeg: d?.windFromDirection,
                windGustMs: d?.windSpeedOfGust,
                precipitationMmPerH: n1?.precipitationAmount,
                thunderProbPercent: n1?.probabilityOfThunder,
                weatherSymbolCode: symbolCode
            )
        }

        return UnifiedForecast(
            source: WeatherSources.metNorway,
            fetchedAtUtc: fetchedAtUtc,
            modelInfo: modelInfo,
            points: points
        )
    }
}
