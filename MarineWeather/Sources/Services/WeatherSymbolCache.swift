import UIKit

/// Loads FMI smart-symbol PNGs from CDN with in-memory cache.
@MainActor
final class WeatherSymbolCache {
    static let shared = WeatherSymbolCache()

    private var images: [Int: UIImage] = [:]
    private var inflight: [Int: Task<UIImage?, Never>] = [:]

    private init() {}

    func image(for code: Int) async -> UIImage? {
        if let cached = images[code] { return cached }
        if let task = inflight[code] { return await task.value }

        let task = Task<UIImage?, Never> {
            await loadFromCDN(code: code)
        }
        inflight[code] = task
        let image = await task.value
        inflight[code] = nil
        if let image { images[code] = image }
        return image
    }

    private func loadFromCDN(code: Int) async -> UIImage? {
        let cdnCode = FmiWeatherSymbol.normalizedCDNCode(code)
        guard let url = URL(string: "https://cdn.fmi.fi/symbol-images/smartsymbol/v3/p/\(cdnCode).png") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200 ..< 300).contains(http.statusCode),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
}
