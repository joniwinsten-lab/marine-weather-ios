import SwiftUI

/// 24-hour and 7-day weather outlook with selectable source.
struct WeatherOutlookPane: View {
    @Bindable var viewModel: CompareViewModel
    @State private var selectedSource = UserPreferences.weatherSource

    private var sourceState: SourceForecastState {
        viewModel.sourceStates[selectedSource] ?? .idle
    }

    private var hourlyRows: [WeatherForecastRowModel] {
        guard let points = sourceState.forecast?.points else { return [] }
        return ForecastSampler.sampleHourlyNext(points: points, hours: 24)
            .enumerated()
            .map { index, row in
                WeatherForecastRowModel(
                    id: "hour-\(index)",
                    label: row.label,
                    point: row.point,
                    highlighted: index == 0
                )
            }
    }

    private var weeklyRows: [WeatherForecastRowModel] {
        guard let points = sourceState.forecast?.points else { return [] }
        return ForecastSampler.sampleDailyWithLabels(points: points, numDays: 7)
            .enumerated()
            .compactMap { index, row in
                guard row.point != nil else { return nil }
                return WeatherForecastRowModel(
                    id: "day-\(index)",
                    label: row.label,
                    point: row.point,
                    highlighted: false
                )
            }
    }

    private var showsFmiHorizonNote: Bool {
        selectedSource == .fmi
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            sourcePicker
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { viewModel.onAppear() }
        .onChange(of: selectedSource) { _, source in
            UserPreferences.weatherSource = source
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "weather_screen_title"))
                .font(.title2.weight(.semibold))
            Text(
                String(
                    format: String(localized: "weather_map_hint"),
                    viewModel.mapCenter.latitude,
                    viewModel.mapCenter.longitude
                )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            Text(String(localized: "weather_symbols_attribution"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "weather_source_picker"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(String(localized: "weather_source_picker"), selection: $selectedSource) {
                ForEach(SourceId.allCases) { source in
                    Text(source.shortName).tag(source)
                }
            }
            .pickerStyle(.segmented)

            if showsFmiHorizonNote {
                Text(String(localized: "weather_fmi_horizon_note"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if sourceState.loading && sourceState.forecast == nil {
            ProgressView(String(localized: "weather_loading"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = sourceState.errorMessage, sourceState.forecast == nil {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if hourlyRows.isEmpty || hourlyRows.allSatisfy({ $0.point == nil }) {
            Text(String(localized: "weather_empty"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            forecastScroll
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var forecastScroll: some View {
        GeometryReader { geometry in
            let layout = WeatherForecastTableLayout(contentWidth: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    WeatherForecastSectionHeader(
                        title: String(localized: "weather_section_24h"),
                        windUnit: viewModel.windUnit,
                        layout: layout
                    )

                    ForEach(hourlyRows) { row in
                        WeatherForecastRow(model: row, windUnit: viewModel.windUnit, layout: layout)
                        if row.id != hourlyRows.last?.id {
                            Divider()
                        }
                    }

                    if !weeklyRows.isEmpty {
                        Divider()
                            .padding(.vertical, 14)

                        WeatherForecastSectionHeader(
                            title: String(localized: "weather_section_7d"),
                            windUnit: viewModel.windUnit,
                            layout: layout
                        )

                        ForEach(weeklyRows) { row in
                            WeatherForecastRow(model: row, windUnit: viewModel.windUnit, layout: layout)
                            if row.id != weeklyRows.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct WeatherForecastRowModel: Identifiable {
    let id: String
    let label: String
    let point: UnifiedTimePoint?
    let highlighted: Bool
}

/// Shared column widths so headers and rows stay aligned edge-to-edge.
private struct WeatherForecastTableLayout {
    let contentWidth: CGFloat

    static let columnSpacing: CGFloat = 6
    static let rowVerticalPadding: CGFloat = 10
    static let symbolSize: CGFloat = 36

    var timeWidth: CGFloat { max(64, contentWidth * 0.16) }
    var symbolWidth: CGFloat { 44 }
    var tempWidth: CGFloat { max(44, contentWidth * 0.11) }
    var precipWidth: CGFloat { max(40, contentWidth * 0.10) }
    var windWidth: CGFloat {
        let fixed = timeWidth + symbolWidth + tempWidth + precipWidth
        let gaps = Self.columnSpacing * 4
        return max(72, contentWidth - fixed - gaps)
    }
}

private struct WeatherForecastSectionHeader: View {
    let title: String
    let windUnit: WindUnit
    let layout: WeatherForecastTableLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            WeatherForecastColumnHeader(windUnit: windUnit, layout: layout)

            Divider()
        }
        .padding(.bottom, 4)
        .frame(width: layout.contentWidth, alignment: .leading)
    }
}

private struct WeatherForecastColumnHeader: View {
    let windUnit: WindUnit
    let layout: WeatherForecastTableLayout

    var body: some View {
        HStack(spacing: WeatherForecastTableLayout.columnSpacing) {
            Text(String(localized: "weather_col_time"))
                .frame(width: layout.timeWidth, alignment: .leading)

            Color.clear
                .frame(width: layout.symbolWidth)

            Text(String(localized: "weather_col_temp"))
                .frame(width: layout.tempWidth, alignment: .trailing)

            Text(String(format: String(localized: "weather_col_wind"), windUnit.label))
                .frame(width: layout.windWidth, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(String(localized: "weather_col_precip"))
                .frame(width: layout.precipWidth, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
}

private struct WeatherForecastRow: View {
    let model: WeatherForecastRowModel
    let windUnit: WindUnit
    let layout: WeatherForecastTableLayout

    var body: some View {
        HStack(spacing: WeatherForecastTableLayout.columnSpacing) {
            Text(model.label)
                .font(.system(size: model.highlighted ? 14 : 13, weight: model.highlighted ? .bold : .medium))
                .foregroundStyle(model.highlighted ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: layout.timeWidth, alignment: .leading)

            WeatherSymbolImage(symbolCode: model.point?.weatherSymbolCode, size: WeatherForecastTableLayout.symbolSize)
                .frame(width: layout.symbolWidth)

            Text(tempText)
                .font(.system(size: model.highlighted ? 16 : 15, weight: model.highlighted ? .bold : .regular))
                .monospacedDigit()
                .frame(width: layout.tempWidth, alignment: .trailing)

            Text(windText)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: layout.windWidth, alignment: .trailing)

            Text(precipText)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: layout.precipWidth, alignment: .trailing)
        }
        .padding(.vertical, WeatherForecastTableLayout.rowVerticalPadding)
        .frame(width: layout.contentWidth, alignment: .leading)
        .background {
            if model.highlighted {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
    }

    private var tempText: String {
        guard let temp = model.point?.airTempC else { return "—" }
        return String(format: "%.0f°", temp.rounded())
    }

    private var windText: String {
        guard let speed = model.point?.windSpeedMs,
              let formatted = WindFormatting.speed(speed, unit: windUnit) else {
            return "—"
        }
        if let deg = model.point?.windFromDeg {
            return "\(formatted) \(WindFormatting.cardinal(fromDegrees: deg))"
        }
        return formatted
    }

    private var precipText: String {
        guard let mm = model.point?.precipitationMmPerH else { return "—" }
        if mm < 0.05 { return "0" }
        return String(format: "%.1f", mm)
    }
}
