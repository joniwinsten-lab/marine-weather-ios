import SwiftUI

/// Four-country marine text grid (Android `MarineTextOverviewPane`).
struct MarineTextOverviewPane: View {
    let latitude: Double
    let longitude: Double

    @State private var viewModel = MarineTextViewModel()

    private let countryOrder = ["NO", "SE", "FI", "EE"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(localized: "marine_text_screen_title"))
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                Button {
                    viewModel.refresh(latitude: latitude, longitude: longitude)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.loading)
                .accessibilityLabel(String(localized: "marine_text_refresh_cd"))
            }

            Text(String(localized: "marine_text_intro"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(String(format: String(localized: "marine_text_map_hint"), latitude, longitude))
                .font(.caption2)
                .foregroundStyle(.secondary)

            if viewModel.loading && viewModel.overview == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let errors = viewModel.overview?.errors {
                ForEach(errors, id: \.self) { err in
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let countries = viewModel.overview?.countries, !countries.isEmpty {
                let byCode = Dictionary(uniqueKeysWithValues: countries.map { ($0.countryCode, $0) })
                GeometryReader { geometry in
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            ForEach(countryOrder.prefix(2), id: \.self) { code in
                                countryCell(byCode[code])
                                    .frame(width: (geometry.size.width - 10) / 2, height: (geometry.size.height - 10) / 2)
                            }
                        }
                        HStack(spacing: 10) {
                            ForEach(countryOrder.suffix(2), id: \.self) { code in
                                countryCell(byCode[code])
                                    .frame(width: (geometry.size.width - 10) / 2, height: (geometry.size.height - 10) / 2)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.load(latitude: latitude, longitude: longitude)
        }
        .onChange(of: latitude) { _, _ in
            viewModel.load(latitude: latitude, longitude: longitude)
        }
        .onChange(of: longitude) { _, _ in
            viewModel.load(latitude: latitude, longitude: longitude)
        }
    }

    @ViewBuilder
    private func countryCell(_ card: MarineCountryText?) -> some View {
        if let card {
            MarineCountryCard(card: card)
        }
    }
}

private struct MarineCountryCard: View {
    let card: MarineCountryText

    private var bodyDisplay: String {
        let trimmed = card.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "marine_text_empty_cell") : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            if let meta = card.publishedOrValidLabel {
                Text(meta)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if card.alertLevel != .none {
                MarineAlertBanner(level: card.alertLevel)
            }

            Divider()

            ScrollView {
                Text(bodyDisplay)
                    .font(.subheadline)
                    .foregroundStyle(card.body.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Link(String(localized: "marine_open_web_forecast"), destination: card.servicePageURL)
                .font(.caption)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct MarineAlertBanner: View {
    let level: MarineForecastAlertLevel

    var body: some View {
        let (bg, fg, text): (Color, Color, String) = switch level {
        case .warning:
            (Color(.systemRed).opacity(0.15), Color(.systemRed), String(localized: "marine_alert_warning"))
        case .notice:
            (Color(.systemYellow).opacity(0.25), Color(.systemOrange), String(localized: "marine_alert_notice"))
        case .none:
            (.clear, .clear, "")
        }

        if level != .none {
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(fg)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(bg, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
