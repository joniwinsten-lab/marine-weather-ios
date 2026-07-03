import Foundation

/// Shared app services (Android `AppContainer`).
@MainActor
enum AppServices {
    static let shared = AppServicesContainer()
}

@MainActor
final class AppServicesContainer {
    let watchlistStore = AisWatchlistStore()
    let aisRepository = DigitrafficAisRepository()
    let aisMqttCoordinator = AisMqttCoordinator()

    var mqttCoordinator: AisMqttCoordinator { aisMqttCoordinator }
}
