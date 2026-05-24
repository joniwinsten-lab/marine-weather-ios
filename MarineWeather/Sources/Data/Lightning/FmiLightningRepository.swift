import Foundation

enum FmiLightningRepository {
    private static let storedQuery = "fmi::observations::lightning::simple"
    private static let lookbackMinutes = 120

    static func fetchRecentStrikes(
        lonMin: Double = 19,
        latMin: Double = 59,
        lonMax: Double = 32,
        latMax: Double = 71
    ) async -> Result<[LightningStrike], Error> {
        do {
            let end = Date()
            let start = Calendar.current.date(byAdding: .minute, value: -lookbackMinutes, to: end) ?? end
            var components = URLComponents(string: "https://opendata.fmi.fi/wfs")!
            components.queryItems = [
                URLQueryItem(name: "request", value: "getFeature"),
                URLQueryItem(name: "storedquery_id", value: storedQuery),
                URLQueryItem(name: "starttime", value: FmiInstantFormat.toParam(start)),
                URLQueryItem(name: "endtime", value: FmiInstantFormat.toParam(end)),
                URLQueryItem(name: "bbox", value: "\(lonMin),\(latMin),\(lonMax),\(latMax)"),
            ]
            let data = try await WeatherHTTPClient.fetchBody(url: components.url!)
            guard let xml = String(data: data, encoding: .utf8) else {
                return .failure(WeatherHTTPError.invalidBody)
            }
            return .success(FmiLightningParser.parse(xml))
        } catch {
            return .failure(error)
        }
    }
}
