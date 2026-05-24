import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "water.waves")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                Text(AppConfig.appDisplayName)
                    .font(.title.bold())
                Text("iOS build — iPad landscape")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                MapPlaceholderView()
                Text("Phase 1: add MapLibre via SPM, then weather layers.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle(AppConfig.appDisplayName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
