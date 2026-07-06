import CoreLocation
import MapLibre
import UIKit

/// AIS vessel positions + COG/SOG course vectors (Digitraffic).
enum MapAisOverlay {
    static let pointSourceID = "veneappi_ais_point_source"
    static let pointLayerID = "veneappi_ais_point_layer"
    static let vectorSourceID = "veneappi_ais_vector_source"
    static let vectorLayerID = "veneappi_ais_vector_layer"

    private static let vesselFill = UIColor(red: 0.0, green: 0.48, blue: 0.95, alpha: 1)
    private static let vesselStroke = UIColor.white
    private static let vectorColor = UIColor(red: 0.25, green: 0.72, blue: 1.0, alpha: 0.95)
    private static let pointRadius: CGFloat = 9

    static func update(vessels: [AisVesselDisplay], enabled: Bool, on style: MLNStyle) {
        if !enabled || vessels.isEmpty {
            remove(from: style)
            return
        }

        let capped = Array(vessels.prefix(AppConfig.aisMaxVesselsOnMap))
        updateVectors(vessels: capped, on: style)
        updatePoints(vessels: capped, on: style)
    }

    /// Rebuild point source each update — `shape =` alone does not always repaint on MapLibre iOS.
    private static func updatePoints(vessels: [AisVesselDisplay], on style: MLNStyle) {
        let features: [MLNPointFeature] = vessels.compactMap { vessel in
            guard let coord = AisVesselMotion.displayCoordinate(vessel: vessel) else { return nil }
            let feature = MLNPointFeature()
            feature.coordinate = coord
            return feature
        }
        guard !features.isEmpty else {
            removePoints(from: style)
            return
        }

        removePoints(from: style)
        let collection = MLNShapeCollectionFeature(shapes: features)
        let source = MLNShapeSource(identifier: pointSourceID, shape: collection, options: nil)
        style.addSource(source)
        ensurePointLayer(on: style)
    }

    private static func updateVectors(vessels: [AisVesselDisplay], on style: MLNStyle) {
        var lines: [MLNPolylineFeature] = []
        lines.reserveCapacity(vessels.count)
        for vessel in vessels {
            guard let start = AisVesselMotion.displayCoordinate(vessel: vessel),
                  let endPair = AisVesselMotion.courseVectorEndAt(vessel: vessel),
                  endPair.latitude.isFinite, endPair.longitude.isFinite else { continue }
            let end = CLLocationCoordinate2D(latitude: endPair.latitude, longitude: endPair.longitude)
            let coords = [start, end]
            lines.append(MLNPolylineFeature(coordinates: coords, count: UInt(coords.count)))
        }

        removeVectors(from: style)
        guard !lines.isEmpty else { return }

        let collection = MLNShapeCollectionFeature(shapes: lines)
        let source = MLNShapeSource(identifier: vectorSourceID, shape: collection, options: nil)
        style.addSource(source)
        ensureVectorLayer(on: style)
    }

    private static func ensureVectorLayer(on style: MLNStyle) {
        if style.layer(withIdentifier: vectorLayerID) != nil { return }
        guard let source = style.source(withIdentifier: vectorSourceID) else { return }

        let layer = MLNLineStyleLayer(identifier: vectorLayerID, source: source)
        layer.lineColor = NSExpression(forConstantValue: vectorColor)
        layer.lineWidth = NSExpression(forConstantValue: 4)
        layer.lineOpacity = NSExpression(forConstantValue: 0.92)
        layer.lineCap = NSExpression(forConstantValue: "round")

        insertBelowForecastPin(layer, on: style)
    }

    private static func ensurePointLayer(on style: MLNStyle) {
        if style.layer(withIdentifier: pointLayerID) != nil { return }
        guard let source = style.source(withIdentifier: pointSourceID) else { return }

        let layer = MLNCircleStyleLayer(identifier: pointLayerID, source: source)
        layer.circleRadius = NSExpression(forConstantValue: pointRadius)
        layer.circleColor = NSExpression(forConstantValue: vesselFill)
        layer.circleOpacity = NSExpression(forConstantValue: 1)
        layer.circleStrokeColor = NSExpression(forConstantValue: vesselStroke)
        layer.circleStrokeWidth = NSExpression(forConstantValue: 2.5)

        if let vector = style.layer(withIdentifier: vectorLayerID) {
            style.insertLayer(layer, above: vector)
        } else {
            insertBelowForecastPin(layer, on: style)
        }
    }

    private static func insertBelowForecastPin(_ layer: MLNStyleLayer, on style: MLNStyle) {
        if let pin = style.layer(withIdentifier: MapForecastPin.layerID) {
            style.insertLayer(layer, below: pin)
        } else if let traficom = style.layer(withIdentifier: MapTraficomOverlay.layerID) {
            style.insertLayer(layer, above: traficom)
        } else {
            style.addLayer(layer)
        }
    }

    static func remove(from style: MLNStyle) {
        removePoints(from: style)
        removeVectors(from: style)
    }

    private static func removePoints(from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: pointLayerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: pointSourceID) {
            style.removeSource(source)
        }
    }

    private static func removeVectors(from style: MLNStyle) {
        if let layer = style.layer(withIdentifier: vectorLayerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: vectorSourceID) {
            style.removeSource(source)
        }
    }
}
