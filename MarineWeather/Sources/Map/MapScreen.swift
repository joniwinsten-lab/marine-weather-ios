import CoreLocation
import MapLibre
import SwiftUI

/// Controls an embedded `MapScreen` (zoom) from SwiftUI overlays.
@MainActor
final class MapScreenController {
    weak var mapView: MLNMapView?

    func zoomIn() {
        guard let mapView else { return }
        mapView.setZoomLevel(min(mapView.zoomLevel + 1, 18), animated: true)
    }

    func zoomOut() {
        guard let mapView else { return }
        mapView.setZoomLevel(max(mapView.zoomLevel - 1, 4), animated: true)
    }

    func fitRoute(geometry: [RouteCoordinate], padding: UIEdgeInsets = UIEdgeInsets(top: 48, left: 48, bottom: 48, right: 48)) {
        guard let mapView, geometry.count >= 2 else { return }
        var sw = CLLocationCoordinate2D(latitude: 90, longitude: 180)
        var ne = CLLocationCoordinate2D(latitude: -90, longitude: -180)
        for pt in geometry where pt.lat.isFinite && pt.lon.isFinite {
            sw.latitude = min(sw.latitude, pt.lat)
            sw.longitude = min(sw.longitude, pt.lon)
            ne.latitude = max(ne.latitude, pt.lat)
            ne.longitude = max(ne.longitude, pt.lon)
        }
        let bounds = MLNCoordinateBounds(sw: sw, ne: ne)
        mapView.setVisibleCoordinateBounds(bounds, edgePadding: padding, animated: true, completionHandler: nil)
    }
}

/// MapLibre map using OpenFreeMap Liberty (Android `MapPane` / `MapConfig`).
struct MapScreen: UIViewRepresentable {
    var center: CLLocationCoordinate2D
    var zoom: Double
    var traficomEnabled: Bool
    var controller: MapScreenController
    var routeGeometry: [RouteCoordinate] = []
    var routeStart: RouteCoordinate?
    var routeEnd: RouteCoordinate?
    var autoFitRoute = false
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?
    var onViewportChange: ((Double, Double) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onLongPress: onLongPress)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView.makeConfigured()
        mapView.setCenter(center, zoomLevel: zoom, animated: false)
        mapView.delegate = context.coordinator

        context.coordinator.mapView = mapView
        context.coordinator.lastAppliedCenter = center
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
        context.coordinator.onViewportChange = onViewportChange
        context.coordinator.traficomEnabled = traficomEnabled
        context.coordinator.forecastCenter = center
        context.coordinator.routeGeometry = routeGeometry
        context.coordinator.routeStart = routeStart
        context.coordinator.routeEnd = routeEnd
        controller.mapView = mapView

        if autoFitRoute, routeGeometry.count >= 2 {
            let signature = Self.routeGeometrySignature(routeGeometry)
            if signature != context.coordinator.lastFittedRouteSignature {
                context.coordinator.lastFittedRouteSignature = signature
                controller.fitRoute(geometry: routeGeometry)
                context.coordinator.lastAppliedCenter = mapView.centerCoordinate
            }
        } else if context.coordinator.centerChanged(from: context.coordinator.lastAppliedCenter, to: center) {
            mapView.setCenter(center, zoomLevel: mapView.zoomLevel, animated: true)
            context.coordinator.lastAppliedCenter = center
        }

        if let style = mapView.style {
            MapTraficomOverlay.setEnabled(traficomEnabled, on: style)
            MapForecastPin.update(coordinate: center, on: style)
            MapRouteOverlay.update(
                geometry: routeGeometry,
                start: routeStart,
                end: routeEnd,
                on: style
            )
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        let controller: MapScreenController
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?
        var onViewportChange: ((Double, Double) -> Void)?
        var traficomEnabled: Bool
        var forecastCenter: CLLocationCoordinate2D?
        weak var mapView: MLNMapView?

        var routeGeometry: [RouteCoordinate] = []
        var routeStart: RouteCoordinate?
        var routeEnd: RouteCoordinate?
        var lastFittedRouteSignature: String?
        var lastAppliedCenter: CLLocationCoordinate2D?

        init(controller: MapScreenController, onLongPress: ((CLLocationCoordinate2D) -> Void)?) {
            self.controller = controller
            self.onLongPress = onLongPress
            self.traficomEnabled = false
        }

        func centerChanged(from previous: CLLocationCoordinate2D?, to next: CLLocationCoordinate2D) -> Bool {
            guard let previous else { return true }
            let deltaLat = abs(previous.latitude - next.latitude)
            let deltaLon = abs(previous.longitude - next.longitude)
            return deltaLat > 0.00001 || deltaLon > 0.00001
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            onViewportChange?(mapView.zoomLevel, mapView.centerCoordinate.latitude)
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            onViewportChange?(mapView.zoomLevel, mapView.centerCoordinate.latitude)
            MapTraficomOverlay.setEnabled(traficomEnabled, on: style)
            if let forecastCenter {
                MapForecastPin.update(coordinate: forecastCenter, on: style)
            }
            MapRouteOverlay.update(
                geometry: routeGeometry,
                start: routeStart,
                end: routeEnd,
                on: style
            )
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view as? MLNMapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onLongPress?(coordinate)
        }
    }

    private static func routeGeometrySignature(_ geometry: [RouteCoordinate]) -> String {
        geometry.map { String(format: "%.5f,%.5f", $0.lat, $0.lon) }.joined(separator: "|")
    }
}
