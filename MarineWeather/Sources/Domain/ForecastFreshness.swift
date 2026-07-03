import Foundation

enum ForecastStaleLevel: Equatable {
    case fresh
    case soft
    case hard
}

enum ForecastFreshness {
    static let softStaleMs: Int64 = 6 * 60 * 60 * 1000
    static let hardStaleMs: Int64 = 12 * 60 * 60 * 1000

    static func staleLevel(fetchedAtUtc: Int64, nowUtc: Int64 = Self.nowMs) -> ForecastStaleLevel {
        let age = max(0, nowUtc - fetchedAtUtc)
        if age >= hardStaleMs { return .hard }
        if age >= softStaleMs { return .soft }
        return .fresh
    }

    static func oldestFetchedUtc(from forecasts: [SourceId: UnifiedForecast]) -> Int64? {
        forecasts.values.map(\.fetchedAtUtc).min()
    }

    private static var nowMs: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}

struct WeatherConnectivityStatus: Equatable {
    var isOnline = true
    var anyFromCache = false
    var allSourcesFailed = false
    var staleLevel: ForecastStaleLevel = .fresh
    var oldestFetchedUtc: Int64?
}
