import CoreLocation
import MapLibre
import UIKit

/// Storm radar WMS tiles + lightning strike layers (Android `MapPane` storm/lightning).
enum MapStormOverlay {
    static let radarSourceA = "veneappi_storm_radar_tile_a"
    static let radarLayerA = "veneappi_storm_radar_tile_layer_a"
    static let radarSourceB = "veneappi_storm_radar_tile_b"
    static let radarLayerB = "veneappi_storm_radar_tile_layer_b"
    static let geoImageSourceID = "veneappi_storm_radar_image"
    static let geoImageLayerID = "veneappi_storm_radar_image_layer"
    static let lightningFmiSourceID = "veneappi_lightning_fmi"
    static let lightningSmhiSourceID = "veneappi_lightning_smhi"
    static let lightningFmiLayerID = "veneappi_lightning_fmi"
    static let lightningSmhiLayerID = "veneappi_lightning_smhi"

    private static let radarOpacity: NSNumber = 0.75
    private static let maxLightningFeatures = 1_000
    private static let minRadarSwapInterval: TimeInterval = 0.45
    private static let minLightningUpdateInterval: TimeInterval = 0.35

    private static weak var mapView: MLNMapView?
    private static var activeRadarSlot: RadarSlot = .a
    private static var displayedRadarURL: String?
    private static var displayedGeoImageURL: String?
    private static var pendingRadarURL: String?
    private static var pendingRadarWork: DispatchWorkItem?
    private static var pendingLightningWork: DispatchWorkItem?
    private static var lastRadarSwapTime: TimeInterval = 0
    private static var lastLightningUpdateTime: TimeInterval = 0
    private static var lastLightningSignature: Int?
    private static var styleReady = false
    private static var radarInstalled = false

    static func attach(mapView: MLNMapView) {
        self.mapView = mapView
    }

    static func detach() {
        mapView = nil
        styleReady = false
        radarInstalled = false
        displayedRadarURL = nil
        displayedGeoImageURL = nil
        pendingRadarURL = nil
        pendingRadarWork?.cancel()
        pendingRadarWork = nil
        pendingLightningWork?.cancel()
        pendingLightningWork = nil
        lastLightningSignature = nil
    }

    static func setStyleReady(_ ready: Bool) {
        styleReady = ready
        if !ready {
            displayedRadarURL = nil
            displayedGeoImageURL = nil
            pendingRadarURL = nil
            radarInstalled = false
            pendingRadarWork?.cancel()
            pendingRadarWork = nil
        }
    }

    static func updateRadar(_ overlay: ActiveRadarOverlay?, on style: MLNStyle) {
        guard styleReady else { return }

        guard let overlay else {
            pendingRadarURL = nil
            pendingRadarWork?.cancel()
            pendingRadarWork = nil
            removeAllRadar(from: style)
            removeGeoRadar(from: style)
            return
        }

        switch overlay.kind {
        case .wmsTiles:
            removeGeoRadar(from: style)
            updateWmsRadar(overlay, on: style)
        case .geoImage:
            pendingRadarURL = nil
            pendingRadarWork?.cancel()
            pendingRadarWork = nil
            removeAllRadar(from: style)
            updateGeoRadar(overlay, on: style)
        }
    }

    private static func updateWmsRadar(_ overlay: ActiveRadarOverlay, on style: MLNStyle) {
        guard let url = overlay.wmsTileUrlTemplate else {
            removeAllRadar(from: style)
            return
        }

        if displayedRadarURL == url, radarLayer(on: style, slot: activeRadarSlot) != nil {
            return
        }

        pendingRadarURL = url
        scheduleRadarSwap()
    }

