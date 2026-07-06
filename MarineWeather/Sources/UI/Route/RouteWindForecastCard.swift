import SwiftUI

/// Route weather strip for one source (4 slots along leg).
struct RouteWindForecastCard: View {
    let title: String
    let state: RouteSourceWeatherState
    let slotLabels: [String]
    let windUnit: WindUnit
    var compact: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 6) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: compact ? 14 : 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                if state.loading {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                }
            }

            if let error = state.errorMessage, state.slots == nil {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Divider()

            if let strip = state.slots {
                HStack(alignment: .top, spacing: compact ? 2 : 6) {
                    ForEach(Array(slotLabels.enumerated()), id: \.offset) { index, label in
                        WindForecastTimeSlot(
                            label: label,
                            point: strip.slots.indices.contains(index) ? strip.slots[index] : nil,
                            windUnit: windUnit,
                            dense: compact,
                            labelLineLimit: compact ? 2 : 3
                        )
                        .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil)
                    }
                }
                .frame(maxHeight: compact ? .infinity : nil)
            } else if !state.loading {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil)
            }
        }
        .padding(.horizontal, compact ? 4 : 8)
        .padding(.vertical, compact ? 3 : 8)
        .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil, alignment: .topLeading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
    }
}
