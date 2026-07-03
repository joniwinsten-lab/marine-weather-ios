import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            MainTabView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showSplash {
                SplashBrandedView {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task {
            await MapTileWarmup.warm(
                lat: AppConfig.defaultLatitude,
                lon: AppConfig.defaultLongitude
            )
        }
    }
}

#Preview {
    ContentView()
}
