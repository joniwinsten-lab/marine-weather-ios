import MapLibre
import UIKit

/// Storm radar WMS tiles + lightning strike layers (Android `MapPane` storm/lightning).
enum MapStormOverlay {
    static let radarSourceID = "veneappi_storm_radar_tile"
    static let radarLayerID = "veneappi_storm_radar_tile_layer"
    static let lightningSourceID = "veneappi_lightning"
    static let lightningFmiLayerID = "veneappi_lightning_fmi"
    static let lightningSmhiLayerID = "veneappi_lightning_smhi"

    private static let radarOpacity: NSNumber = 0.75
    private static var lastRadarTileURL: String?

    static func updateRadar(_ overlay: ActiveRadarOverlay?, on style: MLNStyle) {
        guard let overlay, overlay.kind == .wmsTiles, let url = overlay.wmsTileUrlTemplate else {
            removeRadar(from: style)
            lastRadarTileURL = nil
            return
        }

        if lastRadarTileURL == url, style.layer(withIdentifier: radarLayerID) != nil {
            return
        }

        removeRadar(from: style)
        lastRadarTileURL = url

        let source = MLNRasterTileSource(
            identifier: radarSourceID,
            tileURLTemplates: [url],
            options: [
                .minimumZoomLevel: 3,
                .maximumZoomLevel: 14,
                .tileSize: NSNumber(value: FmiRadarConfig.tileSize),
            ]
        )
        style.addSource(source)
        let layer = MLNRasterStyleLayer(identifier: radarLayerID, source: source)
        layer.rasterOpacity = NSExpression(forConstantValue: radarOpacity)
        if let traficom = style.layer(withIdentifier: MapTraficomOverlay.layerID) {
            style.insertLayer(layer, above: traficom)
        } else {
            style.addLayer(layer)
        }
    }

    static func updateLightning(_ strikes: [LightningStrike], on style: MLNStyle) {
        if strikes.isEmpty {
            removeLightning(from: style)
            return
        }

        let features = strikes.map { strike -> MLNPointFeature in
            let feature = MLNPointFeature()
            feature.coordinate = CLLocationCoordinate2D(latitude: strike.latitude, longitude: strike.longitude)
            feature.attributes = ["source": strike.source.rawValue]
            return feature
        }

        if let source = style.source(withIdentifier: lightningSourceID) as? MLNShapeSource {
            source.shape = MLNShapeCollectionFeature(shapes: features)
            return
        }

        removeLightning(from: style)
        let source = MLNShapeSource(identifier: lightningSourceID, shape: MLNShapeCollectionFeature(shapes: features), options: nil)
        style.addSource(source)

        let anchor = style.layer(withIdentifier: radarLayerID)
            ?? style.layer(withIdentifier: MapTraficomOverlay.layerID)

        let fmiLayer = MLNCircleStyleLayer(identifier: lightningFmiLayerID, source: source)
        fmiLayer.predicate = NSPredicate(format: "source == %@", LightningSourceId.fmi.rawValue)
        fmiLayer.circleRadius = NSExpression(forConstantValue: 7)
        fmiLayer.circleColor = NSExpression(forConstantValue: UIColor(red: 1, green: 0.92, blue: 0.23, alpha: 1))
        fmiLayer.circleOpacity = NSExpression(forConstantValue: 0.92)
        fmiLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
        fmiLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)

        let smhiLayer = MLNCircleStyleLayer(identifier: lightningSmhiLayerID, source: source)
        smhiLayer.predicate = NSPredicate(format: "source == %@", LightningSourceId.smhi.rawValue)
        smhiLayer.circleRadius = NSExpression(forConstantValue: 7)
        smhiLayer.circleColor = NSExpression(forConstantValue: UIColor(red: 1, green: 0.6, blue: 0, alpha: 1))
        smhiLayer.circleOpacity = NSExpression(forConstantValue: 0.92)
        smhiLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
        smhiLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)

        if let anchor {
            style.insertLayer(fmiLayer, above: anchor)
            style.insertLayer(smhiLayer, above: fmiLayer)
        } else {
            style.addLayer(fmiLayer)
            style.addLayer(smhiLayer)
        }
    }

    private static func removeRadar(from style: MLNStyle) {
        lastRadarTileURL = nil
        if let layer = style.layer(withIdentifier: radarLayerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: radarSourceID) {
            style.removeSource(source)
        }
    }

    private static func removeLightning(from style: MLNStyle) {
        for id in [lightningSmhiLayerID, lightningFmiLayerID] {
            if let layer = style.layer(withIdentifier: id) {
                style.removeLayer(layer)
            }
        }
        if let source = style.source(withIdentifier: lightningSourceID) {
            style.removeSource(source)
        }
    }
}

import CoreLocation
