import Foundation

/// FMI OpenWMS radar reflectivity (Android `FmiRadarConfig.kt`).
enum FmiRadarConfig {
    static let tileSize = 512

    static let wmsTileURLTemplate =
        "https://openwms.fmi.fi/geoserver/wms?" +
        "service=WMS&version=1.3.0&request=GetMap" +
        "&layers=Radar:suomi_dbz_eureffin&styles=&format=image/png&transparent=true" +
        "&crs=EPSG:3857&bbox={bbox-epsg-3857}&width=\(tileSize)&height=\(tileSize)"

    /// lon min, lat min, lon max, lat max
    static let tileBounds = (18.0, 55.0, 34.0, 72.0)
}
