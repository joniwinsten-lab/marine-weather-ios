import SwiftUI

/// Maritime gradient splash with app icon and title (Android `SplashBranded.kt`).
struct SplashBrandedView: View {
    var onFinished: () -> Void

    @State private var contentOpacity: Double = 0

    private let topColor = Color(red: 7 / 255, green: 15 / 255, blue: 26 / 255)
    private let midColor = Color(red: 15 / 255, green: 40 / 255, blue: 68 / 255)
    private let bottomColor = Color(red: 21 / 255, green: 62 / 255, blue: 92 / 255)
    private let titleColor = Color(red: 232 / 255, green: 244 / 255, blue: 252 / 255)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [topColor, midColor, bottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppIconSplash")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)

                Text(String(localized: "app_display_name"))
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentOpacity)
        }
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeInOut(duration: 2.0)) {
                contentOpacity = 1
            }
            try? await Task.sleep(for: .milliseconds(2800))
            onFinished()
        }
    }
}
