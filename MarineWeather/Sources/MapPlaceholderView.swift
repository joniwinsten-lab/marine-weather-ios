import SwiftUI

/// Placeholder until MapLibre SPM is linked (see docs/SETUP.md).
struct MapPlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.quaternary)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.title2)
                    Text("Map")
                        .font(.headline)
                    Text(AppConfig.mapStyleURL.host ?? "OpenFreeMap")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
    }
}

#Preview {
    MapPlaceholderView()
        .padding()
}
