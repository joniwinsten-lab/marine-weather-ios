import MapLibre

extension MLNMapView {
    /// Shared MapLibre setup for Compare, Route, and Storm maps.
    static func makeConfigured() -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.styleURL = AppConfig.mapStyleURL
        mapView.automaticallyAdjustsContentInset = false
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        return mapView
    }
}
