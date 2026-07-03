import Foundation

/// Shared HTTP disk cache for map tile warmup (Android `MapHttp.kt`).
enum MapHTTPConfiguration {
    static let cacheByteCount = 50 * 1024 * 1024

    static func install() {
        URLCache.shared = URLCache(
            memoryCapacity: cacheByteCount / 4,
            diskCapacity: cacheByteCount
        )
    }

    static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 12
        return URLSession(configuration: config)
    }()
}
