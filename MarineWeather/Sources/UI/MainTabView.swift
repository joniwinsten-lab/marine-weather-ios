import CoreLocation
import SwiftUI

struct MainTabView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var compareVM = CompareViewModel()
    @State private var routeVM = RouteViewModel()
    @State private var trackVM = AisTrackViewModel()
    @State private var stormVM = StormMapViewModel()
    @State private var aisVM = AisMapViewModel()
    @State private var offlinePackVM = OfflinePackViewModel()
    @State private var selection: MainTab = .compare
    @State private var didAutoCenterOnGPS = false
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var networkMonitor = NetworkConnectivityMonitor.shared

    var body: some View {
        HStack(spacing: 0) {
            NavigationRailView(selection: $selection)

            VStack(spacing: 0) {
                OfflineStatusBanner(status: compareVM.connectivityStatus)
                detail(for: selection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                AttributionFooter()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            AppStoreReviewCoordinator.recordAppLaunch()
            locationManager.requestWhenInUse()
            locationManager.refreshLocation()
            routeVM.syncMapCenter(compareVM.mapCenter)
            compareVM.updateConnectivity(isOnline: networkMonitor.isOnline)
            Task {
                await MapTileWarmup.warm(
                    lat: compareVM.mapCenter.latitude,
                    lon: compareVM.mapCenter.longitude
                )
            }
        }
        .onAppear {
            aisVM.setSceneActive(scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, phase in
            aisVM.setSceneActive(phase == .active)
        }
        .onChange(of: networkMonitor.isOnline) { _, isOnline in
            compareVM.updateConnectivity(isOnline: isOnline)
        }
        .onChange(of: compareVM.mapCenter.latitude) { _, _ in
            routeVM.syncMapCenter(compareVM.mapCenter)
        }
        .onChange(of: compareVM.mapCenter.longitude) { _, _ in
            routeVM.syncMapCenter(compareVM.mapCenter)
        }
        .onChange(of: locationManager.locationUpdateToken) { _, _ in
            guard !didAutoCenterOnGPS, let coordinate = locationManager.lastCoordinate else { return }
            didAutoCenterOnGPS = true
            compareVM.setMapCenter(coordinate)
            routeVM.syncMapCenter(coordinate)
        }
    }

    @ViewBuilder
    private func detail(for tab: MainTab) -> some View {
        switch tab {
        case .compare:
            ComparePane(
                viewModel: compareVM,
                routeVM: routeVM,
                aisVM: aisVM,
                onRecenter: recenterToDevice
            )
        case .route:
            RoutePane(
                viewModel: routeVM,
                offlinePack: offlinePackVM,
                mapCenter: compareVM.mapCenter,
                aisVM: aisVM,
                onRecenter: recenterToDevice
            )
        case .track:
            AisTrackPane(
                viewModel: trackVM,
                mapCenter: compareVM.mapCenter,
                onRecenter: recenterToDevice
            )
        case .extendedWind:
            ExtendedWindOutlookPane(
                viewModel: compareVM,
                onRecenter: recenterToDevice
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
                onRecenter: recenterToDevice
            )
        }
    }

    private func recenterToDevice() {
        locationManager.refreshLocation()
        if let coordinate = locationManager.lastCoordinate {
            compareVM.setMapCenter(coordinate)
            routeVM.syncMapCenter(coordinate)
        }
    }
}

#Preview {
    MainTabView()
}
