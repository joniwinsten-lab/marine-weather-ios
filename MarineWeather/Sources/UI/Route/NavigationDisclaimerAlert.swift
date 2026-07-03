import SwiftUI

/// Planning-only navigation disclaimer (Android `disclaimer_nav_*` + RouteMapTopOverlay info).
struct NavigationDisclaimerAlert: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "disclaimer_nav_title"),
                isPresented: $isPresented
            ) {
                Button(String(localized: "disclaimer_nav_ok"), role: .cancel) {}
            } message: {
                Text(String(localized: "disclaimer_nav_body"))
            }
    }
}

extension View {
    func navigationDisclaimerAlert(isPresented: Binding<Bool>) -> some View {
        modifier(NavigationDisclaimerAlert(isPresented: isPresented))
    }
}
