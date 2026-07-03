import Foundation

actor WeatherRepository {
    func loadAll(lat: Double, lon: Double) async -> [SourceId: Result<UnifiedForecast, Error>] {
        await loadAllWithReport(lat: lat, lon: lon).forecasts
    }

    func loadAllWithReport(lat: Double, lon: Double) async -> WeatherLoadReport {
        let keyBase = "\(Self.roundKey(lat))_\(Self.roundKey(lon))"
        async let met = loadOne(source: .metNorway, keyBase: keyBase) {
            try await WeatherHTTPClient.fetchMetNorway(lat: lat, lon: lon)
        }
        async let smhi = loadOne(source: .smhi, keyBase: keyBase) {
            try await WeatherHTTPClient.fetchSmhi(lat: lat, lon: lon)
        }
        async let fmi = loadOne(source: .fmi, keyBase: keyBase) {
            try await WeatherHTTPClient.fetchFmi(lat: lat, lon: lon)
        }
        return WeatherLoadReport(bySource: [
            .metNorway: await met,
            .smhi: await smhi,
            .fmi: await fmi,
        ])
    }

    private func loadOne(
        source: SourceId,
        keyBase: String,
        operation: @Sendable () async throws -> UnifiedForecast
    ) async -> SourceWeatherOutcome {
        let cacheKey = "\(source.rawValue)_\(keyBase)"
        let cached = await MainActor.run {
            ForecastCacheStore.shared.read(cacheKey: cacheKey)
        }
        do {
            let forecast = try await operation()
            await MainActor.run {
                ForecastCacheStore.shared.upsert(cacheKey: cacheKey, forecast: forecast)
            }
            return SourceWeatherOutcome(result: .success(forecast), servedFromCache: false)
        } catch {
            if let cached {
                return SourceWeatherOutcome(result: .success(cached), servedFromCache: true)
            }
            return SourceWeatherOutcome(result: .failure(error), servedFromCache: false)
        }
    }

    private static func roundKey(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
