import Foundation

enum RadarSourceId: String, Codable {
    case fmi = "FMI"
    case metNordic = "MET_NORDIC"
    case smhi = "SMHI"
}

enum RadarDisplayKind: String, Codable {
    case wmsTiles = "WMS_TILES"
    case geoImage = "GEO_IMAGE"
}

struct RadarGeoBounds: Equatable {
    let northLat: Double
    let westLon: Double
    let southLat: Double
    let eastLon: Double
}

struct RadarAnimationFrame: Equatable, Identifiable {
    var id: String { timeIso }
    let sourceId: RadarSourceId
    let kind: RadarDisplayKind
    let timeIso: String
    let timeLabel: String
    let offsetMinutesFromNow: Int
    let wmsTileUrlTemplate: String?
    let geoImageUrl: String?
    let geoBounds: RadarGeoBounds?
}

struct ActiveRadarOverlay: Equatable {
    let sourceId: RadarSourceId
    let kind: RadarDisplayKind
    let sourceLabel: String
    let timeLabel: String
    let wmsTileUrlTemplate: String?
    let geoImageUrl: String?
    let geoBounds: RadarGeoBounds?
}

enum RadarFrameRole {
    case observation
    case now
    case forecast
}
