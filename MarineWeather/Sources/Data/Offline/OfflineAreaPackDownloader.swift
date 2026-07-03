import Foundation

enum OfflineAreaPackDownloader {
    struct Progress: Sendable {
        let stepKey: String
        let current: Int
        let total: Int
    }

    struct Result: Sendable {
        let weatherSamples: Int
        let routeVertices: Int
    }

    static func downloadRoutePack(
        routeGeometry: [RouteCoordinate],
        marineTitlesByCountry: [String: String],
        onProgress: @Sendable @escaping (Progress) -> Void
    ) async throws -> Result {
        guard routeGeometry.count >= 2 else {
            throw OfflinePackError.routeTooShort
        }
        let samples = GeoMath.samplePointsAlongRoute(routeGeometry)
        guard let bounds = GeoMath.boundsAroundPolyline(routeGeometry, paddingDeg: 0.15) else {
            throw OfflinePackError.boundsUnavailable
        }

        let totalSteps = samples.count + 2
        var step = 0

        func report(_ key: String, current: Int? = nil, total: Int? = nil) {
            onProgress(Progress(
                stepKey: key,
                current: current ?? min(step, totalSteps),
                total: total ?? totalSteps
            ))
        }

        report("tiles")
        await MapTileWarmup.warmRouteCorridor(routePoints: routeGeometry)
        step += 1

        report("marine")
        let mid = samples[samples.count / 2]
        _ = await MarineTextRepository().loadOverview(
            lat: mid.lat,
            lon: mid.lon,
            titlesByCountry: marineTitlesByCountry
        )
        step += 1

        let repository = WeatherRepository()
        for (index, point) in samples.enumerated() {
            report("weather", current: index + 1, total: samples.count)
            _ = await repository.loadAllWithReport(lat: point.lat, lon: point.lon)
        }
        step = totalSteps

        let label = String(
            format: "%.2f,%.2f → %.2f,%.2f",
            routeGeometry.first!.lat,
            routeGeometry.first!.lon,
            routeGeometry.last!.lat,
            routeGeometry.last!.lon
        )
        await MainActor.run {
            OfflineAreaPackStore.shared.insert(
                OfflineAreaPackEntity(
                    createdAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                    routePointCount: routeGeometry.count,
                    weatherSampleCount: samples.count,
                    minLat: bounds.minLat,
                    minLon: bounds.minLon,
                    maxLat: bounds.maxLat,
                    maxLon: bounds.maxLon,
                    label: label
                )
            )
        }

        report("done", current: totalSteps, total: totalSteps)
        return Result(weatherSamples: samples.count, routeVertices: routeGeometry.count)
    }
}

enum OfflinePackError: LocalizedError {
    case routeTooShort
    case boundsUnavailable

    var errorDescription: String? {
        switch self {
        case .routeTooShort, .boundsUnavailable:
            return String(localized: "offline_pack_failed")
        }
    }
}
