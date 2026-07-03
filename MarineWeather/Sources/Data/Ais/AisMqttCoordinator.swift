import Foundation
import os

/// Single Digitraffic MQTT connection shared by map overlay and Seuranta tab.
/// Subscriptions are the union of active consumers' MMSI sets.
@MainActor
final class AisMqttCoordinator {
    private let log = Logger(subsystem: "fi.veneappi.MarineWeather", category: "AisMqttCoordinator")
    private let client = DigitrafficAisMqttClient()
    private lazy var subscriptionManager = AisSubscriptionManager(mqttClient: client)

    private var viewportActive = false
    private var watchlistActive = false
    private var viewportMmsis = Set<Int>()
    private var watchlistMmsis = Set<Int>()
    private var reconcileTask: Task<Void, Never>?
    private var messageHandlers: [UUID: (AisMqttInboundMessage) -> Void] = [:]
    private var messagePumpTask: Task<Void, Never>?

    var connectionState: AisMqttConnectionState { client.connectionState }
    var messages: AsyncStream<AisMqttInboundMessage> { client.messages }
    var connectionStates: AsyncStream<AisMqttConnectionState> { client.connectionStates }
    var isConnected: Bool { client.isConnected }

    init() {
        messagePumpTask = Task { [weak self] in
            guard let self else { return }
            for await message in self.client.messages {
                for handler in self.messageHandlers.values {
                    handler(message)
                }
            }
        }
    }

    @discardableResult
    func addMessageHandler(_ handler: @escaping (AisMqttInboundMessage) -> Void) -> UUID {
        let id = UUID()
        messageHandlers[id] = handler
        return id
    }

    func removeMessageHandler(_ id: UUID) {
        messageHandlers.removeValue(forKey: id)
    }

    func setViewportConsumer(active: Bool, mmsis: Set<Int>) {
        reconcileTask?.cancel()
        reconcileTask = Task { @MainActor in
            viewportActive = active
            viewportMmsis = mmsis
            await reconcileLocked()
        }
    }

    func setWatchlistConsumer(active: Bool, mmsis: Set<Int>) {
        reconcileTask?.cancel()
        reconcileTask = Task { @MainActor in
            watchlistActive = active
            watchlistMmsis = mmsis
            await reconcileLocked()
        }
    }

    func disconnectAll() {
        reconcileTask?.cancel()
        reconcileTask = Task { @MainActor in
            viewportActive = false
            watchlistActive = false
            viewportMmsis = []
            watchlistMmsis = []
            subscriptionManager.clearLocalState()
            client.disconnect()
        }
    }

    private func reconcileLocked() async {
        let shouldConnect = viewportActive || watchlistActive
        guard shouldConnect else {
            subscriptionManager.clearLocalState()
            client.disconnect()
            return
        }

        var union = Set<Int>()
        if viewportActive { union.formUnion(viewportMmsis) }
        if watchlistActive { union.formUnion(watchlistMmsis) }

        do {
            if !client.isConnected {
                try await client.connect()
            }
            subscriptionManager.sync(wanted: union)
            log.info("subscriptions=\(self.subscriptionManager.subscribedCount) union=\(union.count)")
        } catch {
            log.warning("mqtt reconcile failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
