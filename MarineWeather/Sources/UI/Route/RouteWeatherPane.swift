import SwiftUI

/// Right panel for route tab — boat speed, export, offline pack, three stacked source cards.
struct RouteWeatherPane: View {
    @Bindable var viewModel: RouteViewModel
    @Bindable var offlinePack: OfflinePackViewModel
    @Binding var speedText: String
    var onExportGpx: () -> Void
    var onExportPdf: () -> Void

    private let speedBarHeight: CGFloat = 72
    private let exportRowHeight: CGFloat = 36
    private let offlinePackHeight: CGFloat = 108
    private let weatherHeaderHeight: CGFloat = 28

    var body: some View {
        GeometryReader { geometry in
            let scrollable = UiBreakpoints.routeWeatherUsesScroll(height: geometry.size.height)
            if scrollable {
                ScrollView {
                    panelContent(
                        cardHeight: UiBreakpoints.routeForecastCardMinHeight,
                        compact: false
                    )
                }
            } else {
                let spacingTotal = 2 * CGFloat(SourceId.allCases.count - 1) + 6
                let used = speedBarHeight + exportRowHeight + offlinePackHeight + weatherHeaderHeight + spacingTotal + 6
                let cardHeight = max(0, (geometry.size.height - used) / CGFloat(SourceId.allCases.count))
                panelContent(cardHeight: cardHeight, compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private func panelContent(cardHeight: CGFloat, compact: Bool) -> some View {
        let labels = viewModel.routeSlotLabels()
        VStack(alignment: .leading, spacing: 2) {
            speedBar
                .frame(height: speedBarHeight)
            exportRow
                .frame(height: exportRowHeight)
            OfflineRoutePackCard(
                enabled: viewModel.routeGeometry.count >= 2,
                packState: offlinePack.state,
                onDownload: {
                    offlinePack.download(routeGeometry: viewModel.routeGeometry)
                }
            )
            .frame(height: offlinePackHeight)
            weatherHeader
                .frame(height: weatherHeaderHeight)

            ForEach(SourceId.allCases) { source in
                RouteWindForecastCard(
                    title: source.displayName,
                    state: viewModel.routeWeatherBySource[source] ?? .idle,
                    slotLabels: labels,
                    windUnit: viewModel.windUnit,
                    compact: compact
                )
                .frame(minHeight: cardHeight, maxHeight: compact ? cardHeight : nil)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }

    private var speedBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "route_boat_speed"))
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Button(String(localized: "route_clear")) {
                    viewModel.clearRoute()
                }
                .font(.caption)
            }
            HStack(spacing: 8) {
                if let leg = viewModel.routeWeatherLegNm, leg > 0 {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(String(format: String(localized: "route_distance_nm"), leg))
                            .font(.system(size: 10))
                        if let eta = viewModel.routeWeatherEtaHours {
                            Text(String(format: String(localized: "route_eta_hours"), eta))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                TextField(String(localized: "route_speed_kn"), text: $speedText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .font(.system(size: 12))
                    .onSubmit { commitSpeed() }
                Slider(
                    value: Binding(
                        get: { viewModel.boatSpeedKn },
                        set: {
                            viewModel.setBoatSpeedKn($0)
                            speedText = formatSpeed($0)
                        }
                    ),
                    in: 0.5...40,
                    step: 0.5
                )
            }
        }
        .padding(6)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 6))
    }

    private var exportRow: some View {
        HStack(spacing: 8) {
            Button(String(localized: "route_export_gpx"), action: onExportGpx)
                .buttonStyle(.bordered)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
            Button(String(localized: "route_export_pdf"), action: onExportPdf)
                .buttonStyle(.bordered)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
    }

    private var weatherHeader: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "route_weather_title"))
                    .font(.system(size: 10, weight: .semibold))
                if viewModel.isRoutingRoute {
                    Text(String(localized: "route_computing_fairway"))
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                } else if viewModel.routeFairwayUnavailable {
                    Text(String(localized: "route_fairway_fallback"))
                        .font(.system(size: 8))
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if viewModel.loadingRouteWeather {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            }
            windChip(.metersPerSecond, "m/s")
            windChip(.knots, "kn")
        }
    }

    private func windChip(_ unit: WindUnit, _ label: String) -> some View {
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

    private func formatSpeed(_ kn: Double) -> String {
        String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), kn)
    }

    private func commitSpeed() {
        let normalized = speedText.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(normalized) {
            viewModel.setBoatSpeedKn(parsed)
            speedText = formatSpeed(viewModel.boatSpeedKn)
        } else {
            speedText = formatSpeed(viewModel.boatSpeedKn)
        }
    }
}
