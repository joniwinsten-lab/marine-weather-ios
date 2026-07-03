import CoreLocation
import SwiftUI

private let extWindDayCount = 13

/// 12+ day wind outlook with map (long-press = forecast point). Android `ExtendedWindOutlookPane`.
struct ExtendedWindOutlookPane: View {
    @Bindable var viewModel: CompareViewModel
    @Bindable var premium = PremiumAccess.shared
    @State private var traficomEnabled = true
    @State private var mapController = MapScreenController()
    var onRecenter: () -> Void

    private var metDaily: [UnifiedTimePoint?] { dailySamples(for: .metNorway) }
    private var smhiDaily: [UnifiedTimePoint?] { dailySamples(for: .smhi) }
    private var fmiDaily: [UnifiedTimePoint?] { dailySamples(for: .fmi) }

    private var hasAnyForecast: Bool {
        metDaily.contains { $0 != nil } || smhiDaily.contains { $0 != nil } || fmiDaily.contains { $0 != nil }
    }

    var body: some View {
        Group {
            if premium.isPremium {
                outlookContent
            } else {
                RoutePremiumPaywall(premium: premium) {}
            }
        }
        .onAppear { viewModel.onAppear() }
    }

    private var outlookContent: some View {
        GeometryReader { geometry in
            let twoPane = geometry.size.width >= UiBreakpoints.twoPaneMinWidth
            if twoPane {
                HStack(spacing: 0) {
                    mapColumn
                        .frame(
                            width: geometry.size.width * UiBreakpoints.extendedWindMapWidthFraction,
                            height: geometry.size.height
                        )
                    outlookTable
                        .frame(
                            width: geometry.size.width * UiBreakpoints.extendedWindTableWidthFraction,
                            height: geometry.size.height
                        )
                }
            } else {
                VStack(spacing: 0) {
                    mapColumn.frame(height: geometry.size.height * 0.52)
                    outlookTable.frame(height: geometry.size.height * 0.48)
                }
            }
        }
    }

    private var mapColumn: some View {
        VStack(spacing: 0) {
            Button { traficomEnabled.toggle() } label: {
                Text(String(localized: "traficom_chip"))
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(traficomEnabled ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            MapScreen(
                center: viewModel.mapCenter,
                zoom: AppConfig.defaultCompareZoom,
                traficomEnabled: traficomEnabled,
                controller: mapController,
                onLongPress: { viewModel.setMapCenter($0) }
            )
            .overlay(alignment: .bottomTrailing) { mapControls.padding(10) }
        }
    }

    private var outlookTable: some View {
        GeometryReader { geo in
            let horizontalPad: CGFloat = 8
            let contentWidth = geo.size.width - horizontalPad * 2
            let headerBlock: CGFloat = 36
            let footerBlock: CGFloat = 14
            let rowHeight = max(
                38,
                (geo.size.height - headerBlock - footerBlock) / CGFloat(extWindDayCount + 1)
            )

            VStack(alignment: .leading, spacing: 2) {
                tableHeader
                if !hasAnyForecast, !viewModel.isRefreshing {
                    Text(String(localized: "route_ext_empty"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                windTable(availableWidth: contentWidth, rowHeight: rowHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                Text(String(localized: "route_ext_attribution"))
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, horizontalPad)
            .padding(.vertical, 4)
        }
        .background(Color(.secondarySystemBackground))
    }

    private var tableHeader: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "route_ext_title"))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(String(
                    format: String(localized: "route_ext_coords_short"),
                    viewModel.mapCenter.latitude,
                    viewModel.mapCenter.longitude
                ))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if viewModel.isRefreshing {
                ProgressView().controlSize(.mini).scaleEffect(0.65)
            }
            windUnitChip(.metersPerSecond, "m/s")
            windUnitChip(.knots, "kn")
            Button { viewModel.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .disabled(viewModel.isRefreshing)
        }
    }

    private func windTable(availableWidth: CGFloat, rowHeight: CGFloat) -> some View {
        let dayWidth = min(52, availableWidth * 0.17)
        let sourceWidth = max(0, (availableWidth - dayWidth - 4) / 3)
        let today = Calendar.current.startOfDay(for: Date())

        return VStack(spacing: 0) {
            HStack(spacing: 1) {
                Text(String(localized: "route_ext_col_day"))
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: dayWidth, height: rowHeight * 0.85, alignment: .leading)
                sourceHeader(.metNorway, width: sourceWidth, height: rowHeight * 0.85)
                sourceHeader(.smhi, width: sourceWidth, height: rowHeight * 0.85)
                sourceHeader(.fmi, width: sourceWidth, height: rowHeight * 0.85)
            }
            Divider()

            ForEach(0..<extWindDayCount, id: \.self) { dayIndex in
                let dayLabel = dayLabel(for: dayIndex, today: today)
                HStack(spacing: 1) {
                    Text(dayLabel)
                        .font(.system(size: 11, weight: dayIndex == 0 ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: dayWidth, height: rowHeight, alignment: .leading)
                    cell(metDaily, dayIndex, width: sourceWidth, height: rowHeight)
                    cell(smhiDaily, dayIndex, width: sourceWidth, height: rowHeight)
                    cell(fmiDaily, dayIndex, width: sourceWidth, height: rowHeight)
                }
                if dayIndex < extWindDayCount - 1 {
                    Divider().opacity(0.25)
                }
            }
        }
    }

    private func sourceHeader(_ source: SourceId, width: CGFloat, height: CGFloat) -> some View {
        Text(source.shortName)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: width, height: height)
            .multilineTextAlignment(.center)
    }

    private func cell(_ daily: [UnifiedTimePoint?], _ index: Int, width: CGFloat, height: CGFloat) -> some View {
        WindOutlookCell(
            point: daily.indices.contains(index) ? daily[index] : nil,
            windUnit: viewModel.windUnit
        )
        .frame(width: width, height: height)
    }

    private func dayLabel(for dayIndex: Int, today: Date) -> String {
        if dayIndex == 0 { return String(localized: "route_ext_day_today") }
        guard let date = Calendar.current.date(byAdding: .day, value: dayIndex, to: today) else {
            return "—"
        }
        let day = Calendar.current.component(.day, from: date)
        let month = Calendar.current.component(.month, from: date)
        return "\(day).\(month)."
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

    private func windUnitChip(_ unit: WindUnit, _ label: String) -> some View {
        Button { viewModel.setWindUnit(unit) } label: {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    viewModel.windUnit == unit ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private func dailySamples(for source: SourceId) -> [UnifiedTimePoint?] {
        let points = viewModel.sourceStates[source]?.forecast?.points ?? []
        return ForecastSampler.sampleDailyNearLocalNoon(points: points, timeZone: .current, numDays: extWindDayCount)
    }
}
