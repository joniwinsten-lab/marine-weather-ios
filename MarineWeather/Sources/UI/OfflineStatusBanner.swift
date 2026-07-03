import SwiftUI

struct OfflineStatusBanner: View {
    let status: WeatherConnectivityStatus

    var body: some View {
        if let message = bannerMessage {
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(backgroundColor)
        }
    }

    private var backgroundColor: Color {
        if !status.isOnline || status.allSourcesFailed || status.staleLevel == .hard {
            return Color(.systemRed).opacity(0.15)
        }
        return Color(.systemOrange).opacity(0.15)
    }

    private var foregroundColor: Color {
        if !status.isOnline || status.allSourcesFailed || status.staleLevel == .hard {
            return Color(.systemRed)
        }
        return Color(.systemOrange)
    }

    private var bannerMessage: String? {
        if status.allSourcesFailed && !status.isOnline {
            return String(localized: "offline_banner_no_data")
        }
        if status.allSourcesFailed {
            return String(localized: "offline_banner_load_failed")
        }
        let fetchedLabel = status.oldestFetchedUtc.map(Self.formatFetched)

        if !status.isOnline {
            if let fetchedLabel {
                return String(format: String(localized: "offline_banner_offline_cached"), fetchedLabel)
            }
            return String(localized: "offline_banner_offline_no_cache")
        }
        if status.anyFromCache, let fetchedLabel {
            return String(format: String(localized: "offline_banner_cache_fallback"), fetchedLabel)
        }
        switch status.staleLevel {
        case .hard:
            if let fetchedLabel {
                return String(format: String(localized: "offline_banner_stale_hard"), fetchedLabel)
            }
            return String(localized: "offline_banner_stale_hard_short")
        case .soft:
            if let fetchedLabel {
                return String(format: String(localized: "offline_banner_stale_soft"), fetchedLabel)
            }
            return String(localized: "offline_banner_stale_soft_short")
        case .fresh:
            return nil
        }
    }

    private static func formatFetched(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
