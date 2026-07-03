import Foundation

/// SMHI open radar PNG (Android `SmhiRadarRepository.kt`).
enum SmhiRadarRepository {
    private static let baseURL = "https://data-download.smhi.se/data/meteorology/radar"
    private static let filePattern = #"RADAR_SWE_EPSG3006_QCOMP_(\d{12})\.png"#

    static let smhiBounds = RadarGeoBounds(
        northLat: 69.5,
        westLon: 10.0,
        southLat: 54.5,
        eastLon: 25.0
    )

    static func loadLatestOverlay() async -> ActiveRadarOverlay? {
        guard let fileName = await fetchLatestFileName() else { return nil }
        let url = URL(string: "\(baseURL)/\(fileName)")!
        guard await RadarHTTPClient.probeResourceExists(url: url) else { return nil }
        let time = parseTime(from: fileName)
        return ActiveRadarOverlay(
            sourceId: .smhi,
            kind: .geoImage,
            sourceLabel: "SMHI",
            timeLabel: time.map { FmiInstantFormat.toDisplayHHmm($0) } ?? fileName,
            wmsTileUrlTemplate: nil,
            geoImageUrl: url.absoluteString,
            geoBounds: smhiBounds
        )
    }

    private static func fetchLatestFileName() async -> String? {
        let names = await fetchRecentFileNames(limit: 1)
        return names.last
    }

    private static func fetchRecentFileNames(limit: Int) async -> [String] {
        guard let url = URL(string: "\(baseURL)/") else { return [] }
        do {
            let html = try await RadarHTTPClient.getText(url: url)
            let regex = try NSRegularExpression(pattern: filePattern)
            let range = NSRange(html.startIndex..., in: html)
            let matches =
                regex
                .matches(in: html, range: range)
                .compactMap { match -> String? in
                    guard let r = Range(match.range, in: html) else { return nil }
                    return String(html[r])
                }
            return Array(Set(matches)).sorted().suffix(limit).map { String($0) }
        } catch {
            return []
        }
    }

    private static func parseTime(from fileName: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: filePattern),
              let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: fileName) else {
            return nil
        }
        let raw = String(fileName[range])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter.date(from: raw)
    }
}
