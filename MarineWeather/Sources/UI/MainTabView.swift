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
    @State private var selection: MainTab = {
        #if DEBUG
        ScreenshotLaunch.initialTab ?? .compare
        #else
        .compare
        #endif
    }()
    @State private var didAutoCenterOnGPS = false
    @State private var showNavigationMenu = false
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var networkMonitor = NetworkConnectivityMonitor.shared

    var body: some View {
        GeometryReader { geometry in
            let showRail = UiBreakpoints.showsNavigationRail(width: geometry.size.width)
            HStack(spacing: 0) {
                if showRail {
                    NavigationRailView(selection: $selection)
                }

                VStack(spacing: 0) {
                    if !showRail {
                        CompactNavigationBar(selection: $selection, showMenu: $showNavigationMenu)
                    }
                    OfflineStatusBanner(status: compareVM.connectivityStatus)
                    detail(for: selection)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    AttributionFooter()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showNavigationMenu) {
            NavigationMenuSheet(selection: $selection, isPresented: $showNavigationMenu)
        }
        .onAppear {
            #if DEBUG
            applyDebugScreenshotLaunchOverrides()
            #endif
            AppStoreReviewCoordinator.recordAppLaunch()
            #if DEBUG
            if !ScreenshotLaunch.iapReview {
                locationManager.requestWhenInUse()
                locationManager.refreshLocation()
            }
            #else
            locationManager.requestWhenInUse()
            locationManager.refreshLocation()
            #endif
            routeVM.syncMapCenter(compareVM.mapCenter)
            compareVM.updateConnectivity(isOnline: networkMonitor.isOnline)
            Task {
                await MapTileWarmup.warm(
                    lat: compareVM.mapCenter.latitude,
                    lon: compareVM.mapCenter.longitude
                )
            }
            stormVM.prefetchInBackground(
                lat: compareVM.mapCenter.latitude,
                lon: compareVM.mapCenter.longitude
            )
        }
        .task(id: mapCenterPrefetchKey) {
            try? await Task.sleep(nanoseconds: 750_000_000)
            stormVM.prefetchInBackground(
                lat: compareVM.mapCenter.latitude,
                lon: compareVM.mapCenter.longitude
            )
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
        case .weather:
            WeatherOutlookPane(viewModel: compareVM)
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

    private var mapCenterPrefetchKey: String {
        String(
            format: "%.2f_%.2f",
            compareVM.mapCenter.latitude,
            compareVM.mapCenter.longitude
        )
    }

    private func recenterToDevice() {
        locationManager.refreshLocation()
        if let coordinate = locationManager.lastCoordinate {
            compareVM.setMapCenter(coordinate)
            routeVM.syncMapCenter(coordinate)
        }
    }

    #if DEBUG
    /// Launch args for App Store screenshot automation (`scripts/capture-app-store-screenshots.sh`).
    private func applyDebugScreenshotLaunchOverrides() {
        let args = CommandLine.arguments
        if args.contains("-screenshotPremium") {
            PremiumAccess.shared.unlockForTesting()
        }
        if args.contains("-iapReviewScreenshot") {
            PremiumAccess.shared.configureForIAPReviewScreenshot()
        }
        if let tab = ScreenshotLaunch.initialTab {
            selection = tab
        }
    }
    #endif
}

#Preview {
    MainTabView()
}
