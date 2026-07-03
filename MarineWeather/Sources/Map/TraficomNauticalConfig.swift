import CoreLocation
import Foundation

/// Traficom open WMTS nautical planning charts (Android `TraficomNauticalConfig.kt`).
enum TraficomNauticalConfig {
    /// National mosaic — regional series A–T are selected automatically when panning.
    static let tileURLTemplate =
        "https://julkinen.traficom.fi/rasteripalvelu/wmts/rest/" +
        "Traficom:Merikarttasarjat%20public/default/WGS84_Pseudo-Mercator/" +
        "WGS84_Pseudo-Mercator:{z}/{y}/{x}?format=image/png"

    static let minimumZoom: Double = 5
    /// Service returns HTTP 400 above zoom 15 for the mosaic layer.
    static let maximumZoom: Double = 15

    /// WGS84 bounds: minLon, minLat, maxLon, maxLat (Finnish coastal waters).
    static let boundsSW = CLLocationCoordinate2D(latitude: 58, longitude: 17)
    static let boundsNE = CLLocationCoordinate2D(latitude: 71, longitude: 32)

    static func isCurrentSource(_ urlTemplate: String?) -> Bool {
        guard let urlTemplate, !urlTemplate.isEmpty else { return false }
        return urlTemplate.contains("Merikarttasarjat%20public")
            || urlTemplate.contains("Merikarttasarjat public")
    }
}
