import MapLibre

enum MapTraficomOverlay {
    static let sourceID = "veneappi_traficom_nautical"
    static let layerID = "veneappi_traficom_nautical_layer"

    /// Traficom open WMTS — Merikarttasarja B (Android `MapPane.kt`).
    static let tileURLTemplate =
        "https://julkinen.traficom.fi/rasteripalvelu/wmts/rest/Traficom:Merikarttasarja%20B/default/WGS84_Pseudo-Mercator/WGS84_Pseudo-Mercator:{z}/{y}/{x}?format=image/png"

    static func setEnabled(_ enabled: Bool, on style: MLNStyle) {
        let present = style.layer(withIdentifier: layerID) != nil
        switch (enabled, present) {
        case (true, false):
            addLayer(to: style)
        case (false, true):
            removeLayer(from: style)
        default:
            break
        }
    }

    private static func addLayer(to style: MLNStyle) {
        guard style.source(withIdentifier: sourceID) == nil else { return }
        let source = MLNRasterTileSource(
            identifier: sourceID,
            tileURLTemplates: [tileURLTemplate],
            options: [
                .minimumZoomLevel: 5,
                .maximumZoomLevel: 18,
                .tileSize: 256,
            ]
        )
        style.addSource(source)
        let layer = MLNRasterStyleLayer(identifier: layerID, source: source)
        style.addLayer(layer)
    }

    private static func removeLayer(from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: layerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: sourceID) {
            style.removeSource(source)
        }
    }
}
