import CoreLocation
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
        let results = await repository.loadAll(lat: lat, lon: lon)

        guard !Task.isCancelled else { return }

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
        isRefreshing = false
    }
}
