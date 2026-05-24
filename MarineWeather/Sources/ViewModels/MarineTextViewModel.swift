import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class MarineTextViewModel {
    private(set) var overview: MarineTextOverview?
    private(set) var loading = false

    private let repository = MarineTextRepository()
    private var loadTask: Task<Void, Never>?

    func load(latitude: Double, longitude: Double) {
        loadTask?.cancel()
        loadTask = Task {
            loading = true
            let titles: [String: String] = [
                "NO": String(localized: "marine_text_country_no"),
                "SE": String(localized: "marine_text_country_se"),
                "FI": String(localized: "marine_text_country_fi"),
                "EE": String(localized: "marine_text_country_ee"),
            ]
            let result = await repository.loadOverview(
                lat: latitude,
                lon: longitude,
                titlesByCountry: titles
            )
            guard !Task.isCancelled else { return }
            overview = result
            loading = false
        }
    }

    func refresh(latitude: Double, longitude: Double) {
        load(latitude: latitude, longitude: longitude)
    }
}
