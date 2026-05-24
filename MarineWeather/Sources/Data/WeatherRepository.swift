import Foundation

actor WeatherRepository {
    func loadAll(lat: Double, lon: Double) async -> [SourceId: Result<UnifiedForecast, Error>] {
        let keyBase = "\(Self.roundKey(lat))_\(Self.roundKey(lon))"

        async let met = fetchWithCache(source: .metNorway, keyBase: keyBase) {
            try await WeatherHTTPClient.fetchMetNorway(lat: lat, lon: lon)
        }
        async let smhi = fetchWithCache(source: .smhi, keyBase: keyBase) {
            try await WeatherHTTPClient.fetchSmhi(lat: lat, lon: lon)
        }
        async let fmi = fetchWithCache(source: .fmi, keyBase: keyBase) {
            try await WeatherHTTPClient.fetchFmi(lat: lat, lon: lon)
        }

        return [
            .metNorway: await met,
            .smhi: await smhi,
            .fmi: await fmi,
        ]
    }

    private func fetchWithCache(
        source: SourceId,
        keyBase: String,
        operation: @Sendable () async throws -> UnifiedForecast
    ) async -> Result<UnifiedForecast, Error> {
        let cacheKey = "\(source.rawValue)_\(keyBase)"
        do {
            let forecast = try await operation()
            await MainActor.run {
                ForecastCacheStore.shared.upsert(cacheKey: cacheKey, forecast: forecast)
            }
            return .success(forecast)
        } catch {
            let cached = await MainActor.run {
                ForecastCacheStore.shared.read(cacheKey: cacheKey)
            }
            if let cached {
                return .success(cached)
            }
            return .failure(error)
        }
    }

    private static func roundKey(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
