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
        VStack(alignment: .leading, spacing: dense ? 2 : 8) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: dense ? 11 : 15, weight: .semibold))
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
                    .font(.system(size: dense ? 8 : 11))
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
                HStack(alignment: .top, spacing: dense ? 1 : 6) {
                    ForEach(Array(slotLabels.enumerated()), id: \.offset) { index, label in
                        WindTimeSlot(
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

private struct WindTimeSlot: View {
    let label: String
    let point: UnifiedTimePoint?
    let windUnit: WindUnit
    var dense: Bool = false

    var body: some View {
        VStack(spacing: dense ? 1 : 4) {
            Text(label)
                .font(.system(size: dense ? 9 : 12, weight: .semibold))
                .foregroundStyle(.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let point, let speedMs = point.windSpeedMs, let speed = WindFormatting.speed(speedMs, unit: windUnit) {
                Text(speed)
                    .font(.system(size: dense ? 14 : 20, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(windUnit.label)
                    .font(.system(size: dense ? 9 : 11))
                    .foregroundStyle(.secondary)

                if let gustMs = point.windGustMs, let gust = WindFormatting.speed(gustMs, unit: windUnit) {
                    Text("Max \(gust)")
                        .font(.system(size: dense ? 9 : 11))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                if let from = point.windFromDeg {
                    WindDirectionGlyph(fromDegrees: from, size: dense ? 18 : 36)
                    Text("\(Int(from.rounded()))°")
                        .font(.system(size: dense ? 9 : 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .font(.system(size: dense ? 12 : 18, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
