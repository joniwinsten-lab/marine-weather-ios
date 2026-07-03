import Foundation
import Observation

struct OfflinePackUiState: Equatable {
    var downloading = false
    var stepKey: String?
    var current = 0
    var total = 0
    var lastSuccessWeatherSamples: Int?
    var lastSuccessRouteVertices: Int?
    var lastFailed = false
}

@MainActor
@Observable
final class OfflinePackViewModel {
    private(set) var state = OfflinePackUiState()

    func download(routeGeometry: [RouteCoordinate]) {
        guard routeGeometry.count >= 2, !state.downloading else { return }
        state = OfflinePackUiState(downloading: true)
        let titles: [String: String] = [
            "NO": String(localized: "marine_text_country_no"),
            "SE": String(localized: "marine_text_country_se"),
            "FI": String(localized: "marine_text_country_fi"),
            "EE": String(localized: "marine_text_country_ee"),
        ]
        Task {
            do {
                let result = try await OfflineAreaPackDownloader.downloadRoutePack(
                    routeGeometry: routeGeometry,
                    marineTitlesByCountry: titles
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.state.downloading = true
                        self?.state.stepKey = progress.stepKey
                        self?.state.current = progress.current
                        self?.state.total = progress.total
                    }
                }
                state = OfflinePackUiState(
                    lastSuccessWeatherSamples: result.weatherSamples,
                    lastSuccessRouteVertices: result.routeVertices
                )
            } catch {
                state = OfflinePackUiState(lastFailed: true)
            }
        }
    }
}
