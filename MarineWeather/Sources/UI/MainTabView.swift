import CoreLocation
import SwiftUI

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var compareVM = CompareViewModel()
    @State private var stormVM = StormMapViewModel()
    @State private var selection: MainTab = .compare

    var body: some View {
        HStack(spacing: 0) {
            NavigationRailView(selection: $selection)

            VStack(spacing: 0) {
                detail(for: selection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                AttributionFooter()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            locationManager.requestWhenInUse()
        }
    }

    @ViewBuilder
    private func detail(for tab: MainTab) -> some View {
        switch tab {
        case .compare:
            ComparePane(
                viewModel: compareVM,
                onRecenter: {
                    locationManager.refreshLocation()
                    if let coordinate = locationManager.lastCoordinate {
                        compareVM.setMapCenter(coordinate)
                    }
                }
            )
        case .route:
            PremiumPlaceholderPane(
                title: String(localized: "placeholder_route_title"),
                message: String(localized: "placeholder_route_message")
            )
        case .extendedWind:
            PremiumPlaceholderPane(
                title: String(localized: "placeholder_wind_title"),
                message: String(localized: "placeholder_wind_message")
            )
        case .marineText:
            MarineTextOverviewPane(
                latitude: compareVM.mapCenter.latitude,
                longitude: compareVM.mapCenter.longitude
            )
        case .stormRadar:
            StormRadarPane(
                stormVM: stormVM,
                mapCenter: compareVM.mapCenter,
                onLongPress: { compareVM.setMapCenter($0) },
                onRecenter: {
                    locationManager.refreshLocation()
                    if let coordinate = locationManager.lastCoordinate {
                        compareVM.setMapCenter(coordinate)
                    }
                }
            )
        }
    }
}

#Preview {
    MainTabView()
}
