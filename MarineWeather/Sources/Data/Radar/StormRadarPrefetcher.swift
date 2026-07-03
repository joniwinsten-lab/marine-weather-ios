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

    /// Radar timeline first; lightning is loaded separately so the map can render before WFS parsing.
    func fetchRadarAndCache(lat: Double, lon: Double) async -> StormRadarPrefetch {
        let key = StormRadarPrefetch.locationKey(lat: lat, lon: lon)
        if let entry = cache, entry.locationKey == key, !entry.isExpired(), !entry.frames.isEmpty {
            return entry
        }

        async let latestOverlay = loadActiveOverlay(lat: lat, lon: lon)
        async let frames = loadAnimation(lat: lat, lon: lon)
        let (overlay, frameList) = await (latestOverlay, frames)
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let bundle = StormRadarPrefetch(
            locationKey: key,
            fetchedAtMs: now,
            frames: frameList,
            latestOverlay: overlay,
            sourceLabel: overlay.sourceLabel,
            lightningStrikes: cache?.locationKey == key ? (cache?.lightningStrikes ?? []) : [],
            lightningFetchedAtMs: cache?.locationKey == key ? cache?.lightningFetchedAtMs : nil,
            lightningError: cache?.locationKey == key ? cache?.lightningError : nil
        )
        cache = bundle
        return bundle
    }

    func fetchLightningAndUpdateCache() async -> StormRadarPrefetch? {
        guard var entry = cache else { return nil }
        let lightningResult = await loadLightning()
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        entry = StormRadarPrefetch(
            locationKey: entry.locationKey,
            fetchedAtMs: entry.fetchedAtMs,
            frames: entry.frames,
            latestOverlay: entry.latestOverlay,
            sourceLabel: entry.sourceLabel,
            lightningStrikes: lightningResult.value ?? [],
            lightningFetchedAtMs: now,
            lightningError: lightningResult.error?.localizedDescription
        )
        cache = entry
        return entry
    }

    /// Full bundle (radar + lightning) for callers that need both at once.
    func fetchAndCache(lat: Double, lon: Double) async -> StormRadarPrefetch {
        let radar = await fetchRadarAndCache(lat: lat, lon: lon)
        if let withLightning = await fetchLightningAndUpdateCache() {
            return withLightning
        }
        return radar
    }

    private func loadActiveOverlay(lat: Double, lon: Double) async -> ActiveRadarOverlay {
        await CompositeRadarRepository.loadActiveOverlay(lat: lat, lon: lon)
    }

    private func loadAnimation(lat: Double, lon: Double) async -> [RadarAnimationFrame] {
        await CompositeRadarRepository.loadAnimation(lat: lat, lon: lon)
    }

    private func loadLightning() async -> (value: [LightningStrike]?, error: Error?) {
        let result = await CompositeLightningRepository.fetchMergedStrikes()
        switch result {
        case .success(let strikes):
            return (strikes, nil)
        case .failure(let error):
            return (nil, error)
        }
    }
}
