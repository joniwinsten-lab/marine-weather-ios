import MapLibre

enum MapTraficomOverlay {
    static let sourceID = "veneappi_traficom_nautical"
    static let layerID = "veneappi_traficom_nautical_layer"

    private static var installedURLTemplate: String?

    static func setEnabled(_ enabled: Bool, on style: MLNStyle) {
        let present = style.layer(withIdentifier: layerID) != nil
        if enabled {
            let needsRefresh = present && !TraficomNauticalConfig.isCurrentSource(installedURLTemplate)
            if needsRefresh {
                removeLayer(from: style)
            }
            if style.source(withIdentifier: sourceID) == nil {
                addLayer(to: style)
            }
        } else if present {
            removeLayer(from: style)
        }
    }

    private static func addLayer(to style: MLNStyle) {
        guard style.source(withIdentifier: sourceID) == nil else { return }
        let bounds = MLNCoordinateBounds(
            sw: TraficomNauticalConfig.boundsSW,
            ne: TraficomNauticalConfig.boundsNE
        )
        let source = MLNRasterTileSource(
            identifier: sourceID,
            tileURLTemplates: [TraficomNauticalConfig.tileURLTemplate],
            options: [
                .minimumZoomLevel: NSNumber(value: TraficomNauticalConfig.minimumZoom),
                .maximumZoomLevel: NSNumber(value: TraficomNauticalConfig.maximumZoom),
                .tileSize: NSNumber(value: 256),
                .coordinateBounds: NSValue(mlnCoordinateBounds: bounds),
            ]
        )
        style.addSource(source)
        let layer = MLNRasterStyleLayer(identifier: layerID, source: source)
        style.addLayer(layer)
        installedURLTemplate = TraficomNauticalConfig.tileURLTemplate
    }

    private static func removeLayer(from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: layerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: sourceID) {
            style.removeSource(source)
        }
        installedURLTemplate = nil
    }
}
