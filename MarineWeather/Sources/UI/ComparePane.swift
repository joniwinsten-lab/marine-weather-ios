import CoreLocation
import SwiftUI

struct ComparePane: View {
    @Bindable var viewModel: CompareViewModel
    @State private var traficomEnabled = true
    @State private var mapController = MapScreenController()
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
            onLongPress: { viewModel.setMapCenter($0) }
        )
        .overlay(alignment: .topLeading) {
            traficomChip.padding(8)
        }
        .overlay(alignment: .bottomTrailing) {
            mapControls.padding(10)
        }
    }

    private var traficomChip: some View {
        Button {
            traficomEnabled.toggle()
        } label: {
            Text(String(localized: "traficom_chip"))
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(traficomEnabled ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
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
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
