import SwiftUI

/// Side panel for Compare tab — mirrors Android dense `WeatherPane`.
struct WeatherComparePane: View {
    @Bindable var viewModel: CompareViewModel
    var dense: Bool

    private let headerHeight: CGFloat = 24

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: dense ? 2 : 8) {
                header
                    .frame(height: headerHeight)

                if dense {
                    let spacingTotal = 2 * CGFloat(SourceId.allCases.count - 1)
                    let cardHeight = max(
                        0,
                        (geometry.size.height - headerHeight - spacingTotal) / CGFloat(SourceId.allCases.count)
                    )
                    ForEach(SourceId.allCases) { source in
                        SourceWindForecastCard(
                            title: source.displayName,
                            state: viewModel.sourceStates[source] ?? .idle,
                            windUnit: viewModel.windUnit,
                            dense: true
                        )
                        .frame(height: cardHeight)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(SourceId.allCases) { source in
                                SourceWindForecastCard(
                                    title: source.displayName,
                                    state: viewModel.sourceStates[source] ?? .idle,
                                    windUnit: viewModel.windUnit,
                                    dense: false
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, dense ? 2 : 10)
            .padding(.vertical, dense ? 1 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Weather sources")
                    .font(.system(size: 10, weight: .semibold))
                Text("Long-press map")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            }
            windUnitChips
            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .disabled(viewModel.isRefreshing)
        }
    }

    private var windUnitChips: some View {
        HStack(spacing: 2) {
            windChip(.metersPerSecond, label: "m/s")
            windChip(.knots, label: "kn")
        }
    }

    private func windChip(_ unit: WindUnit, label: String) -> some View {
        Button {
            viewModel.setWindUnit(unit)
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    viewModel.windUnit == unit ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}
