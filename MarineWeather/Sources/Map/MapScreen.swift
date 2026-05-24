import CoreLocation
import MapLibre
import SwiftUI

/// Controls an embedded `MapScreen` (zoom) from SwiftUI overlays.
@MainActor
final class MapScreenController {
    fileprivate weak var mapView: MLNMapView?

    func zoomIn() {
        guard let mapView else { return }
        mapView.setZoomLevel(min(mapView.zoomLevel + 1, 18), animated: true)
    }

    func zoomOut() {
        guard let mapView else { return }
        mapView.setZoomLevel(max(mapView.zoomLevel - 1, 4), animated: true)
    }
}

/// MapLibre map using OpenFreeMap Liberty (Android `MapPane` / `MapConfig`).
struct MapScreen: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var zoom: Double
    var traficomEnabled: Bool
    var controller: MapScreenController
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onLongPress: onLongPress)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.styleURL = AppConfig.mapStyleURL
        mapView.setCenter(center, zoomLevel: zoom, animated: false)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        mapView.delegate = context.coordinator

        context.coordinator.mapView = mapView
        controller.mapView = mapView

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        mapView.addGestureRecognizer(recognizer)

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.traficomEnabled = traficomEnabled
        context.coordinator.forecastCenter = center
        controller.mapView = mapView

        let deltaLat = abs(mapView.centerCoordinate.latitude - center.latitude)
        let deltaLon = abs(mapView.centerCoordinate.longitude - center.longitude)
        if deltaLat > 0.0001 || deltaLon > 0.0001 {
            mapView.setCenter(center, zoomLevel: mapView.zoomLevel, animated: true)
        }

        if let style = mapView.style {
            MapTraficomOverlay.setEnabled(traficomEnabled, on: style)
            MapForecastPin.update(coordinate: center, on: style)
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        let controller: MapScreenController
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?
        var traficomEnabled: Bool
        var forecastCenter: CLLocationCoordinate2D?
        weak var mapView: MLNMapView?

        init(controller: MapScreenController, onLongPress: ((CLLocationCoordinate2D) -> Void)?) {
            self.controller = controller
            self.onLongPress = onLongPress
            self.traficomEnabled = false
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            MapTraficomOverlay.setEnabled(traficomEnabled, on: style)
            if let forecastCenter {
                MapForecastPin.update(coordinate: forecastCenter, on: style)
            }
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view as? MLNMapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onLongPress?(coordinate)
        }
    }
}
