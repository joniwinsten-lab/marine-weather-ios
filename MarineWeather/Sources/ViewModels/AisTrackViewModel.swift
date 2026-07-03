import CoreLocation
import Foundation
import Observation

/// Seuranta / Track tab: watchlist + browse + MQTT (Android `AisTrackViewModel`).
@MainActor
@Observable
final class AisTrackViewModel {
    private(set) var panel: AisTrackPanel = .watchlist
    private(set) var listFilter: AisTrackListFilter = .all
    private(set) var watchlistSearch = ""
    private(set) var browseSearch = ""
    private(set) var watchlistRows: [AisWatchlistRow] = []
    private(set) var browseItems: [AisBrowseItem] = []
    private(set) var vessels: [AisVesselDisplay] = []
    private(set) var streamMode: AisStreamMode = .off
    private(set) var isLoading = false
    private(set) var browseLoading = false
    private(set) var userMessage: String?
    private(set) var mapRenderGeneration = 0
    private(set) var mapRecenterSignal: Int64 = 0
    private(set) var mapRecenterTarget: CLLocationCoordinate2D?
    private(set) var mapRecenterZoom: Double?

    private let repository: DigitrafficAisRepository
    private let watchlistStore: AisWatchlistStore
    private let mqttCoordinator: AisMqttCoordinator
    private let mqttParser = AisMqttMessageParser()

    private var fleetByMmsi: [Int: AisVesselDisplay] = [:]
    private var lastViewport: MapViewport?
    private var sceneActive = false
    private var premiumActive = false
    private var lastError: String?
    private var pollTask: Task<Void, Never>?
    private var browseTask: Task<Void, Never>?
    private var publishThrottleTask: Task<Void, Never>?
    private var liveTickTask: Task<Void, Never>?
    private var mqttHandlerId: UUID?
    private var isRefreshingFleet = false

    init(
        repository: DigitrafficAisRepository,
        watchlistStore: AisWatchlistStore,
        mqttCoordinator: AisMqttCoordinator
    ) {
        self.repository = repository
        self.watchlistStore = watchlistStore
        self.mqttCoordinator = mqttCoordinator
        mqttHandlerId = mqttCoordinator.addMessageHandler { [weak self] message in
            Task { @MainActor in
                self?.handleMqttMessage(topic: message.topic, payload: message.payload)
            }
        }
    }

    convenience init() {
        self.init(
            repository: AppServices.shared.aisRepository,
            watchlistStore: AppServices.shared.watchlistStore,
            mqttCoordinator: AppServices.shared.mqttCoordinator
        )
    }

    var watchlistEntries: [AisWatchlistEntry] {
        watchlistStore.entries
    }

    func setSceneActive(_ active: Bool) {
        sceneActive = active
        guard premiumActive else { return }
        if active {
            streamMode = .connecting
            bootstrap()
            startLiveTickIfNeeded()
        } else {
            stopPolling()
            browseTask?.cancel()
            liveTickTask?.cancel()
            mqttCoordinator.setWatchlistConsumer(active: false, mmsis: [])
            streamMode = .off
        }
    }

    func setPremiumActive(_ active: Bool) {
        premiumActive = active
        if !active {
            tearDown()
        } else if sceneActive {
            bootstrap()
            startLiveTickIfNeeded()
        }
    }

    func setPanel(_ newPanel: AisTrackPanel) {
        panel = newPanel
        if newPanel == .browse, sceneActive, premiumActive {
            scheduleBrowseRefresh()
        } else {
            publishUi()
        }
    }

    func setListFilter(_ filter: AisTrackListFilter) {
        listFilter = filter
        publishUi()
    }

    func setWatchlistSearch(_ query: String) {
        watchlistSearch = query
        publishUi()
    }

    func setBrowseSearch(_ query: String) {
        browseSearch = query
        Task { await refreshBrowseMerged() }
    }

    func updateViewport(_ viewport: MapViewport) {
        lastViewport = viewport
        if panel == .browse, sceneActive, premiumActive {
            scheduleBrowseRefresh()
        }
    }

    func ensureFallbackViewport(latitude: Double, longitude: Double, zoom: Double = 8.0) {
        guard lastViewport == nil else { return }
        lastViewport = .aroundCenter(latitude: latitude, longitude: longitude, zoom: zoom)
        if panel == .browse {
            scheduleBrowseRefresh()
        }
    }

    func clearUserMessage() {
        userMessage = nil
    }

