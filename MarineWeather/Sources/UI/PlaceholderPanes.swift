import SwiftUI

struct FeaturePlaceholderPane: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "hammer")
        } description: {
            Text(message)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PremiumPlaceholderPane: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "lock.fill")
        } description: {
            Text(message)
        } actions: {
            Text("Products: \(AppConfig.billingRoutePremiumLifetime), \(AppConfig.billingRoutePremiumMonthly)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
