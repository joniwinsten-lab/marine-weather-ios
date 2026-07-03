import CoreLocation
import SwiftUI

struct ComparePane: View {
    @Bindable var viewModel: CompareViewModel
    @Bindable var routeVM: RouteViewModel
    @Bindable var premium = PremiumAccess.shared
    @State private var traficomEnabled = true
    @State private var mapController = MapScreenController()
    @State private var mapZoom = AppConfig.defaultCompareZoom
    @State private var mapLatitude = AppConfig.defaultLatitude
    var onRecenter: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let twoPane = geometry.size.width >= UiBreakpoints.twoPaneMinWidth
            if twoPane {
                HStack(spacing: 0) {
                    mapSection
                        .frame(
                            width: geometry.size.width * UiBreakpoints.compareMapWidthFraction,
                            height: geometry.size.height
                        )
                    WeatherComparePane(viewModel: viewModel, dense: true)
                        .frame(
                            width: geometry.size.width * UiBreakpoints.compareWeatherWidthFraction,
                            height: geometry.size.height
                        )
                }
            } else {
                VStack(spacing: 0) {
                    mapSection
                        .frame(height: geometry.size.height * 0.52)
                    WeatherComparePane(
                        viewModel: viewModel,
                        dense: geometry.size.width >= UiBreakpoints.weatherPaneDenseMinWidth
                    )
                    .frame(height: geometry.size.height * 0.48)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.onAppear()
        }
    }

    private var mapSection: some View {
        MapScreen(
            center: viewModel.mapCenter,
            zoom: AppConfig.defaultCompareZoom,
            traficomEnabled: traficomEnabled,
            controller: mapController,
            routeGeometry: premium.isPremium ? routeVM.routeGeometry : [],
            routeStart: premium.isPremium ? routeVM.routeStart : nil,
            routeEnd: premium.isPremium ? routeVM.routeEnd : nil,
            onLongPress: { viewModel.setMapCenter($0) },
            onViewportChange: { zoom, latitude in
                mapZoom = zoom
                mapLatitude = latitude
            }
        )
        .overlay(alignment: .topLeading) {
            traficomChip.padding(8)
        }
        .overlay(alignment: .bottomLeading) {
            MapScaleBarView(latitude: mapLatitude, zoomLevel: mapZoom)
                .padding(.leading, 8)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .bottomTrailing) {
            mapControls.padding(10)
        }
    }

    private var traficomChip: some View {
        Button {
            traficomEnabled.toggle()
        } label: {
            MapOverlayChrome.chipLabel(isOn: traficomEnabled) {
                Text(String(localized: "traficom_chip"))
            }
        }
        .buttonStyle(.plain)
    }

    private var mapControls: some View {
        VStack(spacing: 6) {
            mapControlButton(systemName: "location.fill", action: onRecenter)
            mapControlButton(systemName: "plus", action: { mapController.zoomIn() })
            mapControlButton(systemName: "minus", action: { mapController.zoomOut() })
        }
    }

    private func mapControlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MapOverlayChrome.circleIcon(systemName: systemName)
        }
        .buttonStyle(.plain)
    }
}
