import Foundation
import Observation

/// UserDefaults JSON persistence for AIS watchlist (Android `AisWatchlistRepository`).
@MainActor
@Observable
final class AisWatchlistStore {
    private(set) var entries: [AisWatchlistEntry] = []

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = Self.decodeEntries(defaults.string(forKey: AisTrackConfig.watchlistStorageKey))
    }

    func addEntry(
        mmsi: Int,
        nickname: String? = nil,
        name: String? = nil,
        callSign: String? = nil,
        source: AddedSource = .manual
    ) throws {
        if entries.contains(where: { $0.mmsi == mmsi }) {
            throw WatchlistStoreError.alreadyExists(mmsi: mmsi)
        }
        if entries.count >= AisTrackConfig.maxWatchlistVessels {
            throw WatchlistStoreError.full(max: AisTrackConfig.maxWatchlistVessels)
        }
        let entry = AisWatchlistEntry(
            mmsi: mmsi,
            nickname: nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            callSign: callSign?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            destination: nil,
            addedAtEpochMs: Int64(Date().timeIntervalSince1970 * 1000),
            addedSource: source.rawValue
        )
        entries.append(entry)
        persist()
    }

    func removeEntry(mmsi: Int) {
        entries.removeAll { $0.mmsi == mmsi }
        persist()
    }

    func updateNickname(mmsi: Int, nickname: String?) {
        guard let index = entries.firstIndex(where: { $0.mmsi == mmsi }) else { return }
        var entry = entries[index]
        entry.nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        entries[index] = entry
        persist()
    }

    private func persist() {
        let payload = (try? encoder.encode(entries)) ?? Data()
        defaults.set(String(data: payload, encoding: .utf8), forKey: AisTrackConfig.watchlistStorageKey)
    }

    private static func decodeEntries(_ raw: String?) -> [AisWatchlistEntry] {
        guard let raw, !raw.isEmpty, let data = raw.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([AisWatchlistEntry].self, from: data))?
            .filter { $0.mmsi > 0 } ?? []
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