    func addManualVessel(mmsi: Int, nickname: String?) {
        Task {
            let meta = try? await repository.lookupMetadata(mmsi: mmsi)
            do {
                try watchlistStore.addEntry(
                    mmsi: mmsi,
                    nickname: nickname,
                    name: meta?.name,
                    callSign: meta?.callSign,
                    source: .manual
                )
                await refreshWatchlistFleet()
                focusWatchlistVessel(mmsi: mmsi)
            } catch {
                userMessage = error.localizedDescription
            }
        }
    }

    func addBrowseItem(_ item: AisBrowseItem) {
        Task {
            do {
                try watchlistStore.addEntry(
                    mmsi: item.mmsi,
                    name: item.name,
                    callSign: item.callSign,
                    source: .search
                )
                panel = .watchlist
                await refreshWatchlistFleet()
                focusWatchlistVessel(mmsi: item.mmsi)
            } catch let error as WatchlistStoreError {
                userMessage = error.localizedDescription
            } catch {
                userMessage = error.localizedDescription
            }
        }
    }

    func removeFromWatchlist(mmsi: Int) {
        Task {
            watchlistStore.removeEntry(mmsi: mmsi)
            fleetByMmsi.removeValue(forKey: mmsi)
            syncMqttSubscriptions()
            publishUi()
        }
    }

    func refreshBrowseNow() {
        scheduleBrowseRefresh(force: true)
    }

    func tickLiveMapRender() {
        guard sceneActive, premiumActive else { return }
        guard AisVesselMotion.needsLiveMapTick(vessels) else { return }
        mapRenderGeneration += 1
    }

    func focusWatchlistVessel(mmsi: Int) {
        Task {
            var vessel = fleetByMmsi[mmsi]
            if vessel == nil, premiumActive {
                await refreshWatchlistFleet()
                vessel = fleetByMmsi[mmsi]
            }
            guard let resolved = vessel,
                  resolved.latitude.isFinite,
                  resolved.longitude.isFinite else { return }
            lastViewport = .aroundCenter(
                latitude: resolved.latitude,
                longitude: resolved.longitude,
                zoom: AisTrackConfig.focusVesselZoom
            )
            requestMapRecenter(
                latitude: resolved.latitude,
                longitude: resolved.longitude,
                zoom: AisTrackConfig.focusVesselZoom
            )
            publishUi()
        }
    }

    // MARK: - Private

    private func requestMapRecenter(latitude: Double, longitude: Double, zoom: Double) {
        mapRecenterTarget = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapRecenterZoom = zoom
        mapRecenterSignal = Int64(Date().timeIntervalSince1970 * 1000)
    }

    private func bootstrap() {
        Task { await refreshWatchlistFleet() }
        startPollingIfNeeded()
        if panel == .browse {
            scheduleBrowseRefresh(force: true)
        }
    }

    private func tearDown() {
        stopPolling()
        browseTask?.cancel()
        publishThrottleTask?.cancel()
        liveTickTask?.cancel()
        mqttCoordinator.setWatchlistConsumer(active: false, mmsis: [])
        fleetByMmsi = [:]
        vessels = []
        watchlistRows = []
        streamMode = .off
    }

