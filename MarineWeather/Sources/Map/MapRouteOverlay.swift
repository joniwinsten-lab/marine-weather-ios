import CoreLocation
import MapLibre
import UIKit

/// Route polyline and start/end markers (Android `updateRoute` / `updateRouteMarkers`).
enum MapRouteOverlay {
    static let routeSourceID = "veneappi_route_source"
    static let routeLayerID = "veneappi_route_layer"
    static let startSourceID = "veneappi_route_start_pt"
    static let startLayerID = "veneappi_route_start_layer"
    static let endSourceID = "veneappi_route_end_pt"
    static let endLayerID = "veneappi_route_end_layer"
    static let slotsSourceID = "veneappi_route_weather_slots"
    static let slotsLayerID = "veneappi_route_weather_slots_layer"

    private static let routeColor = UIColor(red: 1.0, green: 0.427, blue: 0.0, alpha: 1) // #FF6D00 — Android route line
    private static let startColor = UIColor(red: 0.298, green: 0.686, blue: 0.314, alpha: 1)
    private static let endColor = UIColor(red: 0.827, green: 0.184, blue: 0.184, alpha: 1)

    static func update(
        geometry: [RouteCoordinate],
        start: RouteCoordinate?,
        end: RouteCoordinate?,
        on style: MLNStyle
    ) {
        updateRouteLine(geometry: geometry, on: style)
        updateMarker(
            coordinate: start,
            sourceID: startSourceID,
            layerID: startLayerID,
            color: startColor,
            on: style
        )
        updateMarker(
            coordinate: end,
            sourceID: endSourceID,
            layerID: endLayerID,
            color: endColor,
            on: style
        )
        updateSlotMarkers(geometry: geometry, on: style)
    }

    private static func updateRouteLine(geometry: [RouteCoordinate], on style: MLNStyle) {
        guard geometry.count >= 2 else {
            removeLayer(style, slotsLayerID, slotsSourceID)
            removeLayer(style, routeLayerID, routeSourceID)
            return
        }
        let coords = geometry.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let feature = MLNPolylineFeature(coordinates: coords, count: UInt(coords.count))
        if let source = style.source(withIdentifier: routeSourceID) as? MLNShapeSource {
            source.shape = feature
            return
        }
        removeLayer(style, slotsLayerID, slotsSourceID)
        removeLayer(style, routeLayerID, routeSourceID)
        let source = MLNShapeSource(identifier: routeSourceID, shape: feature, options: nil)
        style.addSource(source)
        let layer = MLNLineStyleLayer(identifier: routeLayerID, source: source)
        layer.lineColor = NSExpression(forConstantValue: routeColor)
        layer.lineWidth = NSExpression(forConstantValue: 6)
        layer.lineOpacity = NSExpression(forConstantValue: 1)
        layer.lineCap = NSExpression(forConstantValue: "round")
        layer.lineJoin = NSExpression(forConstantValue: "round")
        insertAboveTraficom(layer, on: style)
    }

    /// Small dots at ⅓ and ⅔ along the route (weather forecast sample positions).
    private static func updateSlotMarkers(geometry: [RouteCoordinate], on style: MLNStyle) {
        guard geometry.count >= 2, style.layer(withIdentifier: routeLayerID) != nil else {
            removeLayer(style, slotsLayerID, slotsSourceID)
            return
        }
        let pThird = GeoMath.pointAlongPolyline(geometry, fraction: 1.0 / 3.0)
        let pTwoThirds = GeoMath.pointAlongPolyline(geometry, fraction: 2.0 / 3.0)
        let features: [MLNPointFeature] = [pThird, pTwoThirds].map { pt in
            let f = MLNPointFeature()
            f.coordinate = CLLocationCoordinate2D(latitude: pt.lat, longitude: pt.lon)
            return f
        }
        let collection = MLNShapeCollectionFeature(shapes: features)
        if let source = style.source(withIdentifier: slotsSourceID) as? MLNShapeSource {
            source.shape = collection
            return
        }
        removeLayer(style, slotsLayerID, slotsSourceID)
        let source = MLNShapeSource(identifier: slotsSourceID, shape: collection, options: nil)
        style.addSource(source)
        let layer = MLNCircleStyleLayer(identifier: slotsLayerID, source: source)
        layer.circleRadius = NSExpression(forConstantValue: 5)
        layer.circleColor = NSExpression(forConstantValue: UIColor.white)
        layer.circleOpacity = NSExpression(forConstantValue: 0.95)
        layer.circleStrokeColor = NSExpression(forConstantValue: routeColor)
        layer.circleStrokeWidth = NSExpression(forConstantValue: 2)
        if let routeLayer = style.layer(withIdentifier: routeLayerID) {
            style.insertLayer(layer, above: routeLayer)
        } else {
            insertAboveTraficom(layer, on: style)
        }
    }

    private static func updateMarker(
        coordinate: RouteCoordinate?,
        sourceID: String,
        layerID: String,
        color: UIColor,
        on style: MLNStyle
    ) {
        guard let coordinate else {
            removeLayer(style, layerID, sourceID)
            return
        }
        let pt = MLNPointFeature()
        pt.coordinate = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lon)
        if let source = style.source(withIdentifier: sourceID) as? MLNShapeSource {
            source.shape = pt
            return
        }
        removeLayer(style, layerID, sourceID)
        let source = MLNShapeSource(identifier: sourceID, shape: pt, options: nil)
        style.addSource(source)
        let layer = MLNCircleStyleLayer(identifier: layerID, source: source)
        layer.circleRadius = NSExpression(forConstantValue: 8)
        layer.circleColor = NSExpression(forConstantValue: color)
        layer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
        layer.circleStrokeWidth = NSExpression(forConstantValue: 2)
        if let routeLayer = style.layer(withIdentifier: routeLayerID) {
            style.insertLayer(layer, above: routeLayer)
        } else {
            insertAboveTraficom(layer, on: style)
        }
    }

    private static func insertAboveTraficom(_ layer: MLNStyleLayer, on style: MLNStyle) {
        if let traficom = style.layer(withIdentifier: MapTraficomOverlay.layerID) {
            style.insertLayer(layer, above: traficom)
        } else {
            style.addLayer(layer)
        }
    }

    private static func removeLayer(_ style: MLNStyle, _ layerID: String, _ sourceID: String) {
        if let layer = style.layer(withIdentifier: layerID) {
            style.removeLayer(layer)
        }
        if let source = style.source(withIdentifier: sourceID) {
            style.removeSource(source)
        }
    }
}
