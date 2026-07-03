import SwiftUI

/// Toggle for premium AIS overlay on Compare / Route maps.
struct AisMapChip: View {
    @Bindable var ais: AisMapViewModel
    var premium: Bool
    var onNeedPremium: () -> Void
    var onEnabled: () -> Void

    private var isOn: Bool { premium && ais.isEnabled }

    var body: some View {
        Button {
            if premium {
                let wasEnabled = ais.isEnabled
                ais.toggle(premium: true)
                if ais.isEnabled, !wasEnabled {
                    onEnabled()
                }
            } else {
                onNeedPremium()
            }
        } label: {
            MapOverlayChrome.chipLabel(isOn: isOn) {
                HStack(spacing: 4) {
                    if !premium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                    } else {
                        streamIndicator
                    }
                    Text(String(localized: "ais_chip"))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "ais_chip_accessibility"))
    }

    @ViewBuilder
    private var streamIndicator: some View {
        switch ais.streamMode {
        case .live:
            Circle()
                .fill(Color(red: 0.26, green: 0.63, blue: 0.28))
                .frame(width: 7, height: 7)
                .accessibilityLabel(String(localized: "ais_chip_live"))
        case .restOnly:
            Circle()
                .fill(Color(red: 0.18, green: 0.49, blue: 0.20))
                .frame(width: 7, height: 7)
                .accessibilityLabel(String(localized: "ais_chip_active"))
        case .connecting:
            Circle()
                .fill(Color(red: 0.96, green: 0.49, blue: 0.0))
                .frame(width: 7, height: 7)
                .accessibilityLabel(String(localized: "ais_chip_rest"))
        case .error:
            Circle()
                .fill(Color(red: 0.78, green: 0.16, blue: 0.16))
                .frame(width: 7, height: 7)
                .accessibilityLabel(String(localized: "ais_chip_error"))
        case .off:
            EmptyView()
        }
    }
}
