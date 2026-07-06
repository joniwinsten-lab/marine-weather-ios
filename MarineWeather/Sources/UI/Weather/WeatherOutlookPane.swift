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
                    highlighted: index == 0,
                    labelWidth: 52
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
                    highlighted: false,
                    labelWidth: 72
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
        }
    }

    private var forecastScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                WeatherForecastSectionHeader(
                    title: String(localized: "weather_section_24h"),
                    windUnit: viewModel.windUnit
                )

                ForEach(hourlyRows) { row in
                    WeatherForecastRow(model: row, windUnit: viewModel.windUnit)
                    if row.id != hourlyRows.last?.id {
                        Divider()
                    }
                }

                if !weeklyRows.isEmpty {
                    Divider()
                        .padding(.vertical, 14)

                    WeatherForecastSectionHeader(
                        title: String(localized: "weather_section_7d"),
                        windUnit: viewModel.windUnit
                    )

                    ForEach(weeklyRows) { row in
                        WeatherForecastRow(model: row, windUnit: viewModel.windUnit)
                        if row.id != weeklyRows.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }
}

private struct WeatherForecastRowModel: Identifiable {
    let id: String
    let label: String
    let point: UnifiedTimePoint?
    let highlighted: Bool
    let labelWidth: CGFloat
}

private struct WeatherForecastSectionHeader: View {
    let title: String
    let windUnit: WindUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                Text(String(localized: "weather_col_time"))
                    .frame(minWidth: 72, alignment: .leading)
                Color.clear.frame(width: 40)
                Text(String(localized: "weather_col_temp"))
                    .frame(width: 44, alignment: .trailing)
                Text(String(format: String(localized: "weather_col_wind"), windUnit.label))
                    .frame(minWidth: 56, alignment: .trailing)
                Text(String(localized: "weather_col_precip"))
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }
}

private struct WeatherForecastRow: View {
    let model: WeatherForecastRowModel
    let windUnit: WindUnit

    var body: some View {
        HStack(spacing: 8) {
            Text(model.label)
                .font(.system(size: model.highlighted ? 14 : 13, weight: model.highlighted ? .bold : .medium))
                .foregroundStyle(model.highlighted ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: model.labelWidth, alignment: .leading)

            WeatherSymbolImage(symbolCode: model.point?.weatherSymbolCode, size: 40)
                .frame(width: 40)

            Text(tempText)
                .font(.system(size: model.highlighted ? 16 : 15, weight: model.highlighted ? .bold : .regular))
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)

            Text(windText)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(minWidth: 56, alignment: .trailing)

            Text(precipText)
                .font(.system(size: 13))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .background(model.highlighted ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
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
