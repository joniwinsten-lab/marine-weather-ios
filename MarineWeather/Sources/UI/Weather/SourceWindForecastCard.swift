import SwiftUI

struct SourceWindForecastCard: View {
    let title: String
    let state: SourceForecastState
    let windUnit: WindUnit
    var dense: Bool = false
    private var slotLabels: [String] {
        [
            String(localized: "wind_slot_now"),
            String(localized: "wind_slot_3h"),
            String(localized: "wind_slot_6h"),
            String(localized: "wind_slot_12h"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: dense ? 3 : 8) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: dense ? 14 : 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if state.loading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                }
            }

            if let metaLine = metaLineText {
                Text(metaLine)
                    .font(.system(size: dense ? 10 : 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            if let error = state.errorMessage, state.forecast == nil {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Divider()

            if let forecast = state.forecast {
                let slots = ForecastSampler.sampleAtOffsets(points: forecast.points)
                HStack(alignment: .top, spacing: dense ? 2 : 6) {
                    ForEach(Array(slotLabels.enumerated()), id: \.offset) { index, label in
                        WindForecastTimeSlot(
                            label: label,
                            point: slots.indices.contains(index) ? slots[index] : nil,
                            windUnit: windUnit,
                            dense: dense
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            } else if !state.loading {
                Spacer(minLength: 0)
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, dense ? 4 : 10)
        .padding(.vertical, dense ? 3 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: dense ? 6 : 10))
    }

    private var metaLineText: String? {
        guard let forecast = state.forecast else { return nil }
        let fetched = Self.formatFetched(forecast.fetchedAtUtc)
        if let modelInfo = forecast.modelInfo, !modelInfo.isEmpty {
            return "Fetched \(fetched) · \(modelInfo)"
        }
        return "Fetched \(fetched)"
    }

    private static func formatFetched(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
        return date.formatted(date: .numeric, time: .shortened)
    }
}
