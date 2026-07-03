import Foundation
import Network
import Observation

/// Observes validated internet (Wi‑Fi or cellular), matching Android `NetworkConnectivityMonitor`.
@MainActor
@Observable
final class NetworkConnectivityMonitor {
    static let shared = NetworkConnectivityMonitor()

    private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "fi.veneappi.MarineWeather.connectivity")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }
}
