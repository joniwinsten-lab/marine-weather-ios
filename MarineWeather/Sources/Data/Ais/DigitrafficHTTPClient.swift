import Foundation

/// HTTP client for Fintraffic Digitraffic Marine AIS API (requires `Digitraffic-User` header).
enum DigitrafficHTTPClient {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    static func getData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(AppConfig.digitrafficUser, forHTTPHeaderField: "Digitraffic-User")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw WeatherHTTPError.notHTTP
        }
        return data
    }
}
