import CoreLocation
import MapLibre
import UIKit

/// Storm radar WMS tiles + lightning strike layers (Android `MapPane` storm/lightning).
enum MapStormOverlay {
    static let radarSourceID = "veneappi_storm_radar_tile"
    static let radarLayerID = "veneappi_storm_radar_tile_layer"
    static let lightningFmiSourceID = "veneappi_lightning_fmi"
    static let lightningSmhiSourceID = "veneappi_lightning_smhi"
    static let lightningFmiLayerID = "veneappi_lightning_fmi"
    static let lightningSmhiLayerID = "veneappi_lightning_smhi"

    private static let radarOpacity: NSNumber = 0.75
    private static let maxLightningFeatures = 2_500
    private static let minRadarSwapInterval: TimeInterval = 0.45

    private static var lastRadarTileURL: String?
    private static var lastRadarSwapTime: TimeInterval = 0
    private static var pendingRadarWork: DispatchWorkItem?
    private static var styleReady = false

    static func setStyleReady(_ ready: Bool) {
        styleReady = ready
        if !ready {
            lastRadarTileURL = nil
            pendingRadarWork?.cancel()
            pendingRadarWork = nil
        }
    }

    static func updateRadar(_ overlay: ActiveRadarOverlay?, on style: MLNStyle) {
        guard styleReady else { return }

        guard let overlay, overlay.kind == .wmsTiles, let url = overlay.wmsTileUrlTemplate else {
            pendingRadarWork?.cancel()
            pendingRadarWork = nil
            removeRadar(from: style)
            lastRadarTileURL = nil
            return
        }

        if lastRadarTileURL == url, style.layer(withIdentifier: radarLayerID) != nil {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastRadarSwapTime
        if elapsed < minRadarSwapInterval, style.layer(withIdentifier: radarLayerID) != nil {
            pendingRadarWork?.cancel()
            let work = DispatchWorkItem { [url] in
                applyRadar(url: url, on: style)
            }
            pendingRadarWork = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (minRadarSwapInterval - elapsed),
                execute: work
            )
            return
        }

        applyRadar(url: url, on: style)
    }

    static func updateLightning(_ strikes: [LightningStrike], on style: MLNStyle) {
        guard styleReady else { return }

        let capped = Array(strikes.prefix(maxLightningFeatures))
        let fmi = capped.filter { $0.source == .fmi }
        let smhi = capped.filter { $0.source == .smhi }

        updateLightningSource(
            sourceID: lightningFmiSourceID,
            layerID: lightningFmiLayerID,
            strikes: fmi,
            fillColor: UIColor(red: 1, green: 0.92, blue: 0.23, alpha: 1),
            on: style
        )
        updateLightningSource(
            sourceID: lightningSmhiSourceID,
            layerID: lightningSmhiLayerID,
            strikes: smhi,
            fillColor: UIColor(red: 1, green: 0.6, blue: 0, alpha: 1),
            on: style
        )
    }

    // MARK: - Private

    private static func applyRadar(url: String, on style: MLNStyle) {
        if lastRadarTileURL == url, style.layer(withIdentifier: radarLayerID) != nil {
            return
        }

        removeRadar(from: style)
        lastRadarTileURL = url
        lastRadarSwapTime = ProcessInfo.processInfo.systemUptime

        let source = MLNRasterTileSource(
            identifier: radarSourceID,
            tileURLTemplates: [url],
            options: [
                .minimumZoomLevel: 3,
                .maximumZoomLevel: 14,
                .tileSize: 256,
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

    private static func updateLightningSource(
        sourceID: String,
        layerID: String,
        strikes: [LightningStrike],
        fillColor: UIColor,
        on style: MLNStyle
    ) {
        if strikes.isEmpty {
            removeLightningSource(sourceID: sourceID, layerID: layerID, from: style)
            return
        }

        let features: [MLNShape & MLNFeature] = strikes.map { strike in
            let feature = MLNPointFeature()
            feature.coordinate = CLLocationCoordinate2D(latitude: strike.latitude, longitude: strike.longitude)
            return feature
        }
        let collection = MLNShapeCollectionFeature(shapes: features)

        if let source = style.source(withIdentifier: sourceID) as? MLNShapeSource {
            source.shape = collection
            ensureLightningLayer(layerID: layerID, sourceID: sourceID, fillColor: fillColor, on: style)
            return
        }

        removeLightningSource(sourceID: sourceID, layerID: layerID, from: style)
        let source = MLNShapeSource(identifier: sourceID, shape: collection, options: nil)
        style.addSource(source)
        ensureLightningLayer(layerID: layerID, sourceID: sourceID, fillColor: fillColor, on: style)
    }

    private static func ensureLightningLayer(
        layerID: String,
        sourceID: String,
        fillColor: UIColor,
        on style: MLNStyle
    ) {
        if style.layer(withIdentifier: layerID) != nil { return }

        guard let source = style.source(withIdentifier: sourceID) else { return }
        let layer = MLNCircleStyleLayer(identifier: layerID, source: source)
        layer.circleRadius = NSExpression(forConstantValue: 7)
        layer.circleColor = NSExpression(forConstantValue: fillColor)
        layer.circleOpacity = NSExpression(forConstantValue: 0.92)
        layer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
        layer.circleStrokeWidth = NSExpression(forConstantValue: 2)

        let anchor = style.layer(withIdentifier: radarLayerID)
            ?? style.layer(withIdentifier: MapTraficomOverlay.layerID)
        if let anchor {
            style.insertLayer(layer, above: anchor)
        } else {
            style.addLayer(layer)
        }
    }

    private static func removeRadar(from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: radarLayerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: radarSourceID) {
            style.removeSource(source)
        }
    }

    private static func removeLightningSource(sourceID: String, layerID: String, from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: layerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: sourceID) {
            style.removeSource(source)
        }
    }

    static func removeAll(from style: MLNStyle) {
        pendingRadarWork?.cancel()
        pendingRadarWork = nil
        lastRadarTileURL = nil
        removeRadar(from: style)
        removeLightningSource(sourceID: lightningFmiSourceID, layerID: lightningFmiLayerID, from: style)
        removeLightningSource(sourceID: lightningSmhiSourceID, layerID: lightningSmhiLayerID, from: style)
    }
}
