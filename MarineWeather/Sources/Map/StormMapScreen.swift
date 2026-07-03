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
    var onViewportChange: ((Double, Double) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onLongPress: onLongPress)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView.makeConfigured()
        mapView.setCenter(center, zoomLevel: StormMapConstants.defaultZoom, animated: false)
        mapView.minimumZoomLevel = StormMapConstants.minimumZoom
        mapView.delegate = context.coordinator

        context.coordinator.mapView = mapView
        context.coordinator.lastAppliedCenter = center
        controller.mapView = mapView
        MapStormOverlay.attach(mapView: mapView)
        MapStormOverlay.setStyleReady(false)

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
        controller.mapView = mapView
        MapStormOverlay.attach(mapView: mapView)

        if context.coordinator.centerChanged(from: context.coordinator.lastAppliedCenter, to: center) {
            mapView.setCenter(center, zoomLevel: mapView.zoomLevel, animated: true)
            context.coordinator.lastAppliedCenter = center
        }

        context.coordinator.scheduleOverlaySyncIfNeeded(
            radarOverlay: radarOverlay,
            lightningStrikes: lightningStrikes
        )
    }

    static func dismantleUIView(_ mapView: MLNMapView, coordinator: Coordinator) {
        coordinator.cancelPendingSync()
        MapStormOverlay.detach()
        MapStormOverlay.setStyleReady(false)
        if let style = mapView.style {
            MapStormOverlay.removeAll(from: style)
        }
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        let controller: MapScreenController
        var onLongPress: ((CLLocationCoordinate2D) -> Void)?
        var onViewportChange: ((Double, Double) -> Void)?
        weak var mapView: MLNMapView?
        var lastAppliedCenter: CLLocationCoordinate2D?

        private var pendingRadarOverlay: ActiveRadarOverlay?
        private var pendingLightning: [LightningStrike] = []
        private var appliedOverlayKey: String?
        private var appliedLightningCount = -1
        private var syncWorkItem: DispatchWorkItem?
        private var lightningDeferredWork: DispatchWorkItem?

        init(controller: MapScreenController, onLongPress: ((CLLocationCoordinate2D) -> Void)?) {
            self.controller = controller
            self.onLongPress = onLongPress
        }

        func centerChanged(from previous: CLLocationCoordinate2D?, to next: CLLocationCoordinate2D) -> Bool {
            guard let previous else { return true }
            let deltaLat = abs(previous.latitude - next.latitude)
            let deltaLon = abs(previous.longitude - next.longitude)
            return deltaLat > 0.00001 || deltaLon > 0.00001
        }

        func scheduleOverlaySyncIfNeeded(
            radarOverlay: ActiveRadarOverlay?,
            lightningStrikes: [LightningStrike]
        ) {
            let overlayKey = Self.overlayKey(radarOverlay)
            let lightningCount = lightningStrikes.count
            if overlayKey == appliedOverlayKey, lightningCount == appliedLightningCount {
                return
            }

            pendingRadarOverlay = radarOverlay
            pendingLightning = lightningStrikes
            syncWorkItem?.cancel()

            let work = DispatchWorkItem { [weak self] in
                self?.applyPendingOverlays()
            }
            syncWorkItem = work
            DispatchQueue.main.async(execute: work)
        }

        func cancelPendingSync() {
            syncWorkItem?.cancel()
            syncWorkItem = nil
            lightningDeferredWork?.cancel()
            lightningDeferredWork = nil
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            onViewportChange?(mapView.zoomLevel, mapView.centerCoordinate.latitude)
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            onViewportChange?(mapView.zoomLevel, mapView.centerCoordinate.latitude)
            MapStormOverlay.setStyleReady(true)
            MapTraficomOverlay.setEnabled(false, on: style)
            applyPendingOverlays()
        }

        private func applyPendingOverlays() {
            guard let mapView, let style = mapView.style else { return }
            MapTraficomOverlay.setEnabled(false, on: style)

            MapStormOverlay.updateRadar(pendingRadarOverlay, on: style)
            appliedOverlayKey = Self.overlayKey(pendingRadarOverlay)

            lightningDeferredWork?.cancel()
            let strikes = pendingLightning
            let work = DispatchWorkItem { [weak self] in
                guard let self, let style = self.mapView?.style else { return }
                MapStormOverlay.updateLightning(strikes, on: style)
                self.appliedLightningCount = strikes.count
            }
            lightningDeferredWork = work
            let delay: TimeInterval = pendingRadarOverlay == nil ? 0 : 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }

        private static func overlayKey(_ overlay: ActiveRadarOverlay?) -> String {
            guard let overlay else { return "" }
            switch overlay.kind {
            case .wmsTiles:
                return "wms:" + (overlay.wmsTileUrlTemplate ?? "")
            case .geoImage:
                return "geo:" + (overlay.geoImageUrl ?? "")
            }
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
