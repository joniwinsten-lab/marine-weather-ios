import SwiftUI

/// Vessel info when user taps an AIS symbol on the map.
struct AisVesselDetailSheet: View {
    let vessel: AisVesselDisplay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(vessel.displayLabel)
                        .font(.title3.bold())
                }

                Section(String(localized: "ais_detail_motion")) {
                    row(String(localized: "ais_detail_speed"), AisFormatting.formatSpeedKn(vessel.sogKn))
                    row(String(localized: "ais_detail_cog"), AisFormatting.formatBearing(vessel.cogDeg))
                    row(String(localized: "ais_detail_heading"), AisFormatting.formatHeading(vessel.headingDeg))
                    if vessel.showsCourseVector {
                        Text(String(format: String(localized: "ais_detail_vector_hint"), Int(AppConfig.aisCourseVectorMinutes)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(String(localized: "ais_detail_identity")) {
                    row("MMSI", String(vessel.mmsi))
                    if let imo = vessel.imo, imo > 0 {
                        row("IMO", String(imo))
                    }
                    if let callSign = vessel.callSign?.trimmingCharacters(in: .whitespacesAndNewlines), !callSign.isEmpty {
                        row(String(localized: "ais_detail_callsign"), callSign)
                    }
                    if let type = AisFormatting.shipTypeLabel(code: vessel.shipTypeCode) {
                        row(String(localized: "ais_detail_type"), type)
                    }
                    if let nav = AisFormatting.navStatusLabel(code: vessel.navStatusCode) {
                        row(String(localized: "ais_detail_status"), nav)
                    }
                }

                if hasVoyageSection {
                    Section(String(localized: "ais_detail_voyage")) {
                        if let dest = AisFormatting.formatDestination(vessel.destination) {
                            row(String(localized: "ais_detail_destination"), dest)
                        }
                        if let draught = AisFormatting.formatDraughtMeters(vessel.draughtTenthsM) {
                            row(String(localized: "ais_detail_draught"), draught)
                        }
                        if let eta = AisFormatting.formatEta(vessel.etaRaw) {
                            row(String(localized: "ais_detail_eta"), eta)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "ais_detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "disclaimer_nav_ok")) { dismiss() }
                }
            }
        }
    }

    private var hasVoyageSection: Bool {
        AisFormatting.formatDestination(vessel.destination) != nil
            || AisFormatting.formatDraughtMeters(vessel.draughtTenthsM) != nil
            || AisFormatting.formatEta(vessel.etaRaw) != nil
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label, value: value)
    }
}
