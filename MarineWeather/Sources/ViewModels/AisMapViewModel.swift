import Foundation
import os

/// Premium AIS overlay: REST bootstrap + shared Digitraffic MQTT (viewport MMSI subscriptions).
@MainActor
@Observable
final class AisMapViewModel {
    private let log = Logger(subsystem: "fi.veneappi.MarineWeather", category: "AisMapViewModel")
    private let repository: DigitrafficAisRepository
    private let mqttCoordinator: AisMqttCoordinator
    private let mqttParser = AisMqttMessageParser()

    private(set) var isEnabled = false
    private(set) var vessels: [AisVesselDisplay] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var streamMode: AisStreamMode = .off
    private(set) var mapRenderGeneration = 0

    private var pollTask: Task<Void, Never>?
    private var viewportTask: Task<Void, Never>?
    private var mqttConnectionTask: Task<Void, Never>?
    private var publishThrottleTask: Task<Void, Never>?
    private var fleetByMmsi: [Int: AisVesselDisplay] = [:]
    private var lastViewport: MapViewport?
    private var appIsActive = true
    private var pollCycle = 0
    private var isRefreshing = false

    init(
        repository: DigitrafficAisRepository? = nil,
        mqttCoordinator: AisMqttCoordinator? = nil
    ) {
        self.repository = repository ?? AppServices.shared.aisRepository
        self.mqttCoordinator = mqttCoordinator ?? AppServices.shared.mqttCoordinator
        startMqttObservers()
    }

    private func startMqttObservers() {
        mqttHandlerId = mqttCoordinator.addMessageHandler { [weak self] message in
            Task { @MainActor in
                await self?.handleMqttMessage(topic: message.topic, payload: message.payload)
            }
        }
        mqttConnectionTask = Task {
            for await state in mqttCoordinator.connectionStates {
                switch state {
                case .connected:
                    self.syncMqttSubscriptions()
                    self.updateStreamMode()
                case .disconnected, .error:
                    self.updateStreamMode()
                case .connecting:
                    break
                }
            }
        }
    }

    private var mqttHandlerId: UUID?

    func setSceneActive(_ active: Bool) {
        guard appIsActive != active else { return }
        appIsActive = active
        guard isEnabled else { return }
        if active {
            streamMode = .connecting
            bootstrap()
        } else {
            stopPolling()
            viewportTask?.cancel()
            viewportTask = nil
            mqttCoordinator.setViewportConsumer(active: false, mmsis: [])
            streamMode = .off
        }
    }

    func setEnabled(_ enabled: Bool, premium: Bool) {
        guard premium else {
            tearDown()
            isEnabled = false
            return
        }
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        if enabled {
            streamMode = .connecting
            lastError = nil
            pollCycle = 0
            bootstrap()
        } else {
            tearDown()
        }
    }

    func toggle(premium: Bool) {
        setEnabled(!isEnabled, premium: premium)
    }

    func updateViewport(_ viewport: MapViewport) {
        let regionChanged = lastViewport.map { viewport.regionChangedSignificantly($0) } ?? true
        lastViewport = viewport
        guard isEnabled else { return }
        if !regionChanged, !fleetByMmsi.isEmpty { return }
        scheduleViewportRefresh()
    }

    func ensureFallbackViewport(
        latitude: Double,
        longitude: Double,
        zoom: Double = AppConfig.defaultCompareZoom
    ) {
        guard lastViewport == nil else { return }
        lastViewport = MapViewport.aroundCenter(latitude: latitude, longitude: longitude, zoom: zoom)
        if isEnabled {
            Task { await refreshFromNetwork(fullFetch: true) }
        }
    }

    func refreshNow() {
        guard isEnabled else { return }
        Task { await refreshFromNetwork(fullFetch: pollCycle == 0) }
    }

    func tickLiveMapRender() {
        guard isEnabled, appIsActive else { return }
        guard AisVesselMotion.needsLiveMapTick(vessels: vessels) else { return }
        mapRenderGeneration += 1
    }

    // MARK: - Private

    private func bootstrap() {
        Task { await refreshFromNetwork(fullFetch: true) }
        startPollingIfNeeded()
    }

    private func tearDown() {
        streamMode = .off
        lastError = nil
        stopPolling()
        viewportTask?.cancel()
        viewportTask = nil
        publishThrottleTask?.cancel()
        publishThrottleTask = nil
        mqttCoordinator.setViewportConsumer(active: false, mmsis: [])
        fleetByMmsi = [:]
        pollCycle = 0
        vessels = []
    }