    private func startPollingIfNeeded() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval: TimeInterval = self?.mqttCoordinator.isConnected == true ? 600 : AppConfig.aisRestPollIntervalSeconds
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self, self.sceneActive, self.premiumActive else { continue }
                await self.refreshWatchlistFleet()
            }
        }
    }

    private func startLiveTickIfNeeded() {
        liveTickTask?.cancel()
        liveTickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.tickLiveMapRender()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func refreshWatchlistFleet() async {
        guard premiumActive else { return }
        let mmsis = Set(watchlistStore.entries.map(\.mmsi))
        guard !isRefreshingFleet else { return }
        isRefreshingFleet = true
        if !mmsis.isEmpty { isLoading = true }
        do {
            let fleet = try await repository.fetchVesselsForMmsis(mmsis)
            fleetByMmsi = Dictionary(uniqueKeysWithValues: fleet.map { ($0.mmsi, $0) })
            lastError = nil
            syncMqttSubscriptions()
            publishUi()
        } catch {
            lastError = error.localizedDescription
            updateStreamMode()
        }
        isLoading = false
        isRefreshingFleet = false
    }

    private func scheduleBrowseRefresh(force: Bool = false) {
        browseTask?.cancel()
        browseTask = Task { [weak self] in
            if !force {
                try? await Task.sleep(nanoseconds: AisTrackConfig.browseDebounceMs * 1_000_000)
            }
            guard let self, self.sceneActive, self.premiumActive, self.panel == .browse else { return }
            guard let viewport = self.lastViewport else { return }
            self.browseLoading = true
            do {
                let radius = viewport.queryRadiusKm()
                let nearby = try await self.repository.fetchNearbyBrowseItems(
                    latitude: viewport.center.latitude,
                    longitude: viewport.centerLongitude,
                    radiusKm: radius
                )
                self.browseItems = nearby
                await self.refreshBrowseMerged()
            } catch {
                self.browseItems = []
                await self.refreshBrowseMerged()
            }
            self.browseLoading = false
        }
    }

    private func refreshBrowseMerged() async {
        let q = browseSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let nearbyFiltered = filterBrowseItems(browseItems, query: q)
        var merged: [Int: AisBrowseItem] = [:]
        for item in nearbyFiltered { merged[item.mmsi] = item }
        if q.count >= AisTrackConfig.globalSearchMinChars {
            if let global = try? await repository.searchVesselsMetadata(query: q) {
                for item in global where merged[item.mmsi] == nil {
                    merged[item.mmsi] = item
                }
            }
        }
        browseItems = merged.values.sorted {
            $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel) == .orderedAscending
        }
        publishUi()
    }

    private func filterBrowseItems(_ items: [AisBrowseItem], query: String) -> [AisBrowseItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { item in
            [String(item.mmsi), item.name, item.callSign]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()
                .contains(q)
        }
    }

    private func handleMqttMessage(topic: String, payload: Data) {
        guard sceneActive, premiumActive else { return }
        guard let update = mqttParser.parseMessage(topic: topic, payload: payload) else { return }
        guard let prev = fleetByMmsi[update.mmsi] else { return }
        let merged = prev.applyingMqttUpdate(update)
        guard merged != prev else { return }
        fleetByMmsi[update.mmsi] = merged
        scheduleThrottledPublish()
    }

    private func scheduleThrottledPublish() {
        guard publishThrottleTask == nil || publishThrottleTask?.isCancelled == true else { return }
        publishThrottleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            self?.publishUi()
        }
    }

    private func syncMqttSubscriptions() {
        guard sceneActive, premiumActive else {
            mqttCoordinator.setWatchlistConsumer(active: false, mmsis: [])
            return
        }
        mqttCoordinator.setWatchlistConsumer(
            active: true,
            mmsis: Set(watchlistStore.entries.map(\.mmsi))
        )
    }

    private func publishUi() {
        let rows = watchlistStore.entries.map { entry in
            AisWatchlistRow(entry: entry, vessel: fleetByMmsi[entry.mmsi])
        }
        watchlistRows = filterWatchlistRows(rows)
        if panel == .watchlist {
            vessels = watchlistRows.compactMap(\.vessel).filter {
                $0.latitude.isFinite && $0.longitude.isFinite
            }
        } else {
            vessels = browseItems.compactMap { item in
                guard let lat = item.latitude, let lon = item.longitude,
                      lat.isFinite, lon.isFinite else { return nil }
                return AisVesselDisplay(
                    mmsi: item.mmsi,
                    latitude: lat,
                    longitude: lon,
                    name: item.name,
                    callSign: item.callSign,
                    destination: nil,
                    imo: nil,
                    draughtTenthsM: nil,
                    shipTypeCode: nil,
                    etaRaw: nil,
                    navStatusCode: nil,
                    sogKn: item.sogKn,
                    cogDeg: nil,
                    headingDeg: nil,
                    lastSeenEpochMs: item.lastSeenEpochMs
                )
            }
        }
        mapRenderGeneration += 1
        updateStreamMode()
    }

    private func filterWatchlistRows(_ rows: [AisWatchlistRow]) -> [AisWatchlistRow] {
        let q = watchlistSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredBySearch: [AisWatchlistRow]
        if q.isEmpty {
            filteredBySearch = rows
        } else {
            filteredBySearch = rows.filter { row in
                [String(row.entry.mmsi), row.entry.nickname, row.entry.name, row.entry.callSign]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .lowercased()
                    .contains(q)
            }
        }
        switch listFilter {
        case .all:
            return filteredBySearch
        case .active:
            return filteredBySearch.filter { row in
                row.vessel.map { AisVesselMotion.isActive($0) } == true
            }
        case .stale:
            return filteredBySearch.filter { row in
                row.vessel.map { !AisVesselMotion.isActive($0) } != false
            }
        }
    }

    private func updateStreamMode() {
        guard sceneActive, premiumActive else {
            streamMode = .off
            return
        }
        let hasFleet = !fleetByMmsi.isEmpty
        if hasFleet && isLoading {
            streamMode = .connecting
        } else if !hasFleet && lastError != nil {
            streamMode = .error
        } else if mqttCoordinator.isConnected && hasFleet {
            streamMode = .live
        } else if hasFleet {
            streamMode = .restOnly
        } else {
            streamMode = .connecting
        }
    }
}
