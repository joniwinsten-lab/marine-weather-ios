import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class CompareViewModel {
    var mapCenter: CLLocationCoordinate2D
    var windUnit: WindUnit
    private(set) var sourceStates: [SourceId: SourceForecastState]
    private(set) var isRefreshing = false
    private(set) var connectivityStatus = WeatherConnectivityStatus()

    private let repository = WeatherRepository()
    private var refreshTask: Task<Void, Never>?
    private var didInitialLoad = false

    init(
        mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(
            latitude: AppConfig.defaultLatitude,
            longitude: AppConfig.defaultLongitude
        )
    ) {
        self.mapCenter = mapCenter
        self.windUnit = UserPreferences.windUnit
        self.sourceStates = Dictionary(
            uniqueKeysWithValues: SourceId.allCases.map { ($0, .idle) }
        )
    }

    func onAppear() {
        guard !didInitialLoad else { return }
        didInitialLoad = true
        refresh()
    }

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { await performRefresh() }
    }

    func setMapCenter(_ coordinate: CLLocationCoordinate2D) {
        mapCenter = coordinate
        refresh()
    }

    func setWindUnit(_ unit: WindUnit) {
        windUnit = unit
        UserPreferences.windUnit = unit
    }

    func updateConnectivity(isOnline: Bool) {
        connectivityStatus.isOnline = isOnline
        recomputeConnectivityMeta()
    }

    private func performRefresh() async {
        isRefreshing = true
        for source in SourceId.allCases {
            sourceStates[source] = SourceForecastState(
                forecast: sourceStates[source]?.forecast,
                errorMessage: nil,
                loading: true
            )
        }

        let lat = mapCenter.latitude
        let lon = mapCenter.longitude
        let report = await repository.loadAllWithReport(lat: lat, lon: lon)

        guard !Task.isCancelled else { return }

        let results = report.forecasts
        for source in SourceId.allCases {
            switch results[source] {
            case .success(let forecast):
                sourceStates[source] = SourceForecastState(
                    forecast: forecast,
                    errorMessage: nil,
                    loading: false
                )
            case .failure(let error):
                sourceStates[source] = SourceForecastState(
                    forecast: sourceStates[source]?.forecast,
                    errorMessage: error.localizedDescription,
                    loading: false
                )
            case .none:
                sourceStates[source] = SourceForecastState(
                    forecast: nil,
                    errorMessage: "No response",
                    loading: false
                )
            }
        }

        let successfulForecasts = results.compactMapValues { try? $0.get() }
        let oldest = ForecastFreshness.oldestFetchedUtc(from: successfulForecasts)
        connectivityStatus.anyFromCache = report.anyServedFromCache
        connectivityStatus.allSourcesFailed = report.allSourcesFailed
        connectivityStatus.oldestFetchedUtc = oldest
        connectivityStatus.staleLevel = oldest.map { ForecastFreshness.staleLevel(fetchedAtUtc: $0) } ?? .fresh

        if !report.allSourcesFailed, !successfulForecasts.isEmpty {
            AppStoreReviewCoordinator.onPositiveEngagement()
        }

        isRefreshing = false
    }

    private func recomputeConnectivityMeta() {
        let forecasts = sourceStates.compactMapValues { $0.forecast }
        let oldest = ForecastFreshness.oldestFetchedUtc(from: forecasts)
        connectivityStatus.oldestFetchedUtc = oldest
        connectivityStatus.staleLevel = oldest.map { ForecastFreshness.staleLevel(fetchedAtUtc: $0) } ?? .fresh
        connectivityStatus.allSourcesFailed =
            !sourceStates.isEmpty && sourceStates.values.allSatisfy { $0.forecast == nil && $0.errorMessage != nil }
    }
}
