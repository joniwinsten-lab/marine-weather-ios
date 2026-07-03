import SwiftUI

/// Route weather strip for one source (4 slots along leg).
struct RouteWindForecastCard: View {
    let title: String
    let state: RouteSourceWeatherState
    let slotLabels: [String]
    let windUnit: WindUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
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
                HStack(alignment: .top, spacing: 2) {
                    ForEach(Array(slotLabels.enumerated()), id: \.offset) { index, label in
                        WindForecastTimeSlot(
                            label: label,
                            point: strip.slots.indices.contains(index) ? strip.slots[index] : nil,
                            windUnit: windUnit,
                            dense: true,
                            labelLineLimit: 2
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            } else if !state.loading {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
    }
}
