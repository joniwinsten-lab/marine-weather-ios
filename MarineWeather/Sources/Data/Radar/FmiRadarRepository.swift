import Foundation

/// Latest radar mosaic time from FMI WMS capabilities (Android `FmiRadarRepository.kt`).
enum FmiRadarRepository {
    private static let capabilitiesURL =
        "https://openwms.fmi.fi/geoserver/wms?service=WMS&version=1.3.0&request=GetCapabilities"
    private static let cacheTTLMs: Int64 = 5 * 60 * 1000
    private static let timeDimensionPattern = try! NSRegularExpression(
        pattern: #"<Dimension name="time"[^>]*>([^<]+)</Dimension>"#,
        options: .caseInsensitive
    )

    private static var cachedInstant: Date?
    private static var cachedAtMs: Int64 = 0

    static func latestRadarInstant() async -> Date? {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        if let cached = cachedInstant, nowMs - cachedAtMs < cacheTTLMs {
            return cached
        }
        guard let dimension = await fetchTimeDimension() else { return nil }
        let parsed = FmiRadarTimeSeries.parseDimensionEnd(dimension)
        cachedInstant = parsed
        cachedAtMs = nowMs
        return parsed
    }

    private static func fetchTimeDimension() async -> String? {
        guard let url = URL(string: capabilitiesURL) else { return nil }
        do {
            let xml = try await WeatherHTTPClient.fetchText(url: url, accept: "application/xml,*/*")
            let ns = xml as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = timeDimensionPattern.firstMatch(in: xml, range: range),
                  match.numberOfRanges > 1 else {
                return nil
            }
            return ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
