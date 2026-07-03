import Foundation

enum AisTrackConfig {
    static let maxWatchlistVessels = 50
    static let globalSearchMinChars = 2
    static let globalSearchMax = 40
    static let browseDebounceMs: UInt64 = 700
    static let watchlistStorageKey = "mw_ais_watchlist_v1"
    static let focusVesselZoom: Double = 11.0
}

enum AddedSource: String, Codable, Sendable {
    case mapTap = "MAP_TAP"
    case search = "SEARCH"
    case manual = "MANUAL"
}

struct AisWatchlistEntry: Codable, Equatable, Identifiable, Sendable {
    var id: Int { mmsi }
    let mmsi: Int
    var nickname: String?
    var name: String?
    var callSign: String?
    var destination: String?
    let addedAtEpochMs: Int64
    let addedSource: String

    var displayLabel: String {
        let nick = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !nick.isEmpty { return nick }
        let vesselName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !vesselName.isEmpty { return vesselName }
        return "MMSI \(mmsi)"
    }
}

enum AisBrowseSource: String, Sendable {
    case nearby = "NEARBY"
    case global = "GLOBAL"
}

struct AisBrowseItem: Equatable, Identifiable, Sendable {
    var id: Int { mmsi }
    let mmsi: Int
    let name: String?
    let callSign: String?
    let latitude: Double?
    let longitude: Double?
    let sogKn: Double?
    let lastSeenEpochMs: Int64?
    let source: AisBrowseSource

    var displayLabel: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "MMSI \(mmsi)" : trimmed
    }
}

enum AisTrackListFilter: String, CaseIterable, Sendable {
    case all
    case active
    case stale
}

enum AisTrackPanel: String, Hashable, Sendable {
    case watchlist
    case browse
}

struct AisWatchlistRow: Equatable, Sendable {
    let entry: AisWatchlistEntry
    let vessel: AisVesselDisplay?
}

enum WatchlistStoreError: LocalizedError {
    case alreadyExists(mmsi: Int)
    case full(max: Int)

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let mmsi):
            return "MMSI \(mmsi) already in watchlist"
        case .full(let max):
            return String(format: String(localized: "track_watchlist_full"), max)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
