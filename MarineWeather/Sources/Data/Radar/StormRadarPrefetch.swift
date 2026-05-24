import Foundation

struct StormRadarPrefetch: Equatable {
    static let staleAfterMs: Int64 = 5 * 60 * 1000

    let locationKey: String
    let fetchedAtMs: Int64
    let frames: [RadarAnimationFrame]
    let latestOverlay: ActiveRadarOverlay?
    let sourceLabel: String
    let lightningStrikes: [LightningStrike]
    let lightningFetchedAtMs: Int64?
    let lightningError: String?

    func isExpired(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> Bool {
        nowMs - fetchedAtMs > Self.staleAfterMs
    }

    static func locationKey(lat: Double, lon: Double) -> String {
        String(format: "%.2f_%.2f", lat, lon)
    }
}
