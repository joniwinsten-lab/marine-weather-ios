import SwiftUI

/// Simple map scale bar from zoom + latitude (Web Mercator).
struct MapScaleBarView: View {
    let latitude: Double
    let zoomLevel: Double
    var maxBarWidth: CGFloat = 88

    var body: some View {
        let metrics = Self.metrics(latitude: latitude, zoom: zoomLevel, maxBarWidth: maxBarWidth)
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.primary.opacity(0.85))
                .frame(width: metrics.barWidth, height: 3)
            Text(metrics.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.primary.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
        }
    }

    static func metrics(latitude: Double, zoom: Double, maxBarWidth: CGFloat) -> (label: String, barWidth: CGFloat) {
        let clampedZoom = min(max(zoom, 0), 22)
        let latRad = latitude * .pi / 180.0
        let metersPerPixel = cos(latRad) * 2.0 * .pi * 6_378_137.0 / (256.0 * pow(2.0, clampedZoom))
        guard metersPerPixel.isFinite, metersPerPixel > 0 else {
            return ("—", maxBarWidth * 0.5)
        }
        let maxMeters = Double(maxBarWidth) * metersPerPixel
        let niceMeters = niceDistanceMeters(maxMeters)
        let width = CGFloat(niceMeters / metersPerPixel)
        return (formatDistance(niceMeters), min(max(width, 24), maxBarWidth))
    }

    private static func niceDistanceMeters(_ maxMeters: Double) -> Double {
        let candidates: [Double] = [
            10, 20, 50, 100, 200, 500,
            1_000, 2_000, 5_000, 10_000, 20_000, 50_000, 100_000, 200_000,
        ]
        return candidates.last { $0 <= maxMeters } ?? 10
    }

    private static func formatDistance(_ meters: Double) -> String {
        if meters >= 1_000 {
            let km = meters / 1_000
            if km >= 10 {
                return String(format: "%.0f km", km)
            }
            return String(format: "%.1f km", km)
        }
        return String(format: "%.0f m", meters)
    }
}
