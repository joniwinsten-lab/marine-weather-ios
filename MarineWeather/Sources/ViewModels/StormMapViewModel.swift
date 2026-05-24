import CoreLocation
import Foundation
import Observation

struct StormMapUiState: Equatable {
    var radarEnabled = true
    var lightningEnabled = true
    var radarOverlay: ActiveRadarOverlay?
    var radarAnimationFrames: [RadarAnimationFrame] = []
    var radarAnimationPlaying = false
    var radarAnimationIndex = StormRadarTimeline.nowFrameIndex
    var radarSourceLabel = "FMI"
    var allLightningStrikes: [LightningStrike] = []
    var visibleLightningStrikes: [LightningStrike] = []
    var lightningFetchedAtMs: Int64?
    var loadingRadar = false
    var loadingLightning = false
    var lightningError: String?
}

@MainActor
@Observable
final class StormMapViewModel {
    private(set) var ui = StormMapUiState()

    private let prefetcher = StormRadarPrefetcher()
    private var animationTask: Task<Void, Never>?
    private var lightningTask: Task<Void, Never>?
    private var lastLat: Double?
    private var lastLon: Double?

    private static let animationFrameMs: UInt64 = 800
    private static let radarRefreshMs: UInt64 = 5 * 60 * 1000
    private static let lightningPollMs: UInt64 = 60 * 1000

    func setRadarEnabled(_ enabled: Bool) {
        ui.radarEnabled = enabled
        if enabled, let lastLat, let lastLon {
            refreshRadar(lat: lastLat, lon: lastLon)
        } else {
            stopAnimation()
            ui.radarOverlay = nil
            ui.radarAnimationFrames = []
            ui.visibleLightningStrikes = []
        }
    }

    func setLightningEnabled(_ enabled: Bool) {
        ui.lightningEnabled = enabled
        if enabled {
            refreshLightningOnly()
        } else {
            lightningTask?.cancel()
            ui.allLightningStrikes = []
            ui.visibleLightningStrikes = []
            ui.lightningError = nil
            ui.loadingLightning = false
        }
    }

    func refreshRadar(lat: Double, lon: Double) {
        lastLat = lat
        lastLon = lon
        guard ui.radarEnabled else { return }
        Task {
            let wasPlaying = ui.radarAnimationPlaying
            let hadTimeline = !ui.radarAnimationFrames.isEmpty
            let previousIndex = ui.radarAnimationIndex
            stopAnimation()

            if let cached = await prefetcher.peek(lat: lat, lon: lon) {
                applyPrefetch(cached, hadTimeline: hadTimeline, previousIndex: previousIndex)
                if wasPlaying, cached.frames.count >= 2 {
                    startAnimation()
                }
                if !cached.isExpired() {
                    return
                }
            } else {
                ui.loadingRadar = true
                if ui.lightningEnabled { ui.loadingLightning = true }
            }

            let bundle = await prefetcher.fetchAndCache(lat: lat, lon: lon)
            applyPrefetch(bundle, hadTimeline: hadTimeline, previousIndex: previousIndex)
            if wasPlaying, bundle.frames.count >= 2 {
                startAnimation()
            }
        }
    }

    func refreshLightningOnly() {
        guard ui.lightningEnabled else { return }
        lightningTask?.cancel()
        lightningTask = Task {
            ui.loadingLightning = true
            ui.lightningError = nil
            let result = await CompositeLightningRepository.fetchMergedStrikes()
            guard !Task.isCancelled else { return }
            switch result {
            case .success(let strikes):
                ui.allLightningStrikes = strikes
                ui.lightningFetchedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
                ui.lightningError = nil
            case .failure(let error):
                ui.lightningError = error.localizedDescription
            }
            ui.loadingLightning = false
            reapplyLightningForCurrentFrame()
        }
    }

    func toggleRadarAnimation() {
        guard ui.radarAnimationFrames.count >= 2 else { return }
        if ui.radarAnimationPlaying {
            stopAnimation()
        } else {
            startAnimation()
        }
    }

