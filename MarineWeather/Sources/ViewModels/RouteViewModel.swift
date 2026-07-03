import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class RouteViewModel {
    var mapCenter: CLLocationCoordinate2D
    var windUnit: WindUnit
    var boatSpeedKn: Double = 6.0
    var routeStart: RouteCoordinate?
    var routeEnd: RouteCoordinate?
    var routeGeometry: [RouteCoordinate] = []
    var routeFairwayUnavailable = false
    var isRoutingRoute = false
    private(set) var routeWeatherBySource: [SourceId: RouteSourceWeatherState] = [:]
    private(set) var routeWeatherLegNm: Double?
    private(set) var routeWeatherEtaHours: Double?
    private(set) var loadingRouteWeather = false

    private let repository = WeatherRepository()
    private var routeWeatherTask: Task<Void, Never>?
    private var routingTask: Task<Void, Never>?

    init(
        mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(
            latitude: AppConfig.defaultLatitude,
            longitude: AppConfig.defaultLongitude
        )
    ) {
        self.mapCenter = mapCenter
        self.windUnit = UserPreferences.windUnit
        resetRouteWeatherStates()
    }

    func setWindUnit(_ unit: WindUnit) {
        windUnit = unit
        UserPreferences.windUnit = unit
    }

    func setMapCenter(_ coordinate: CLLocationCoordinate2D) {
        mapCenter = coordinate
    }

    /// Keep route map aligned with Compare tab centre without re-fetching weather.
    func syncMapCenter(_ coordinate: CLLocationCoordinate2D) {
        mapCenter = coordinate
    }

    func setBoatSpeedKn(_ value: Double) {
        boatSpeedKn = min(40, max(0.5, value))
        scheduleRouteWeatherRefresh()
    }

    /// Long-press on route map: 1st = start, 2nd = end, 3rd = new start.
    func onMapLongPress(lat: Double, lon: Double) {
        guard PremiumAccess.shared.isPremium else { return }
        if routeStart == nil {
            routeStart = (lat, lon)
            routeEnd = nil
            routeGeometry = []
            routeFairwayUnavailable = false
        } else if routeEnd == nil {
            routeEnd = (lat, lon)
        } else {
            routeStart = (lat, lon)
            routeEnd = nil
            routeGeometry = []
            routeFairwayUnavailable = false
        }
        recomputeRouteGeometry()
    }

    func clearRoute() {
        routingTask?.cancel()
        routeWeatherTask?.cancel()
        routeStart = nil
        routeEnd = nil
        routeGeometry = []
        routeFairwayUnavailable = false
        isRoutingRoute = false
        routeWeatherLegNm = nil
        routeWeatherEtaHours = nil
        loadingRouteWeather = false
        resetRouteWeatherStates()
    }

    func onPremiumChanged(isPremium: Bool) {
        if !isPremium {
            clearRoute()
        } else {
            scheduleRouteWeatherRefresh()
        }
    }

    private func resetRouteWeatherStates() {
        routeWeatherBySource = Dictionary(
            uniqueKeysWithValues: SourceId.allCases.map { ($0, .idle) }
        )
    }

    private func recomputeRouteGeometry() {
        guard PremiumAccess.shared.isPremium else { return }
        guard let start = routeStart, let end = routeEnd else {
            routeGeometry = []
            routeFairwayUnavailable = false
            scheduleRouteWeatherRefresh()
            return
        }
        routeGeometry = []
        routeFairwayUnavailable = false
        isRoutingRoute = true
        scheduleRouteWeatherRefresh()

        routingTask?.cancel()
        let launchStart = start
        let launchEnd = end
        routingTask = Task {
            let fairway = await VaylaFairwayRouter.routeAlongNavLines(
                lat1: launchStart.lat,
                lon1: launchStart.lon,
                lat2: launchEnd.lat,
                lon2: launchEnd.lon
            )
            guard !Task.isCancelled else { return }
            guard routeStart?.lat == launchStart.lat,
                  routeStart?.lon == launchStart.lon,
                  routeEnd?.lat == launchEnd.lat,
                  routeEnd?.lon == launchEnd.lon else { return }

            isRoutingRoute = false
            if let fairway, fairway.count >= 2,
               fairway.allSatisfy({ $0.lat.isFinite && $0.lon.isFinite }) {
                routeGeometry = fairway
                routeFairwayUnavailable = false
            } else {
                routeGeometry = GeoMath.greatCirclePoints(
                    lat1: launchStart.lat,
                    lon1: launchStart.lon,
                    lat2: launchEnd.lat,
                    lon2: launchEnd.lon
                )
                routeFairwayUnavailable = true
            }
            scheduleRouteWeatherRefresh()
        }
    }

    func routePointsForExport() -> [RouteCoordinate] {
        if routeGeometry.count >= 2 { return routeGeometry }
        if let start = routeStart, let end = routeEnd { return [start, end] }
        return []
    }

    private func scheduleRouteWeatherRefresh() {
        routeWeatherTask?.cancel()
        routeWeatherTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await refreshRouteWeather()
        }
    }

    private func refreshRouteWeather() async {
        guard PremiumAccess.shared.isPremium else {
            routeWeatherLegNm = nil
            routeWeatherEtaHours = nil
            loadingRouteWeather = false
            resetRouteWeatherStates()
            return
        }
        guard let start = routeStart, let end = routeEnd else {
            routeWeatherLegNm = nil
            routeWeatherEtaHours = nil
            loadingRouteWeather = false
            resetRouteWeatherStates()
            return
        }

        let geom: [RouteCoordinate] =
            routeGeometry.count >= 2 ? routeGeometry : [start, end]
        let totalM = GeoMath.polylineLengthMeters(geom)
        let totalNm = GeoMath.metersToNauticalMiles(totalM)
        let speedKn = min(40, max(0.5, boatSpeedKn))
        let etaHours = totalNm > 1e-6 ? totalNm / speedKn : 0
        let depart = Int64(Date().timeIntervalSince1970 * 1000)
        let etaMillis = max(60_000, Int64(etaHours * 3_600_000))
        let fracs = [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]
        let locs = fracs.map { GeoMath.pointAlongPolyline(geom, fraction: $0) }
        let targets = fracs.map { f in depart + Int64(Double(etaMillis) * f) }

        routeWeatherLegNm = totalNm
        routeWeatherEtaHours = etaHours
        loadingRouteWeather = true
        for source in SourceId.allCases {
            routeWeatherBySource[source] = RouteSourceWeatherState(
                slots: routeWeatherBySource[source]?.slots,
                errorMessage: nil,
                loading: true
            )
        }

        var chunks: [(Int, [SourceId: Result<UnifiedForecast, Error>])] = []
        await withTaskGroup(of: (Int, [SourceId: Result<UnifiedForecast, Error>]).self) { group in
            for (i, loc) in locs.enumerated() {
                group.addTask {
                    let results = await self.repository.loadAll(lat: loc.lat, lon: loc.lon)
                    return (i, results)
                }
            }
            for await chunk in group {
                chunks.append(chunk)
            }
        }
        chunks.sort { $0.0 < $1.0 }

        guard !Task.isCancelled else { return }

        for source in SourceId.allCases {
            var slotArr: [UnifiedTimePoint?] = Array(repeating: nil, count: 4)
            var meta: String?
            var fetchedAt: Int64 = 0
            var firstError: String?

            for (i, forecastsAtLeg) in chunks {
                guard let result = forecastsAtLeg[source] else { continue }
                switch result {
                case .success(let fc):
                    let picked = ForecastSampler.sampleAtTargetMillis(
                        points: fc.points,
                        targetsMillis: [targets[i]]
                    ).first ?? nil
                    slotArr[i] = picked
                    if i == 0 {
                        meta = fc.modelInfo
                        fetchedAt = fc.fetchedAtUtc
                    }
                case .failure(let error):
                    if firstError == nil {
                        firstError = error.localizedDescription
                    }
                }
            }

            if slotArr.allSatisfy({ $0 == nil }), let firstError {
                routeWeatherBySource[source] = RouteSourceWeatherState(
                    slots: nil,
                    errorMessage: firstError,
                    loading: false
                )
            } else {
                routeWeatherBySource[source] = RouteSourceWeatherState(
                    slots: RouteSourceWeatherSlots(
                        slots: slotArr,
                        fetchedAtUtc: fetchedAt,
                        modelInfo: meta
                    ),
                    errorMessage: nil,
                    loading: false
                )
            }
        }
        loadingRouteWeather = false
    }

    func routeSlotLabels() -> [String] {
        guard routeStart != nil, routeEnd != nil else {
            return Array(repeating: "—", count: 4)
        }
        let leg = routeWeatherLegNm ?? {
            let g = routeGeometry.count >= 2 ? routeGeometry : [routeStart!, routeEnd!]
            return GeoMath.metersToNauticalMiles(GeoMath.polylineLengthMeters(g))
        }()
        let fracs = [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]
        let speedKn = min(40, max(0.5, boatSpeedKn))
        let etaMinutesTotal = leg > 0 ? Int((leg / speedKn * 60).rounded()) : 0
        let nmPoints = [0.0, leg / 3.0, leg * 2.0 / 3.0, leg]
        return zip(nmPoints, fracs).map { nm, fr in
            let elapsedMin = max(0, Int((Double(etaMinutesTotal) * fr).rounded()))
            let distStr = String(format: String(localized: "route_weather_slot_nm"), nm)
            let timeStr: String
            if elapsedMin < 60 {
                timeStr = String(format: String(localized: "route_duration_min"), elapsedMin)
            } else {
                timeStr = String(format: String(localized: "route_duration_hm"), elapsedMin / 60, elapsedMin % 60)
            }
            return String(format: String(localized: "route_slot_label"), distStr, timeStr)
        }
    }
}