    private static func updateGeoRadar(_ overlay: ActiveRadarOverlay, on style: MLNStyle) {
        guard let imageURLString = overlay.geoImageUrl,
              let bounds = overlay.geoBounds,
              let image = loadGeoImage(imageURLString) else {
            removeGeoRadar(from: style)
            return
        }

        if displayedGeoImageURL == imageURLString,
           let source = style.source(withIdentifier: geoImageSourceID) as? MLNImageSource {
            source.image = image
            return
        }

        removeGeoRadar(from: style)
        let quad = coordinateQuad(bounds: bounds)
        let source = MLNImageSource(identifier: geoImageSourceID, coordinateQuad: quad, image: image)
        style.addSource(source)

        let layer = MLNRasterStyleLayer(identifier: geoImageLayerID, source: source)
        layer.rasterOpacity = NSExpression(forConstantValue: radarOpacity)
        insertRadarLayer(layer, on: style)
        displayedGeoImageURL = imageURLString
        displayedRadarURL = nil
    }

    static func updateLightning(_ strikes: [LightningStrike], on style: MLNStyle) {
        guard styleReady else { return }

        let signature = lightningSignature(strikes)
        if signature == lastLightningSignature { return }

        pendingLightningWork?.cancel()
        let work = DispatchWorkItem { [strikes, signature] in
            guard let style = mapView?.style else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = now - lastLightningUpdateTime
            if elapsed < minLightningUpdateInterval {
                let delay = minLightningUpdateInterval - elapsed
                pendingLightningWork?.cancel()
                let retry = DispatchWorkItem {
                    applyLightning(strikes, signature: signature, on: style)
                }
                pendingLightningWork = retry
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: retry)
                return
            }
            applyLightning(strikes, signature: signature, on: style)
        }
        pendingLightningWork = work
        DispatchQueue.main.async(execute: work)
    }

    static func removeAll(from style: MLNStyle) {
        pendingRadarWork?.cancel()
        pendingRadarWork = nil
        pendingLightningWork?.cancel()
        pendingLightningWork = nil
        displayedRadarURL = nil
        displayedGeoImageURL = nil
        pendingRadarURL = nil
        radarInstalled = false
        removeAllRadar(from: style)
        removeGeoRadar(from: style)
        removeLightningSource(sourceID: lightningFmiSourceID, layerID: lightningFmiLayerID, from: style)
        removeLightningSource(sourceID: lightningSmhiSourceID, layerID: lightningSmhiLayerID, from: style)
        lastLightningSignature = nil
    }

    // MARK: - Private

    private enum RadarSlot {
        case a, b

        var sourceID: String {
            switch self {
            case .a: MapStormOverlay.radarSourceA
            case .b: MapStormOverlay.radarSourceB
            }
        }

        var layerID: String {
            switch self {
            case .a: MapStormOverlay.radarLayerA
            case .b: MapStormOverlay.radarLayerB
            }
        }

        var opposite: RadarSlot {
            switch self {
            case .a: .b
            case .b: .a
            }
        }
    }

    private static func scheduleRadarSwap() {
        guard let url = pendingRadarURL else { return }

        if displayedRadarURL == url, radarLayer(on: mapView?.style, slot: activeRadarSlot) != nil {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastRadarSwapTime
        pendingRadarWork?.cancel()

        let work = DispatchWorkItem {
            guard let style = mapView?.style, let targetURL = pendingRadarURL else { return }
            performRadarSwap(url: targetURL, on: style)
        }
        pendingRadarWork = work

        if elapsed < minRadarSwapInterval, radarInstalled {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + (minRadarSwapInterval - elapsed),
                execute: work
            )
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private static func performRadarSwap(url: String, on style: MLNStyle) {
        guard styleReady, pendingRadarURL == url else { return }
        if displayedRadarURL == url, radarLayer(on: style, slot: activeRadarSlot) != nil {
            return
        }

        let incoming = activeRadarSlot.opposite
        removeRadarSlot(incoming, from: style)

        let source = MLNRasterTileSource(
            identifier: incoming.sourceID,
            tileURLTemplates: [url],
            options: [
                .minimumZoomLevel: 3,
                .maximumZoomLevel: 14,
                .tileSize: NSNumber(value: FmiRadarConfig.tileSize),
            ]
        )
        style.addSource(source)

        let layer = MLNRasterStyleLayer(identifier: incoming.layerID, source: source)
        layer.rasterOpacity = NSExpression(forConstantValue: radarOpacity)
        insertRadarLayer(layer, on: style)

        let previous = activeRadarSlot
        activeRadarSlot = incoming
        displayedRadarURL = url
        lastRadarSwapTime = ProcessInfo.processInfo.systemUptime
        radarInstalled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard mapView?.style === style, activeRadarSlot == incoming else { return }
            removeRadarSlot(previous, from: style)
        }
    }

    private static func applyLightning(
        _ strikes: [LightningStrike],
        signature: Int,
        on style: MLNStyle
    ) {
        lastLightningUpdateTime = ProcessInfo.processInfo.systemUptime
        lastLightningSignature = signature

        let capped = Array(strikes.prefix(maxLightningFeatures))
        var fmi: [LightningStrike] = []
        var smhi: [LightningStrike] = []
        fmi.reserveCapacity(min(capped.count, maxLightningFeatures))
        smhi.reserveCapacity(min(capped.count, maxLightningFeatures))
        for strike in capped {
            switch strike.source {
            case .fmi: fmi.append(strike)
            case .smhi: smhi.append(strike)
            }
        }

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

    private static func lightningSignature(_ strikes: [LightningStrike]) -> Int {
        var hasher = Hasher()
        hasher.combine(strikes.count)
        if let first = strikes.first {
            hasher.combine(first.observedAtEpochMs)
        }
        if let last = strikes.last {
            hasher.combine(last.observedAtEpochMs)
        }
        return hasher.finalize()
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

        let features: [MLNPointFeature] = strikes.map { strike in
            let feature = MLNPointFeature()
            feature.coordinate = CLLocationCoordinate2D(
                latitude: strike.latitude,
                longitude: strike.longitude
            )
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

        let anchor = style.layer(withIdentifier: geoImageLayerID)
            ?? radarLayer(on: style, slot: activeRadarSlot)
            ?? radarLayer(on: style, slot: activeRadarSlot.opposite)
            ?? style.layer(withIdentifier: MapTraficomOverlay.layerID)
        if let anchor {
            style.insertLayer(layer, above: anchor)
        } else {
            style.addLayer(layer)
        }
    }

    private static func insertRadarLayer(_ layer: MLNRasterStyleLayer, on style: MLNStyle) {
        if let traficom = style.layer(withIdentifier: MapTraficomOverlay.layerID) {
            style.insertLayer(layer, above: traficom)
        } else {
            style.addLayer(layer)
        }
    }

    private static func radarLayer(on style: MLNStyle?, slot: RadarSlot) -> MLNRasterStyleLayer? {
        style?.layer(withIdentifier: slot.layerID) as? MLNRasterStyleLayer
    }

    private static func removeRadarSlot(_ slot: RadarSlot, from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: slot.layerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: slot.sourceID) {
            style.removeSource(source)
        }
    }

    private static func removeAllRadar(from style: MLNStyle) {
        removeRadarSlot(.a, from: style)
        removeRadarSlot(.b, from: style)
        activeRadarSlot = .a
        displayedRadarURL = nil
        radarInstalled = false
    }

    private static func removeGeoRadar(from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: geoImageLayerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: geoImageSourceID) {
            style.removeSource(source)
        }
        displayedGeoImageURL = nil
    }

    private static func coordinateQuad(bounds: RadarGeoBounds) -> MLNCoordinateQuad {
        MLNCoordinateQuad(
            topLeft: CLLocationCoordinate2D(latitude: bounds.northLat, longitude: bounds.westLon),
            bottomLeft: CLLocationCoordinate2D(latitude: bounds.southLat, longitude: bounds.westLon),
            bottomRight: CLLocationCoordinate2D(latitude: bounds.southLat, longitude: bounds.eastLon),
            topRight: CLLocationCoordinate2D(latitude: bounds.northLat, longitude: bounds.eastLon)
        )
    }

    private static func loadGeoImage(_ pathOrURL: String) -> UIImage? {
        let fileURL: URL
        if pathOrURL.hasPrefix("/") {
            fileURL = URL(fileURLWithPath: pathOrURL)
        } else if let url = URL(string: pathOrURL) {
            fileURL = url
        } else {
            return nil
        }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private static func removeLightningSource(sourceID: String, layerID: String, from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: layerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: sourceID) {
            style.removeSource(source)
        }
    }
}
