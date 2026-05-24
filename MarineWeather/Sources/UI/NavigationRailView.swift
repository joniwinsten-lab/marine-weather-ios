import SwiftUI

/// Android-style narrow navigation rail (icons + small labels).
struct NavigationRailView: View {
    @Binding var selection: MainTab

    var body: some View {
        VStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20))
                        Text(tab.railLabel)
                            .font(.system(size: 10))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        if tab.isPremium {
                            Text(String(localized: "premium_label"))
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(selection == tab ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 10)
                    .background(
                        selection == tab ? Color.accentColor.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(width: UiBreakpoints.navigationRailWidth)
        .background(Color(.secondarySystemBackground))
    }
}

struct AttributionFooter: View {
    @State private var showAttribution = false

    var body: some View {
        HStack {
            Spacer()
            Button(String(localized: "attribution_open")) {
                showAttribution = true
            }
            .font(.caption2)
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
        .sheet(isPresented: $showAttribution) {
            AttributionDialogView()
        }
    }
}
