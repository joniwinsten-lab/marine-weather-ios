import Foundation

extension WeatherHTTPClient {
    /// Generic GET for marine text (JSON or XML); URLSession decompresses gzip automatically.
    static func fetchBody(
        url: URL,
        accept: String = "application/json, text/xml;q=0.9, */*;q=0.8",
        timeoutSeconds: TimeInterval = 25
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(AppConfig.weatherUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeoutSeconds

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WeatherHTTPError.notHTTP
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw WeatherHTTPError.statusCode(http.statusCode)
        }
        return data
    }

    static func fetchText(
        url: URL,
        accept: String = "application/json, text/xml;q=0.9, */*;q=0.8"
    ) async throws -> String {
        let data = try await fetchBody(url: url, accept: accept)
        guard let text = String(data: data, encoding: .utf8) else {
            throw WeatherHTTPError.invalidBody
        }
        return text
    }
}
