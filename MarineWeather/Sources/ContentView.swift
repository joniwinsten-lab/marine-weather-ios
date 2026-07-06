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
                    AppStoreReviewCoordinator.onAppUiReady()
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            #if DEBUG
            if ScreenshotLaunch.iapReview {
                showSplash = false
            }
            #endif
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
