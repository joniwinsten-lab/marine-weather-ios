import SwiftUI

@main
struct MarineWeatherApp: App {
    init() {
        MapHTTPConfiguration.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await PremiumAccess.shared.start()
                }
        }
    }
}
