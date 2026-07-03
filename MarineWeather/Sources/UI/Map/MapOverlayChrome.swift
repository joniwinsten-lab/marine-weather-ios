import SwiftUI

/// Shared chrome for map overlay chips and round controls (readable on busy charts).
enum MapOverlayChrome {
    static func chipLabel<Content: View>(
        isOn: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isOn ? Color.accentColor : Color.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(chipBackground(isOn: isOn))
    }

    static func circleIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.primary)
            .frame(width: 36, height: 36)
            .background(circleBackground())
    }

    private static func chipBackground(isOn: Bool) -> some View {
        Capsule()
            .fill(Color(.systemBackground).opacity(0.92))
            .overlay {
                Capsule()
                    .strokeBorder(
                        isOn ? Color.accentColor : Color.primary.opacity(0.22),
                        lineWidth: isOn ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
    }

    private static func circleBackground() -> some View {
        Circle()
            .fill(Color(.systemBackground).opacity(0.92))
            .overlay {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
    }
}
