import Foundation

/// AIS data source indicator for the map chip.
enum AisStreamMode: Equatable {
    case off
    case connecting
    case restOnly
    case live
    case error
}
