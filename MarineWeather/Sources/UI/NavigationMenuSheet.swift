import SwiftUI

/// Compact top bar with hamburger menu (iPhone).
struct CompactNavigationBar: View {
    @Binding var selection: MainTab
    @Binding var showMenu: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button {
                showMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "nav_menu"))

            Image(systemName: selection.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Text(selection.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }
}

/// Full-screen section picker opened from the compact navigation bar.
struct NavigationMenuSheet: View {
    @Binding var selection: MainTab
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(MainTab.allCases) { tab in
                Button {
                    selection = tab
                    isPresented = false
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: tab.systemImage)
                            .frame(width: 24)
                            .foregroundStyle(selection == tab ? Color.accentColor : Color.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tab.title)
                                .font(.body.weight(selection == tab ? .semibold : .regular))
                            if tab.isPremium {
                                Text(String(localized: "premium_label"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        if selection == tab {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(String(localized: "nav_menu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "disclaimer_nav_ok")) {
                        isPresented = false
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