    private func scheduleViewportRefresh() {
        viewportTask?.cancel()
        viewportTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(AppConfig.aisViewportRefreshDebounceSeconds * 1_000_000_000))
            guard !Task.isCancelled, let self, self.isEnabled else { return }
            await self.refreshForViewportChange()
        }
    }

    private func refreshForViewportChange() async {
        guard isEnabled, let viewport = lastViewport else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        isLoading = true
        let started = Date()
        do {
            let fleet = try await repository.fetchVesselsInViewport(viewport)
            let filtered = AisViewportFilter.filter(fleet, viewport: viewport)
            guard isEnabled else { return }
            lastError = nil
            fleetByMmsi = Dictionary(uniqueKeysWithValues: filtered.map { ($0.mmsi, $0) })
            publishMap()
            pollCycle += 1
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
            log.info("viewport loaded \(filtered.count) vessels in \(elapsedMs)ms (r=\(viewport.queryRadiusKm())km)")
            syncMqttSubscriptions()
        } catch {
            guard isEnabled else { return }
            lastError = error.localizedDescription
            if fleetByMmsi.isEmpty {
                streamMode = .error
            } else {
                updateStreamMode()
            }
            log.warning("viewport fetch failed: \(self.lastError ?? "unknown", privacy: .public)")
        }
        isLoading = false
    }

    private func startPollingIfNeeded() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = await MainActor.run { self?.pollIntervalSeconds() ?? AppConfig.aisRestPollIntervalSeconds }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self, self.isEnabled, self.appIsActive else { continue }
                if self.mqttCoordinator.isConnected {
                    await self.refreshFromNetwork(fullFetch: true)
                } else {
                    let fullFetch = self.pollCycle == 0
                        || self.pollCycle % AppConfig.aisMetadataRefreshEveryNPolls == 0
                    await self.refreshFromNetwork(fullFetch: fullFetch)
                }
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pollIntervalSeconds() -> TimeInterval {
        mqttCoordinator.isConnected
            ? AppConfig.aisRestMetadataPollIntervalSecondsWhenMqttLive
            : AppConfig.aisRestPollIntervalSeconds
    }

    private func refreshFromNetwork(fullFetch: Bool) async {
        guard isEnabled, let viewport = lastViewport else { return }
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if !isLoading { isLoading = true }
        let started = Date()
        do {
            let updates: [AisVesselDisplay]
            if fullFetch {
                updates = try await repository.fetchAllVessels()
            } else {
                updates = try await repository.fetchLocationUpdates()
            }
            let filtered = AisViewportFilter.filter(updates, viewport: viewport)
            let fleet = mergeFleet(incoming: filtered, preserveMetadata: !fullFetch)
            guard isEnabled else { return }
            lastError = nil
            fleetByMmsi = Dictionary(uniqueKeysWithValues: fleet.map { ($0.mmsi, $0) })
            publishMap()
            pollCycle += 1
            let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
            log.info("loaded \(fleet.count) vessels (\(fullFetch ? "full" : "positions")) in \(elapsedMs)ms")
            syncMqttSubscriptions()
        } catch {
            guard isEnabled else { return }
            lastError = error.localizedDescription
            if fleetByMmsi.isEmpty {
                streamMode = .error
            } else {
                updateStreamMode()
            }
            log.warning("fetch failed: \(self.lastError ?? "unknown", privacy: .public)")
        }
        isLoading = false
    }

    private func mergeFleet(
        incoming: [AisVesselDisplay],
        preserveMetadata: Bool
    ) -> [AisVesselDisplay] {
        guard preserveMetadata else { return incoming }
        return incoming.map { vessel in
            guard let prev = fleetByMmsi[vessel.mmsi] else { return vessel }
            return AisVesselDisplay(
                mmsi: vessel.mmsi,
                latitude: vessel.latitude,
                longitude: vessel.longitude,
                name: prev.name,
                callSign: prev.callSign,
                destination: prev.destination,
                imo: prev.imo,
                draughtTenthsM: prev.draughtTenthsM,
                shipTypeCode: prev.shipTypeCode,
                etaRaw: prev.etaRaw,
                navStatusCode: vessel.navStatusCode,
                sogKn: vessel.sogKn,
                cogDeg: vessel.cogDeg,
                headingDeg: vessel.headingDeg,
                lastSeenEpochMs: vessel.lastSeenEpochMs
            )
        }
    }

    private func handleMqttMessage(topic: String, payload: Data) async {
        guard isEnabled else { return }
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
            try? await Task.sleep(nanoseconds: AisMqttConfig.mapPublishThrottleMs * 1_000_000)
            guard let self else { return }
            self.publishMap()
        }
    }

    private func syncMqttSubscriptions() {
        guard isEnabled, appIsActive else {
            mqttCoordinator.setViewportConsumer(active: false, mmsis: [])
            return
        }
        mqttCoordinator.setViewportConsumer(active: true, mmsis: Set(fleetByMmsi.keys))
    }

    private func publishMap() {
        vessels = Array(fleetByMmsi.values)
        mapRenderGeneration += 1
        updateStreamMode()
    }

    private func updateStreamMode() {
        guard isEnabled else {
            streamMode = .off
            return
        }
        switch (lastViewport, fleetByMmsi.isEmpty, isLoading, lastError, mqttCoordinator.isConnected) {
        case (nil, _, _, _, _), (_, true, true, _, _):
            streamMode = .connecting
        case (_, true, _, .some, _):
            streamMode = .error
        case (_, false, _, _, true):
            streamMode = .live
        case (_, false, _, _, false):
            streamMode = .restOnly
        default:
            streamMode = .connecting
        }
    }
}
