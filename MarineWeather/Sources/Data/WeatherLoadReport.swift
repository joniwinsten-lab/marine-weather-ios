import Foundation

struct SourceWeatherOutcome: Sendable {
    let result: Result<UnifiedForecast, Error>
    let servedFromCache: Bool
}

struct WeatherLoadReport: Sendable {
    let bySource: [SourceId: SourceWeatherOutcome]

    var forecasts: [SourceId: Result<UnifiedForecast, Error>] {
        Dictionary(uniqueKeysWithValues: bySource.map { ($0.key, $0.value.result) })
    }

    var anyServedFromCache: Bool {
        bySource.values.contains(where: \.servedFromCache)
    }

    var allSourcesFailed: Bool {
        !bySource.isEmpty && bySource.values.allSatisfy {
            if case .failure = $0.result { return true }
            return false
        }
    }
}
