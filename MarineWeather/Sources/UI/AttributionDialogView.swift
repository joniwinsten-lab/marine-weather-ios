import SwiftUI

/// Sources and licenses (Android `AttributionDialog` in `VeneappiRoot.kt`).
struct AttributionDialogView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    attributionLink(
                        name: String(localized: "source_met_norway"),
                        url: WeatherSources.metNorway.licenseURL
                    )
                    attributionLink(
                        name: String(localized: "source_smhi"),
                        url: WeatherSources.smhi.licenseURL
                    )
                    attributionLink(
                        name: String(localized: "source_fmi"),
                        url: WeatherSources.fmi.licenseURL
                    )

                    Text(String(localized: "attribution_traficom_charts"))
                        .font(.footnote)
                    linkButton(String(localized: "attribution_traficom_cc_link"), url: URL(string: "https://creativecommons.org/licenses/by/4.0/deed.fi")!)

                    Text(String(localized: "attribution_fmi_radar_lightning"))
                        .font(.footnote)
                    linkButton(String(localized: "attribution_fmi_cc_link"), url: WeatherSources.fmi.licenseURL)

                    Text(String(localized: "attribution_met_radar"))
                        .font(.footnote)
                    linkButton(String(localized: "attribution_met_norway_link"), url: WeatherSources.metNorway.licenseURL)

                    Text(String(localized: "attribution_smhi_radar_lightning"))
                        .font(.footnote)
                    linkButton(String(localized: "attribution_smhi_link"), url: WeatherSources.smhi.licenseURL)

                    Text(String(localized: "attribution_digitraffic_ais"))
                        .font(.footnote)
                    linkButton(
                        String(localized: "attribution_digitraffic_link"),
                        url: URL(string: "https://meri.digitraffic.fi/")!
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(String(localized: "attribution_open"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func attributionLink(name: String, url: URL) -> some View {
        Link(destination: url) {
            Text("\(name) — \(url.absoluteString)")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
    }

    private func linkButton(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            Text(title)
                .font(.subheadline)
        }
    }
}
