import SwiftUI

struct OfflineRoutePackCard: View {
    let enabled: Bool
    let packState: OfflinePackUiState
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "offline_pack_title"))
                .font(.system(size: 11, weight: .semibold))
            Text(String(localized: "offline_pack_body"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if packState.downloading, packState.total > 0 {
                ProgressView(value: Double(packState.current), total: Double(packState.total))
                Text(stepLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if packState.lastFailed {
                Text(String(localized: "offline_pack_failed"))
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if let weather = packState.lastSuccessWeatherSamples,
                      let vertices = packState.lastSuccessRouteVertices {
                Text(String(format: String(localized: "offline_pack_done"), weather, vertices))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                onDownload()
            } label: {
                Text(
                    packState.downloading
                        ? String(localized: "offline_pack_downloading")
                        : String(localized: "offline_pack_download")
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!enabled || packState.downloading)
        }
        .padding(6)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
    }

    private var stepLabel: String {
        switch packState.stepKey {
        case "tiles":
            return String(localized: "offline_pack_step_tiles")
        case "marine":
            return String(localized: "offline_pack_step_marine")
        case "weather":
            return String(format: String(localized: "offline_pack_step_weather"), packState.current, packState.total)
        case "done":
            return String(localized: "offline_pack_step_done")
        default:
            return String(localized: "offline_pack_step_working")
        }
    }
}
