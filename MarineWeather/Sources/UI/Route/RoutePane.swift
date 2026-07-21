import CoreLocation
import SwiftUI

struct RoutePane: View {
    @Bindable var viewModel: RouteViewModel
    @Bindable var offlinePack: OfflinePackViewModel
    var mapCenter: CLLocationCoordinate2D
    @Bindable var aisVM: AisMapViewModel
    @Bindable var premium = PremiumAccess.shared
    @State private var traficomEnabled = true
    @State private var mapController = MapScreenController()
    @State private var speedText = "6.0"
    @State private var shareItem: ShareItem?
    @State private var showDisclaimer = false
    @State private var mapZoom = AppConfig.defaultCompareZoom
    @State private var mapLatitude = AppConfig.defaultLatitude
    @State private var selectedAisVessel: AisVesselDisplay?
    var onRecenter: () -> Void

    private var hasRouteEndpoints: Bool {
        viewModel.routeStart != nil && viewModel.routeEnd != nil
    }

    var body: some View {
        Group {
            if premium.isPremium {
                routeContent
            } else {
                RoutePremiumPaywall(premium: premium) {
                    viewModel.onPremiumChanged(isPremium: true)
                }
            }
        }
        .onChange(of: premium.isPremium) { _, isPremium in
            viewModel.onPremiumChanged(isPremium: isPremium)
            if !isPremium {
                aisVM.setEnabled(false, premium: false)
            }
        }
        .onChange(of: aisVM.isEnabled) { _, enabled in
            guard enabled, premium.isPremium else { return }
            aisVM.primeViewport(latitude: mapCenter.latitude, longitude: mapCenter.longitude, zoom: mapZoom)
            syncAisViewport()
        }
        .task(id: aisVM.isEnabled) {
            guard aisVM.isEnabled, premium.isPremium else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                aisVM.tickLiveMapRender()
            }
        }
        .onAppear {
            speedText = formatSpeed(viewModel.boatSpeedKn)
            traficomEnabled = true
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            if !premium.iapReviewScreenshotMode {
                premiumDebugMenu.padding(8)
            }
        }
        #endif
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .navigationDisclaimerAlert(isPresented: $showDisclaimer)
    }

    private var routeContent: some View {
        GeometryReader { geometry in
            if hasRouteEndpoints {
                let twoPane = UiBreakpoints.useTwoPaneLayout(width: geometry.size.width)
                if twoPane {
                    HStack(spacing: 0) {
                        mapSection
                            .frame(
                                width: geometry.size.width * UiBreakpoints.compareMapWidthFraction,
                                height: geometry.size.height
                            )
                        RouteWeatherPane(
                            viewModel: viewModel,
                            offlinePack: offlinePack,
                            speedText: $speedText,
                            onExportGpx: exportGpx,
                            onExportPdf: exportPdf
                        )
                        .frame(
                            width: geometry.size.width * UiBreakpoints.compareWeatherWidthFraction,
                            height: geometry.size.height
                        )
                    }
                } else {
                    VStack(spacing: 0) {
                        mapSection
                            .frame(height: geometry.size.height * UiBreakpoints.stackedMapHeightFraction)
                        RouteWeatherPane(
                            viewModel: viewModel,
                            offlinePack: offlinePack,
                            speedText: $speedText,
                            onExportGpx: exportGpx,
                            onExportPdf: exportPdf
                        )
                        .frame(maxHeight: .infinity)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                }
            } else {
                mapSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if DEBUG
    private var premiumDebugMenu: some View {
        Menu {
            Text(premium.unlockSource.debugLabel)
                .font(.caption)
            Button(String(localized: "route_premium_dev_reset")) {
                premium.resetTestingPremiumState()
                viewModel.onPremiumChanged(isPremium: premium.isPremium)
            }
        } label: {
            Image(systemName: "ladybug.fill")
                .font(.caption)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
    #endif

    private var mapSection: some View {
        MapScreen(
            center: mapCenter,
            zoom: AppConfig.defaultCompareZoom,
            traficomEnabled: traficomEnabled,
            controller: mapController,
            routeGeometry: viewModel.routeGeometry,
            routeStart: viewModel.routeStart,
            routeEnd: viewModel.routeEnd,
            autoFitRoute: hasRouteEndpoints && !viewModel.isRoutingRoute,
            aisVessels: aisVM.vessels,
            aisEnabled: aisVM.isEnabled,
            aisRenderGeneration: aisVM.mapRenderGeneration,
            onLongPress: { coord in
                viewModel.onMapLongPress(lat: coord.latitude, lon: coord.longitude)
            },
            onViewportChange: { zoom, latitude in
                mapZoom = zoom
                mapLatitude = latitude
            },
            onMapViewportChange: { viewport in
                aisVM.updateViewport(viewport)
            },
            onAisVesselSelected: { selectedAisVessel = $0 }
        )
        .sheet(item: $selectedAisVessel) { vessel in
            AisVesselDetailSheet(vessel: vessel)
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                traficomChip
                AisMapChip(
                    ais: aisVM,
                    premium: true,
                    onNeedPremium: {},
                    onEnabled: {
                        aisVM.primeViewport(latitude: mapCenter.latitude, longitude: mapCenter.longitude, zoom: mapZoom)
                        syncAisViewport()
                    }
                )
                Button {
                    showDisclaimer = true
                } label: {
                    MapOverlayChrome.circleIcon(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "disclaimer_nav_title"))
            }
            .padding(8)
        }
        .overlay(alignment: .top) { routeHintBanner.padding(.top, 44) }
        .overlay(alignment: .bottomLeading) {
            MapScaleBarView(latitude: mapLatitude, zoomLevel: mapZoom)
                .padding(.leading, 8)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .bottomTrailing) { mapControls.padding(10) }
    }

    private var routeHintBanner: some View {
        Group {
            if viewModel.routeStart == nil {
                Text(String(localized: "route_hint_set_start"))
            } else if viewModel.routeEnd == nil {
                Text(String(localized: "route_hint_set_end"))
            } else if viewModel.isRoutingRoute {
                Text(String(localized: "route_computing_fairway"))
            } else if viewModel.routeFairwayUnavailable {
                Text(String(localized: "route_fairway_fallback"))
            } else {
                Text(String(localized: "route_fairway_ok"))
            }
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func syncAisViewport() {
        if let viewport = mapController.currentViewport() {
            aisVM.applyMapViewport(viewport)
        }
    }

    private var traficomChip: some View {
        Button { traficomEnabled.toggle() } label: {
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

    private func formatSpeed(_ kn: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), kn)
    }

    private func exportGpx() {
        let points = viewModel.routePointsForExport()
        guard points.count >= 2 else { return }
        do {
            let gpx = RouteGpx.build(routeName: AppConfig.appDisplayName, points: points)
            let stamp = Self.fileStamp()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("marine_weather_route_\(stamp).gpx")
            try gpx.write(to: url, atomically: true, encoding: .utf8)
            shareItem = ShareItem(url: url)
        } catch {
            // silent fail — user can retry
        }
    }

    private func exportPdf() {
        guard let start = viewModel.routeStart, let end = viewModel.routeEnd else { return }
        let slotLabels = viewModel.routeSlotLabels()
        let sources: [(name: String, slotLines: [String])] = SourceId.allCases.map { source in
            let state = viewModel.routeWeatherBySource[source] ?? .idle
            let lines: [String]
            if let slots = state.slots?.slots {
                lines = slots.map { pt in
                    guard let pt, let ms = pt.windSpeedMs else { return "—" }
                    let speed = viewModel.windUnit == .knots ? ms.msToKnots : ms
                    let unit = viewModel.windUnit.label
                    let dir = pt.windFromDeg.map { "\(Int($0.rounded()))°" } ?? "—"
                    return String(format: "%.1f %@ from %@", speed, unit, dir)
                }
            } else {
                lines = state.errorMessage.map { ["Error: \($0)"] }
                    ?? Array(repeating: "—", count: 4)
            }
            return (source.displayName, lines)
        }
        do {
            let url = try RoutePlanPDFExporter.writePDF(
                title: String(localized: "route_plan_pdf_title"),
                startLine: String(format: "Start: %.5f°N %.5f°E", start.lat, start.lon),
                endLine: String(format: "End: %.5f°N %.5f°E", end.lat, end.lon),
                departureLine: viewModel.formattedDepartureForExport(),
                legLine: String(
                    format: String(localized: "route_weather_leg"),
                    viewModel.routeWeatherLegNm ?? 0,
                    viewModel.routeWeatherEtaHours ?? 0
                ),
                boatSpeedLine: String(format: String(localized: "route_boat_speed_pdf"), viewModel.boatSpeedKn),
                slotLabels: slotLabels,
                sources: sources,
                disclaimer: String(localized: "disclaimer_nav_body")
            )
            shareItem = ShareItem(url: url)
        } catch {
            // silent fail
        }
    }

    private static func fileStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f.string(from: Date())
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