    func stepRadarFrame(delta: Int) {
        guard !ui.radarAnimationFrames.isEmpty else { return }
        stopAnimation()
        let newIndex = (ui.radarAnimationIndex + delta)
            .clamped(to: 0 ... ui.radarAnimationFrames.count - 1)
        applyFrameIndex(newIndex)
    }

    func setRadarFrameIndex(_ index: Int) {
        guard !ui.radarAnimationFrames.isEmpty else { return }
        stopAnimation()
        applyFrameIndex(index)
    }

    func startPeriodicRefresh(lat: Double, lon: Double) async {
        while !Task.isCancelled {
            refreshRadar(lat: lat, lon: lon)
            try? await Task.sleep(nanoseconds: Self.radarRefreshMs * 1_000_000)
        }
    }

    func startLightningPolling() async {
        guard ui.lightningEnabled else { return }
        while !Task.isCancelled {
            refreshLightningOnly()
            try? await Task.sleep(nanoseconds: Self.lightningPollMs * 1_000_000)
        }
    }

    private func applyPrefetch(
        _ bundle: StormRadarPrefetch,
        hadTimeline: Bool,
        previousIndex: Int
    ) {
        ui.loadingRadar = false
        ui.loadingLightning = false
        ui.radarSourceLabel = bundle.sourceLabel
        ui.radarAnimationFrames = bundle.frames
        ui.allLightningStrikes = bundle.lightningStrikes
        ui.lightningFetchedAtMs = bundle.lightningFetchedAtMs
        ui.lightningError = bundle.lightningError

        if bundle.frames.isEmpty {
            ui.radarOverlay = bundle.latestOverlay
            ui.radarAnimationIndex = 0
            ui.visibleLightningStrikes = ui.lightningEnabled ? bundle.lightningStrikes : []
        } else {
            let nowIdx = RadarFrameMapping.nowFrameIndex(in: bundle.frames)
            let startIdx =
                hadTimeline && bundle.frames.indices.contains(previousIndex)
                ? previousIndex
                : nowIdx
            applyFrameIndex(startIdx)
        }
    }

    private func startAnimation() {
        stopAnimation()
        ui.radarAnimationPlaying = true
        animationTask = Task {
            let frames = ui.radarAnimationFrames
            guard !frames.isEmpty else { return }
            var index = ui.radarAnimationIndex.clamped(to: 0 ... frames.count - 1)
            while !Task.isCancelled, ui.radarAnimationPlaying {
                applyFrameIndex(index)
                index = (index + 1) % frames.count
                try? await Task.sleep(nanoseconds: Self.animationFrameMs * 1_000_000)
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
        ui.radarAnimationPlaying = false
    }

    private func applyFrameIndex(_ index: Int) {
        let frames = ui.radarAnimationFrames
        guard !frames.isEmpty else {
            ui.radarAnimationIndex = 0
            return
        }
        let i = index.clamped(to: 0 ... frames.count - 1)
        let frame = frames[i]
        ui.radarAnimationIndex = i
        ui.radarOverlay = RadarFrameMapping.toActiveOverlay(frame, sourceLabel: ui.radarSourceLabel)
        ui.visibleLightningStrikes =
            ui.lightningEnabled
            ? RadarFrameMapping.filterLightning(strikes: ui.allLightningStrikes, frame: frame)
            : []
    }

    private func reapplyLightningForCurrentFrame() {
        if !ui.lightningEnabled {
            ui.visibleLightningStrikes = []
            return
        }
        if ui.radarAnimationFrames.isEmpty {
            ui.visibleLightningStrikes = ui.allLightningStrikes
            return
        }
        let idx = ui.radarAnimationIndex.clamped(to: 0 ... ui.radarAnimationFrames.count - 1)
        let frame = ui.radarAnimationFrames[idx]
        ui.visibleLightningStrikes = RadarFrameMapping.filterLightning(
            strikes: ui.allLightningStrikes,
            frame: frame
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
