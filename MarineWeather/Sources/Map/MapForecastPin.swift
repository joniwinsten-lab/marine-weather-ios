import CoreLocation
import MapLibre
import UIKit

/// Forecast location pin (Android `updatePin` — red circle with white stroke).
enum MapForecastPin {
    static let sourceID = "veneappi_pin_source"
    static let layerID = "veneappi_pin_layer"

    private static let fillColor = UIColor(red: 0.827, green: 0.184, blue: 0.184, alpha: 1) // #D32F2F

    static func update(coordinate: CLLocationCoordinate2D, on style: MLNStyle) {
        let feature = MLNPointFeature()
        feature.coordinate = coordinate

        if let source = style.source(withIdentifier: sourceID) as? MLNShapeSource {
            source.shape = feature
            return
        }

        let source = MLNShapeSource(identifier: sourceID, shape: feature, options: nil)
        style.addSource(source)

        let layer = MLNCircleStyleLayer(identifier: layerID, source: source)
        layer.circleRadius = NSExpression(forConstantValue: 7)
        layer.circleColor = NSExpression(forConstantValue: fillColor)
        layer.circleStrokeColor = NSExpression(forConstantValue: UIColor.white)
        layer.circleStrokeWidth = NSExpression(forConstantValue: 2)

        if let traficomLayer = style.layer(withIdentifier: MapTraficomOverlay.layerID) {
            style.insertLayer(layer, above: traficomLayer)
        } else {
            style.addLayer(layer)
        }
    }
}
