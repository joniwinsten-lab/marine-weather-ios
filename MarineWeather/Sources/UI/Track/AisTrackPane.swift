import CoreLocation
import SwiftUI

struct AisTrackPane: View {
    @Bindable var viewModel: AisTrackViewModel
    var mapCenter: CLLocationCoordinate2D
    @Bindable var premium = PremiumAccess.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var traficomEnabled = false
    @State private var mapController = MapScreenController()
    @State private var mapZoom = AppConfig.defaultCompareZoom
    @State private var mapLatitude = AppConfig.defaultLatitude
    @State private var mapDisplayCenter: CLLocationCoordinate2D
    @State private var showAddDialog = false
    @State private var selectedVessel: AisVesselDisplay?
    @State private var snackbarMessage: String?
    var onRecenter: () -> Void

    init(viewModel: AisTrackViewModel, mapCenter: CLLocationCoordinate2D, onRecenter: @escaping () -> Void) {
        self.viewModel = viewModel
        self.mapCenter = mapCenter
        self.onRecenter = onRecenter
        _mapDisplayCenter = State(initialValue: mapCenter)
    }

    var body: some View {
        Group {
            if premium.isPremium {
                trackContent
            } else {
                RoutePremiumPaywall(premium: premium) {
                    viewModel.setPremiumActive(true)
                }
            }
        }
        .onAppear {
            viewModel.setPremiumActive(premium.isPremium)
            if premium.isPremium {
                viewModel.setSceneActive(scenePhase == .active)
                viewModel.ensureFallbackViewport(
                    latitude: mapCenter.latitude,
                    longitude: mapCenter.longitude
                )
                if let viewport = mapController.currentViewport() {
                    viewModel.updateViewport(viewport)
                }
            }
        }
        .onChange(of: premium.isPremium) { _, isPremium in
            viewModel.setPremiumActive(isPremium)
            if isPremium {
                viewModel.setSceneActive(scenePhase == .active)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard premium.isPremium else { return }
            viewModel.setSceneActive(phase == .active)
        }
        .onChange(of: mapCenter.latitude) { _, _ in
            mapDisplayCenter = mapCenter
            if premium.isPremium {
                viewModel.ensureFallbackViewport(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
            }
        }
        .onChange(of: mapCenter.longitude) { _, _ in
            mapDisplayCenter = mapCenter
        }
        .onChange(of: viewModel.mapRecenterSignal) { _, _ in
            if let target = viewModel.mapRecenterTarget {
                mapDisplayCenter = target
            }
            if let zoom = viewModel.mapRecenterZoom {
                mapZoom = zoom
            }
        }
        .onChange(of: viewModel.userMessage) { _, message in
            snackbarMessage = message
            if message != nil {
                viewModel.clearUserMessage()
            }
        }
        .alert(
            snackbarMessage ?? "",
            isPresented: Binding(
                get: { snackbarMessage != nil },
                set: { if !$0 { snackbarMessage = nil } }
            )
        ) {
            Button(String(localized: "disclaimer_nav_ok"), role: .cancel) {}
        }
        .sheet(item: $selectedVessel) { vessel in
            AisVesselDetailSheet(vessel: vessel)
        }
        .sheet(isPresented: $showAddDialog) {
            AddVesselSheet { mmsi, nickname in
                viewModel.addManualVessel(mmsi: mmsi, nickname: nickname)
            }
        }
    }

    private var trackContent: some View {
        GeometryReader { geometry in
            let twoPane = UiBreakpoints.useTwoPaneLayout(width: geometry.size.width)
            if twoPane {
                HStack(spacing: 0) {
                    mapSection
                        .frame(
                            width: geometry.size.width * UiBreakpoints.compareMapWidthFraction,
                            height: geometry.size.height
                        )
                    trackPanelSection
                        .frame(
                            width: geometry.size.width * UiBreakpoints.compareWeatherWidthFraction,
                            height: geometry.size.height
                        )
                }
            } else {
                VStack(spacing: 0) {
                    mapSection
                        .frame(height: geometry.size.height * UiBreakpoints.stackedMapHeightFraction)
                    trackPanelSection
                        .frame(maxHeight: .infinity)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mapSection: some View {
        MapScreen(
            center: mapDisplayCenter,
            zoom: mapZoom,
            traficomEnabled: traficomEnabled,
            controller: mapController,
            aisVessels: viewModel.vessels,
            aisEnabled: !viewModel.vessels.isEmpty,
            aisRenderGeneration: viewModel.mapRenderGeneration,
            recenterSignal: viewModel.mapRecenterSignal,
            recenterZoom: viewModel.mapRecenterZoom,
            onViewportChange: { zoom, latitude in
                mapZoom = zoom
                mapLatitude = latitude
            },
            onMapViewportChange: { viewModel.applyMapViewport($0) },
            onAisVesselSelected: { selectedVessel = $0 }
        )
        .overlay(alignment: .topLeading) {
            HStack(spacing: 8) {
                streamStatusChip
                Toggle(isOn: $traficomEnabled) {
                    Text(String(localized: "track_marine_chart"))
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(8)
        }
        .overlay(alignment: .bottomLeading) {
            MapScaleBarView(latitude: mapLatitude, zoomLevel: mapZoom)
                .padding(.leading, 8)
                .padding(.bottom, 8)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 6) {
                mapControlButton(systemName: "location.fill", action: onRecenter)
                mapControlButton(systemName: "plus", action: { mapController.zoomIn() })
                mapControlButton(systemName: "minus", action: { mapController.zoomOut() })
            }
            .padding(10)
        }
        .onAppear {
            syncTrackViewport()
        }
    }

    private var trackPanelSection: some View {
        VStack(spacing: 0) {
            Picker("", selection: Binding(
                get: { viewModel.panel },
                set: { viewModel.setPanel($0) }
            )) {
                Text(String(localized: "track_panel_watchlist")).tag(AisTrackPanel.watchlist)
                Text(String(localized: "track_panel_browse")).tag(AisTrackPanel.browse)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if viewModel.panel == .browse {
                HStack {
                    Text(String(localized: "track_browse_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        viewModel.refreshBrowseNow()
                    } label: {
                        if viewModel.browseLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.browseLoading)
                    .accessibilityLabel(String(localized: "track_refresh_nearby"))
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }

            listContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.panel == .watchlist {
                Button {
                    showAddDialog = true
                } label: {
                    Label(String(localized: "track_add_vessel"), systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(12)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.panel == .watchlist {
            watchlistContent
        } else {
            browseContent
        }
    }

    private var watchlistContent: some View {
        VStack(spacing: 8) {
            TextField(String(localized: "track_search_watchlist"), text: Binding(
                get: { viewModel.watchlistSearch },
                set: { viewModel.setWatchlistSearch($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            HStack(spacing: 8) {
                filterChip(String(localized: "track_filter_all"), filter: .all)
                filterChip(String(localized: "track_filter_active"), filter: .active)
                filterChip(String(localized: "track_filter_stale"), filter: .stale)
            }
            .padding(.horizontal, 12)

            if viewModel.isLoading && viewModel.watchlistRows.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.watchlistRows.isEmpty {
                Text(String(localized: "track_empty_watchlist"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(viewModel.watchlistRows, id: \.entry.mmsi) { row in
                        watchlistRow(row)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var browseContent: some View {
        VStack(spacing: 8) {
            TextField(String(localized: "track_search_browse"), text: Binding(
                get: { viewModel.browseSearch },
                set: { viewModel.setBrowseSearch($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            if viewModel.browseLoading && viewModel.browseItems.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.browseItems.isEmpty {
                Text(String(localized: "track_empty_browse"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(viewModel.browseItems) { item in
                        browseRow(item)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func watchlistRow(_ row: AisWatchlistRow) -> some View {
        let active = row.vessel.map { AisVesselMotion.isActive($0) } == true
        return Button {
            if let vessel = row.vessel {
                selectedVessel = vessel
            }
            viewModel.focusWatchlistVessel(mmsi: row.entry.mmsi)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.entry.displayLabel)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(watchlistSubtitle(row: row, active: active))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(String(localized: "track_remove")) {
                    viewModel.removeFromWatchlist(mmsi: row.entry.mmsi)
                }
                .buttonStyle(.borderless)
            }
        }
        .buttonStyle(.plain)
    }

    private func browseRow(_ item: AisBrowseItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("MMSI \(item.mmsi)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(String(localized: "track_add_to_watchlist")) {
                viewModel.addBrowseItem(item)
            }
            .buttonStyle(.borderless)
        }
    }

    private func watchlistSubtitle(row: AisWatchlistRow, active: Bool) -> String {
        var parts = ["MMSI \(row.entry.mmsi)"]
        if let sog = row.vessel?.sogKn {
            parts.append(AisFormatting.formatSpeedKn(sog))
        }
        if !active {
            parts.append(String(localized: "track_no_signal"))
        }
        return parts.joined(separator: " · ")
    }

    private func filterChip(_ title: String, filter: AisTrackListFilter) -> some View {
        Button(title) {
            viewModel.setListFilter(filter)
        }
        .buttonStyle(.bordered)
        .tint(viewModel.listFilter == filter ? .accentColor : .secondary)
    }

    private var streamStatusChip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(streamDotColor)
                .frame(width: 8, height: 8)
            Text(streamLabel)
                .font(.caption)
        }
    }

    private var streamLabel: String {
        switch viewModel.streamMode {
        case .live: String(localized: "track_mqtt_live")
        case .connecting: String(localized: "track_mqtt_connecting")
        case .restOnly: String(localized: "track_mqtt_rest")
        case .error: String(localized: "track_mqtt_error")
        case .off: String(localized: "track_mqtt_off")
        }
    }

    private var streamDotColor: Color {
        switch viewModel.streamMode {
        case .live: Color(red: 0.26, green: 0.63, blue: 0.28)
        case .restOnly: Color(red: 0.18, green: 0.49, blue: 0.20)
        case .connecting: Color(red: 0.96, green: 0.49, blue: 0.0)
        case .error: Color(red: 0.78, green: 0.16, blue: 0.16)
        case .off: Color.secondary
        }
    }

    private func syncTrackViewport() {
        if let viewport = mapController.currentViewport() {
            viewModel.applyMapViewport(viewport)
        }
    }

    private func mapControlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            MapOverlayChrome.circleIcon(systemName: systemName)
        }
        .buttonStyle(.plain)
    }
}

private struct AddVesselSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mmsiText = ""
    @State private var nickname = ""
    var onAdd: (Int, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("MMSI", text: $mmsiText)
                    .keyboardType(.numberPad)
                    .onChange(of: mmsiText) { _, newValue in
                        mmsiText = String(newValue.filter(\.isNumber).prefix(9))
                    }
                TextField(String(localized: "track_nickname_optional"), text: $nickname)
            }
            .navigationTitle(String(localized: "track_add_vessel"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "disclaimer_nav_ok")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        if let mmsi = Int(mmsiText), mmsiText.count == 9 {
                            let nick = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                            onAdd(mmsi, nick.isEmpty ? nil : nick)
                            dismiss()
                        }
                    }
                    .disabled(mmsiText.count != 9)
                }
            }
        }
    }
}
