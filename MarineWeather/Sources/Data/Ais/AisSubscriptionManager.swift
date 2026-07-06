import Foundation

/// Keeps MQTT topic subscriptions aligned with viewport MMSI set.
@MainActor
final class AisSubscriptionManager {
    private let mqttClient: DigitrafficAisMqttClient
    private var subscribedMmsis = Set<Int>()

    var subscribedCount: Int { subscribedMmsis.count }

    init(mqttClient: DigitrafficAisMqttClient) {
        self.mqttClient = mqttClient
    }

    func sync(wanted: Set<Int>) async {
        guard mqttClient.isConnected else { return }
        let toRemove = subscribedMmsis.subtracting(wanted)
        let toAdd = wanted.subtracting(subscribedMmsis)
        for mmsi in toRemove {
            mqttClient.unsubscribeVessel(mmsi: mmsi)
            subscribedMmsis.remove(mmsi)
        }
        for (index, mmsi) in toAdd.enumerated() {
            mqttClient.subscribeVessel(mmsi: mmsi)
            subscribedMmsis.insert(mmsi)
            if index % 8 == 7 {
                await Task.yield()
            }
        }
    }

    /// Clears local tracking after broker disconnect (broker drops subscriptions).
    func clearLocalState() {
        subscribedMmsis.removeAll()
    }

    /// Pure delta for tests.
    static func subscriptionDelta(
        subscribed: Set<Int>,
        wanted: Set<Int>
    ) -> (remove: Set<Int>, add: Set<Int>) {
        (subscribed.subtracting(wanted), wanted.subtracting(subscribed))
    }
}
