import SwiftUI

/// Single day / source cell in the 12-day wind table (compact — unit shown in table header only).
struct WindOutlookCell: View {
    let point: UnifiedTimePoint?
    let windUnit: WindUnit

    var body: some View {
        VStack(spacing: 0) {
            if let point, let speedMs = point.windSpeedMs {
                Text(compactSpeed(speedMs))
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if let from = point.windFromDeg {
                    Text("\(Int(from.rounded()))°")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let gustMs = point.windGustMs {
                    Text(String(format: String(localized: "weather_gust_short"), compactSpeed(gustMs)))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            } else {
                Text(String(localized: "route_ext_no_forecast"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
    }

    private func compactSpeed(_ ms: Double) -> String {
        if windUnit == .knots {
            return String(format: "%.0f", ms.msToKnots)
        }
        return String(format: "%.1f", ms)
    }
}
