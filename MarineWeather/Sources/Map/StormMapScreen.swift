import CoreLocation
import MapLibre
import SwiftUI

enum StormMapConstants {
    static let defaultZoom: Double = 5.5
    static let minimumZoom: Double = 4.5
}

/// Map for storm radar tab — wider zoom, radar WMS + lightning (Android `MapPane` isStormMap).
struct StormMapScreen: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var radarOverlay: ActiveRadarOverlay?
    var lightningStrikes: [LightningStrike]
    var controller: MapScreenController
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onLongPress: onLongPress)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.styleURL = AppConfig.mapStyleURL
        mapView.setCenter(center, zoomLevel: StormMapConstants.defaultZoom, animated: false)
        mapView.minimumZoomLevel = StormMapConstants.minimumZoom
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
        context.coordinator.radarOverlay = radarOverlay
        context.coordinator.lightningStrikes = lightningStrikes
        controller.mapView = mapView

        let deltaLat = abs(mapView.centerCoordinate.latitude - center.latitude)
        let deltaLon = abs(mapView.centerCoordinate.longitude - center.longitude)
        if deltaLat > 0.05 || deltaLon > 0.05 {
            mapView.setCenter(center, zoomLevel: mapView.zoomLevel, animated: true)
        }

        if let style = mapView.style {
            MapTraficomOverlay.setEnabled(false, on: style)
            MapStormOverlay.updateRadar(radarOverlay, on: style)
            MapStormOverlay.updateLightning(lightningStrikes, on: style)
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        let controller: MapScreenController
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?
        var radarOverlay: ActiveRadarOverlay?
        var lightningStrikes: [LightningStrike] = []
        weak var mapView: MLNMapView?

        init(controller: MapScreenController, onLongPress: ((CLLocationCoordinate2D) -> Void)?) {
            self.controller = controller
            self.onLongPress = onLongPress
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            MapTraficomOverlay.setEnabled(false, on: style)
            MapStormOverlay.updateRadar(radarOverlay, on: style)
            MapStormOverlay.updateLightning(lightningStrikes, on: style)
        }
    }
}

extension StormMapScreen.Coordinator {
    @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let mapView = recognizer.view as? MLNMapView else { return }
        let point = recognizer.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        onLongPress?(coordinate)
    }
}
