import CoreLocation
import SwiftUI

/// Storm radar + lightning tab (Android `StormRadarPane.kt`).
struct StormRadarPane: View {
    @Bindable var stormVM: StormMapViewModel
    let mapCenter: CLLocationCoordinate2D
    var onLongPress: (CLLocationCoordinate2D) -> Void
    var onRecenter: () -> Void

    @State private var mapController = MapScreenController()

    var body: some View {
        VStack(spacing: 0) {
            controlRow
            ZStack(alignment: .bottomLeading) {
                StormMapScreen(
                    center: mapCenter,
                    radarOverlay: stormVM.ui.radarEnabled ? stormVM.ui.radarOverlay : nil,
                    lightningStrikes: stormVM.ui.lightningEnabled ? stormVM.ui.visibleLightningStrikes : [],
                    controller: mapController,
                    onLongPress: onLongPress
                )

                StormOverlayHud(stormUi: stormVM.ui)
                    .padding(.leading, 8)
                    .padding(.bottom, showTimeline ? 118 : 56)

                if showTimeline {
                    StormTimelineSlider(
                        frames: stormVM.ui.radarAnimationFrames,
                        selectedIndex: stormVM.ui.radarAnimationIndex,
                        onSelectIndex: { stormVM.setRadarFrameIndex($0) }
                    )
                    .padding(.bottom, 8)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                mapControls.padding(10)
            }
        }
        .task(id: mapCenter.latitude) {
            stormVM.refreshRadar(lat: mapCenter.latitude, lon: mapCenter.longitude)
            await stormVM.startPeriodicRefresh(lat: mapCenter.latitude, lon: mapCenter.longitude)
        }
        .task(id: stormVM.ui.lightningEnabled) {
            guard stormVM.ui.lightningEnabled else { return }
            await stormVM.startLightningPolling()
        }
    }

    private var showTimeline: Bool {
        stormVM.ui.radarEnabled && stormVM.ui.radarAnimationFrames.count >= 2
    }

    private var controlRow: some View {
        HStack(spacing: 8) {
            FilterChipToggle(
                title: String(localized: "storm_radar_chip_radar"),
                isOn: stormVM.ui.radarEnabled
            ) {
                stormVM.setRadarEnabled(!stormVM.ui.radarEnabled)
            }
            FilterChipToggle(
                title: String(localized: "storm_radar_chip_lightning"),
                isOn: stormVM.ui.lightningEnabled
            ) {
                stormVM.setLightningEnabled(!stormVM.ui.lightningEnabled)
            }

            if showTimeline {
                Button { stormVM.stepRadarFrame(delta: -1) } label: {
                    Image(systemName: "backward.fill")
                }
                Button { stormVM.toggleRadarAnimation() } label: {
                    Image(systemName: stormVM.ui.radarAnimationPlaying ? "pause.fill" : "play.fill")
                }
                Button { stormVM.stepRadarFrame(delta: 1) } label: {
                    Image(systemName: "forward.fill")
                }
            }

            if stormVM.ui.loadingRadar || stormVM.ui.loadingLightning {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var mapControls: some View {
        VStack(spacing: 6) {
            mapControlButton(systemName: "location.fill", action: onRecenter)
            mapControlButton(systemName: "plus", action: { mapController.zoomIn() })
            mapControlButton(systemName: "minus", action: { mapController.zoomOut() })
        }
    }

    private func mapControlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct FilterChipToggle: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isOn ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct StormOverlayHud: View {
    let stormUi: StormMapUiState

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if stormUi.radarEnabled {
                let source = stormUi.radarOverlay?.sourceLabel ?? stormUi.radarSourceLabel
                let time = stormUi.radarOverlay?.timeLabel ?? String(localized: "storm_radar_time_loading")
                Text(String(format: String(localized: "storm_radar_source_time"), source, time))
                    .font(.caption2)

                if stormUi.radarAnimationFrames.count >= 2 {
                    let frames = stormUi.radarAnimationFrames
                    let idx = stormUi.radarAnimationIndex.clamped(to: 0 ... frames.count - 1)
                    let frame = frames[idx]
                    Text(positionText(frames: frames, frame: frame, time: time))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(
                        stormUi.radarAnimationPlaying
                        ? String(localized: "storm_radar_animation_on")
                        : String(localized: "storm_radar_animation_off")
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            if stormUi.lightningEnabled {
                if let ms = stormUi.lightningFetchedAtMs {
                    let t = Self.timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(ms) / 1000))
                    Text(
                        String(
                            format: String(localized: "storm_lightning_updated_utc"),
                            t,
                            stormUi.visibleLightningStrikes.count,
                            stormUi.allLightningStrikes.count
                        )
                    )
                    .font(.caption2)
                } else {
                    Text(String(localized: "storm_lightning_loading"))
                        .font(.caption2)
                }
                if let err = stormUi.lightningError {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func positionText(frames: [RadarAnimationFrame], frame: RadarAnimationFrame, time: String) -> String {
        switch RadarFrameMapping.frameRole(frame) {
        case .forecast:
            let ahead = RadarFrameMapping.minutesAfterNow(frames: frames, index: stormUi.radarAnimationIndex) ?? 0
            return String(format: String(localized: "storm_radar_showing_forecast"), time, ahead)
        case .now:
            return String(format: String(localized: "storm_radar_showing_now"), time)
        case .observation:
            let ago = RadarFrameMapping.minutesBeforeNow(frames: frames, index: stormUi.radarAnimationIndex) ?? 0
            let agoLabel = String(format: String(localized: "storm_radar_observation_ago"), ago)
            return String(format: String(localized: "storm_radar_showing_observation"), time, agoLabel)
        }
    }
}

private struct StormTimelineSlider: View {
    let frames: [RadarAnimationFrame]
    let selectedIndex: Int
    let onSelectIndex: (Int) -> Void

    var body: some View {
        let nowIdx = RadarFrameMapping.nowFrameIndex(in: frames)
        let nowFrac = frames.count > 1 ? Double(nowIdx) / Double(frames.count - 1) : 0

        VStack(spacing: 2) {
            Slider(
                value: Binding(
                    get: { Double(selectedIndex) },
                    set: { onSelectIndex(Int($0.rounded())) }
                ),
                in: 0 ... Double(frames.count - 1),
                step: 1
            )
            GeometryReader { geo in
                Text(String(localized: "storm_radar_now_marker"))
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                    .position(x: geo.size.width * nowFrac, y: geo.size.height / 2)
            }
            .frame(height: 14)
            HStack {
                Text(String(localized: "storm_radar_slider_observations"))
                Spacer()
                Text(String(localized: "storm_radar_slider_forecast"))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
