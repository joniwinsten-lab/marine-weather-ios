import Foundation
import SwiftData

/// Offline forecast cache (Android Room `ForecastCacheDao`).
@MainActor
final class ForecastCacheStore {
    static let shared = ForecastCacheStore()

    private let container: ModelContainer
    private let context: ModelContext

    private init() {
        container = try! ModelContainer(for: ForecastCacheEntity.self)
        context = ModelContext(container)
    }

    func read(cacheKey: String) -> UnifiedForecast? {
        let key = cacheKey
        var descriptor = FetchDescriptor<ForecastCacheEntity>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        descriptor.fetchLimit = 1
        guard let row = try? context.fetch(descriptor).first else { return nil }
        return CachedForecastPayload.decode(from: row.json)
    }

    func upsert(cacheKey: String, forecast: UnifiedForecast) {
        let json = CachedForecastPayload.encode(forecast)
        let key = cacheKey
        var descriptor = FetchDescriptor<ForecastCacheEntity>(
            predicate: #Predicate { $0.cacheKey == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.json = json
            existing.updatedAt = forecast.fetchedAtUtc
        } else {
            context.insert(
                ForecastCacheEntity(
                    cacheKey: cacheKey,
                    json: json,
                    updatedAt: forecast.fetchedAtUtc
                )
            )
        }
        try? context.save()
    }
}

private struct CachedForecastPayload: Codable {
    let sourceId: String
    let fetchedAtUtc: Int64
    let modelInfo: String?
    let points: [CachedTimePoint]

    struct CachedTimePoint: Codable {
        let instantUtc: Int64
        let airTempC: Double?
        let windSpeedMs: Double?
        let windFromDeg: Double?
        let windGustMs: Double?
        let precipitationMmPerH: Double?
        let thunderProbPercent: Double?
    }

    static func encode(_ forecast: UnifiedForecast) -> String {
        let payload = CachedForecastPayload(
            sourceId: forecast.source.id.rawValue,
            fetchedAtUtc: forecast.fetchedAtUtc,
            modelInfo: forecast.modelInfo,
            points: forecast.points.map {
                CachedTimePoint(
                    instantUtc: $0.instantUtc,
                    airTempC: $0.airTempC,
                    windSpeedMs: $0.windSpeedMs,
                    windFromDeg: $0.windFromDeg,
                    windGustMs: $0.windGustMs,
                    precipitationMmPerH: $0.precipitationMmPerH,
                    thunderProbPercent: $0.thunderProbPercent
                )
            }
        )
        let data = try! JSONEncoder().encode(payload)
        return String(data: data, encoding: .utf8)!
    }

    static func decode(from json: String) -> UnifiedForecast? {
        guard let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(CachedForecastPayload.self, from: data),
              let sourceId = SourceId(rawValue: payload.sourceId) else {
            return nil
        }
        return UnifiedForecast(
            source: WeatherSources.source(for: sourceId),
            fetchedAtUtc: payload.fetchedAtUtc,
            modelInfo: payload.modelInfo,
            points: payload.points.map {
                UnifiedTimePoint(
                    instantUtc: $0.instantUtc,
                    airTempC: $0.airTempC,
                    windSpeedMs: $0.windSpeedMs,
                    windFromDeg: $0.windFromDeg,
                    windGustMs: $0.windGustMs,
                    precipitationMmPerH: $0.precipitationMmPerH,
                    thunderProbPercent: $0.thunderProbPercent
                )
            }
        )
    }
}
