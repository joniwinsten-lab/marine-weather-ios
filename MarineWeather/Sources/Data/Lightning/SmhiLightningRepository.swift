import Foundation

enum SmhiLightningRepository {
    private static let lookbackMinutes = 120

    static func fetchRecentStrikes() async -> Result<[LightningStrike], Error> {
        do {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let now = Date()
            let y = calendar.component(.year, from: now)
            let m = calendar.component(.month, from: now)
            let d = calendar.component(.day, from: now)
            let url = URL(
                string: "https://opendata-download-lightning.smhi.se/api/version/latest/year/\(y)/month/\(m)/day/\(d)/data.csv"
            )!
            let csv = try await WeatherHTTPClient.fetchText(url: url, accept: "text/csv,*/*")
            let lookbackMs = Int64(Date().timeIntervalSince1970 * 1000) - Int64(lookbackMinutes * 60 * 1000)
            let strikes = await Task.detached(priority: .utility) {
                SmhiLightningParser.parse(csv, lookbackEpochMs: lookbackMs)
            }.value
            return .success(strikes)
        } catch {
            return .failure(error)
        }
    }
}
