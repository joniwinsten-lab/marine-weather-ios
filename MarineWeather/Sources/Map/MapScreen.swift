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

    /// Frame the full route with padding (Android `newLatLngBounds`).
    func currentViewport() -> MapViewport? {
        guard let mapView else { return nil }
        let bounds = mapView.visibleCoordinateBounds
        return MapViewport(
            southWest: bounds.sw,
            northEast: bounds.ne,
            zoom: mapView.zoomLevel,
            centerLatitude: mapView.centerCoordinate.latitude
        )
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
    /// When true, zoom to fit [routeGeometry] whenever it changes (route planning tab).
    var autoFitRoute = false
    var aisVessels: [AisVesselDisplay] = []
    var aisEnabled = false
    var aisRenderGeneration = 0
    var recenterSignal: Int64 = 0
    var recenterZoom: Double?
    var onLongPress: ((CLLocationCoordinate2D) -> Void)?
    var onViewportChange: ((Double, Double) -> Void)?
    var onMapViewportChange: ((MapViewport) -> Void)?
    var onAisVesselSelected: ((AisVesselDisplay) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onLongPress: onLongPress, onAisVesselSelected: onAisVesselSelected)
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

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.require(toFail: recognizer)
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onViewportChange = onViewportChange
        context.coordinator.onMapViewportChange = onMapViewportChange
        context.coordinator.onAisVesselSelected = onAisVesselSelected
        context.coordinator.traficomEnabled = traficomEnabled
        context.coordinator.aisEnabled = aisEnabled
        context.coordinator.aisVessels = aisVessels
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
        } else {
            context.coordinator.lastFittedRouteSignature = nil
            if recenterSignal != 0, recenterSignal != context.coordinator.lastAppliedRecenterSignal {
                context.coordinator.lastAppliedRecenterSignal = recenterSignal
                let zoomLevel = recenterZoom ?? mapView.zoomLevel
                mapView.setCenter(center, zoomLevel: zoomLevel, animated: true)
                context.coordinator.lastAppliedCenter = center
            } else if context.coordinator.centerChanged(from: context.coordinator.lastAppliedCenter, to: center) {
                mapView.setCenter(center, zoomLevel: mapView.zoomLevel, animated: true)
                context.coordinator.lastAppliedCenter = center
            }
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
            let needsAisRedraw = aisEnabled != context.coordinator.lastAppliedAisEnabled
                || aisRenderGeneration != context.coordinator.lastAppliedAisRenderGeneration
            if needsAisRedraw {
                MapAisOverlay.update(vessels: aisVessels, enabled: aisEnabled, on: style)
                context.coordinator.lastAppliedAisEnabled = aisEnabled
                context.coordinator.lastAppliedAisRenderGeneration = aisRenderGeneration
            }
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        let controller: MapScreenController
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?
        var onViewportChange: ((Double, Double) -> Void)?
        var onMapViewportChange: ((MapViewport) -> Void)?
        var onAisVesselSelected: ((AisVesselDisplay) -> Void)?
        var traficomEnabled: Bool
        var aisVessels: [AisVesselDisplay] = []
        var aisEnabled = false
        var lastAppliedAisRenderGeneration = -1
        var lastAppliedAisEnabled = false
        var forecastCenter: CLLocationCoordinate2D?
        weak var mapView: MLNMapView?

        init(
            controller: MapScreenController,
            onLongPress: ((CLLocationCoordinate2D) -> Void)?,
            onAisVesselSelected: ((AisVesselDisplay) -> Void)?
        ) {
            self.controller = controller
            self.onLongPress = onLongPress
            self.onAisVesselSelected = onAisVesselSelected
            self.traficomEnabled = false
        }

        var routeGeometry: [RouteCoordinate] = []
        var routeStart: RouteCoordinate?
        var routeEnd: RouteCoordinate?
        var lastFittedRouteSignature: String?
        var lastAppliedCenter: CLLocationCoordinate2D?
        var lastAppliedRecenterSignal: Int64 = 0

        func centerChanged(from previous: CLLocationCoordinate2D?, to next: CLLocationCoordinate2D) -> Bool {
            guard let previous else { return true }
            let deltaLat = abs(previous.latitude - next.latitude)
            let deltaLon = abs(previous.longitude - next.longitude)
            return deltaLat > 0.00001 || deltaLon > 0.00001
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            onViewportChange?(mapView.zoomLevel, mapView.centerCoordinate.latitude)
            let bounds = mapView.visibleCoordinateBounds
            onMapViewportChange?(MapViewport(
                southWest: bounds.sw,
                northEast: bounds.ne,
                zoom: mapView.zoomLevel,
                centerLatitude: mapView.centerCoordinate.latitude
            ))
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
            MapAisOverlay.update(vessels: aisVessels, enabled: aisEnabled, on: style)
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view as? MLNMapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onLongPress?(coordinate)
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  aisEnabled,
                  let mapView = recognizer.view as? MLNMapView,
                  !aisVessels.isEmpty else { return }
            let point = recognizer.location(in: mapView)
            let hitRadius: CGFloat = 32
            var best: (vessel: AisVesselDisplay, distance: CGFloat)?

            for vessel in aisVessels {
                guard let coord = AisVesselMotion.displayCoordinate(vessel: vessel) else { continue }
                let vesselPoint = mapView.convert(coord, toPointTo: mapView)
                let dx = vesselPoint.x - point.x
                let dy = vesselPoint.y - point.y
                let dist = hypot(dx, dy)
                guard dist <= hitRadius else { continue }
                if let current = best {
                    if dist < current.distance { best = (vessel, dist) }
                } else {
                    best = (vessel, dist)
                }
            }

            if let vessel = best?.vessel {
                onAisVesselSelected?(vessel)
            }
        }
    }

    private static func routeGeometrySignature(_ geometry: [RouteCoordinate]) -> String {
        geometry.map { String(format: "%.5f,%.5f", $0.lat, $0.lon) }.joined(separator: "|")
    }
}
