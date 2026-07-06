import Foundation
import UIKit
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
        mqttConnectionTask = Task { @MainActor [weak self] in
            guard let self else { return }
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
            startPollingIfNeeded()
        } else {
            tearDown()
        }
    }

    /// Ensure a viewport exists (map center fallback) and fetch AIS for the visible area.
    func primeViewport(latitude: Double, longitude: Double, zoom: Double = AppConfig.defaultCompareZoom) {
        if lastViewport == nil {
            lastViewport = .aroundCenter(latitude: latitude, longitude: longitude, zoom: zoom)
        }
        guard isEnabled else { return }
        Task { await refreshForViewportChange() }
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

    /// Replace fallback viewport with the live map bounds and fetch when AIS is on.
    func applyMapViewport(_ viewport: MapViewport) {
        lastViewport = viewport
        guard isEnabled else { return }
        Task { await refreshForViewportChange() }
    }

    func ensureFallbackViewport(
        latitude: Double,
        longitude: Double,
        zoom: Double = AppConfig.defaultCompareZoom
    ) {
        primeViewport(latitude: latitude, longitude: longitude, zoom: zoom)
    }

    func refreshNow() {
        guard isEnabled else { return }
        Task { await refreshForViewportChange() }
    }

    func tickLiveMapRender() {
        guard isEnabled, appIsActive else { return }
        guard AisVesselMotion.needsLiveMapTick(vessels: vessels) else { return }
        mapRenderGeneration += 1
    }

    // MARK: - Private

    private func bootstrap() {
        startPollingIfNeeded()
        if lastViewport != nil {
            Task { await refreshForViewportChange() }
        }
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
        let debounceSeconds = fleetByMmsi.isEmpty ? 0 : AppConfig.aisViewportRefreshDebounceSeconds
        viewportTask = Task { [weak self] in
            if debounceSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(debounceSeconds * 1_000_000_000))
            }
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
        updateStreamMode()
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
        updateStreamMode()
    }

    private func startPollingIfNeeded() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = await MainActor.run { self?.pollIntervalSeconds() ?? AppConfig.aisRestPollIntervalSeconds }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self, self.isEnabled, self.appIsActive else { continue }
                await self.refreshForViewportChange()
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
        publishThrottleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: AisMqttConfig.mapPublishThrottleMs * 1_000_000)
            self?.publishMap()
        }
    }

    private func syncMqttSubscriptions() {
        guard isEnabled, appIsActive else {
            mqttCoordinator.setViewportConsumer(active: false, mmsis: [])
            return
        }
        guard AppConfig.aisMqttLiveOnPhone || UIDevice.current.userInterfaceIdiom != .phone else {
            mqttCoordinator.setViewportConsumer(active: false, mmsis: [])
            return
        }
        let mmsis = cappedMqttMmsis()
        guard !mmsis.isEmpty else {
            mqttCoordinator.setViewportConsumer(active: false, mmsis: [])
            return
        }
        mqttCoordinator.setViewportConsumer(active: true, mmsis: mmsis)
    }

    /// MQTT live updates for the nearest vessels only — avoids broker overload on phone.
    private func cappedMqttMmsis() -> Set<Int> {
        guard !fleetByMmsi.isEmpty else { return [] }
        let ranked: [AisVesselDisplay]
        if let viewport = lastViewport {
            ranked = fleetByMmsi.values.sorted { lhs, rhs in
                let d0 = GeoMath.haversineMeters(
                    lat1: viewport.center.latitude, lon1: viewport.center.longitude,
                    lat2: lhs.latitude, lon2: lhs.longitude
                )
                let d1 = GeoMath.haversineMeters(
                    lat1: viewport.center.latitude, lon1: viewport.center.longitude,
                    lat2: rhs.latitude, lon2: rhs.longitude
                )
                return d0 < d1
            }
        } else {
            ranked = Array(fleetByMmsi.values)
        }
        return Set(ranked.prefix(AppConfig.aisMaxMqttSubscriptions).map(\.mmsi))
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
        if lastViewport == nil || isLoading {
            streamMode = .connecting
            return
        }
        if fleetByMmsi.isEmpty, lastError != nil {
            streamMode = .error
            return
        }
        if mqttCoordinator.isConnected, AppConfig.aisMqttLiveOnPhone || UIDevice.current.userInterfaceIdiom != .phone {
            streamMode = .live
        } else {
            streamMode = .restOnly
        }
    }
}
