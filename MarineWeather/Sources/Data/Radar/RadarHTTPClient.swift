import Foundation

enum RadarHTTPClient {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    static func getData(url: URL, accept: String? = "application/json") async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(AppConfig.weatherUserAgent, forHTTPHeaderField: "User-Agent")
        if let accept {
            request.setValue(accept, forHTTPHeaderField: "Accept")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw WeatherHTTPError.notHTTP
        }
        return data
    }

    static func getText(url: URL) async throws -> String {
        let data = try await getData(url: url, accept: "*/*")
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Lightweight probe (Android `probeImageOk`).
    static func probeResourceExists(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.setValue(AppConfig.weatherUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        request.httpMethod = "GET"
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200 ..< 300).contains(http.statusCode) || http.statusCode == 206
        } catch {
            return false
        }
    }
}
