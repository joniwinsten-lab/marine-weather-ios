import Foundation

typealias RouteCoordinate = (lat: Double, lon: Double)

/// Wind samples along a route leg (departure / 33% / 66% / arrival).
struct RouteSourceWeatherSlots: Equatable {
    let slots: [UnifiedTimePoint?]
    let fetchedAtUtc: Int64
    let modelInfo: String?
}

struct RouteSourceWeatherState: Equatable {
    var slots: RouteSourceWeatherSlots?
    var errorMessage: String?
    var loading: Bool

    static let idle = RouteSourceWeatherState(slots: nil, errorMessage: nil, loading: false)
}
