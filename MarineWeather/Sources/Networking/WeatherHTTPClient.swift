import Foundation

/// Shared HTTP client for MET / FMI / SMHI APIs. Sends Android-matching User-Agent.
enum WeatherHTTPClient {
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    static func fetchMetNorway(lat: Double, lon: Double) async throws -> UnifiedForecast {
        let latR = roundCoord(lat, decimals: 4)
        let lonR = roundCoord(lon, decimals: 4)
        var components = URLComponents(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latR)),
            URLQueryItem(name: "lon", value: String(lonR)),
        ]
        let data = try await getData(components.url!)
        let feature = try jsonDecoder.decode(MetFeature.self, from: data)
        return MetMapper.toUnified(feature, fetchedAtUtc: nowMillis())
    }

    static func fetchSmhi(lat: Double, lon: Double) async throws -> UnifiedForecast {
        let lonP = roundCoord(lon, decimals: 3)
        let latP = roundCoord(lat, decimals: 3)
        let url = URL(
            string: "https://opendata-download-metfcst.smhi.se/api/category/snow1g/version/1/geotype/point/lon/\(lonP)/lat/\(latP)/data.json"
        )!
        let data = try await getData(url)
        let response = try jsonDecoder.decode(SmhiPointResponse.self, from: data)
        return SmhiMapper.toUnified(response, fetchedAtUtc: nowMillis())
    }

    static func fetchFmi(lat: Double, lon: Double) async throws -> UnifiedForecast {
        let latP = roundCoord(lat, decimals: 5)
        let lonP = roundCoord(lon, decimals: 5)
        var components = URLComponents(string: "https://opendata.fmi.fi/wfs")!
        components.queryItems = [
            URLQueryItem(name: "request", value: "getFeature"),
            URLQueryItem(name: "storedquery_id", value: "fmi::forecast::harmonie::surface::point::multipointcoverage"),
            URLQueryItem(name: "latlon", value: "\(latP),\(lonP)"),
            URLQueryItem(name: "parameters", value: "temperature,WindSpeedMS,WindDirection,WindGust"),
        ]
        let data = try await getData(components.url!)
        guard let xml = String(data: data, encoding: .utf8) else {
            throw WeatherHTTPError.invalidBody
        }
        let points = try FmiMultipointParser.parse(xml)
        return UnifiedForecast(
            source: WeatherSources.fmi,
            fetchedAtUtc: nowMillis(),
            modelInfo: "HARMONIE surface point",
            points: points
        )
    }

    private static func getData(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(AppConfig.weatherUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WeatherHTTPError.notHTTP
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw WeatherHTTPError.statusCode(http.statusCode)
        }
        return data
    }

    private static func roundCoord(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (value * factor).rounded() / factor
    }

    private static func nowMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}

enum WeatherHTTPError: LocalizedError {
    case notHTTP
    case invalidBody
    case statusCode(Int)

    var errorDescription: String? {
        switch self {
        case .notHTTP:
            "Invalid HTTP response"
        case .invalidBody:
            "Invalid response body"
        case .statusCode(let code):
            "HTTP \(code)"
        }
    }
}
