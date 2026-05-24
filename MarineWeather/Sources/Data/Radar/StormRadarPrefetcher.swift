import Foundation

actor StormRadarPrefetcher {
    private var cache: StormRadarPrefetch?

    func peek(lat: Double, lon: Double) -> StormRadarPrefetch? {
        guard let entry = cache,
              entry.locationKey == StormRadarPrefetch.locationKey(lat: lat, lon: lon) else {
            return nil
        }
        return entry
    }

    func fetchAndCache(lat: Double, lon: Double) async -> StormRadarPrefetch {
        let key = StormRadarPrefetch.locationKey(lat: lat, lon: lon)
        if let entry = cache, entry.locationKey == key, !entry.isExpired() {
            return entry
        }

        let latestOverlay = await CompositeRadarRepository.loadActiveOverlay(lat: lat, lon: lon)
        let frames = await CompositeRadarRepository.loadAnimation(lat: lat, lon: lon)
        let lightningResult = await CompositeLightningRepository.fetchMergedStrikes()
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let bundle = StormRadarPrefetch(
            locationKey: key,
            fetchedAtMs: now,
            frames: frames,
            latestOverlay: latestOverlay,
            sourceLabel: latestOverlay.sourceLabel,
            lightningStrikes: (try? lightningResult.get()) ?? [],
            lightningFetchedAtMs: now,
            lightningError: {
                if case .failure(let e) = lightningResult { return e.localizedDescription }
                return nil
            }()
        )
        cache = bundle
        return bundle
    }
}
