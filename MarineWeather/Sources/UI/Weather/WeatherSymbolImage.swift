import SwiftUI

struct WeatherSymbolImage: View {
    let symbolCode: Int?
    var size: CGFloat = 40

    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if symbolCode != nil, !loadFailed {
                ProgressView()
                    .controlSize(.small)
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: symbolCode) {
            guard let symbolCode else {
                image = nil
                loadFailed = false
                return
            }
            image = nil
            loadFailed = false
            if let loaded = await WeatherSymbolCache.shared.image(for: symbolCode) {
                image = loaded
            } else {
                loadFailed = true
            }
        }
    }

    private var placeholder: some View {
        Image(systemName: "cloud")
            .font(.system(size: size * 0.55))
            .foregroundStyle(.secondary)
    }
}
