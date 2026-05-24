import Foundation

enum FmiLightningParser {
    private static let memberBlock = try! NSRegularExpression(
        pattern: #"<wfs:member>([\s\S]*?)</wfs:member>"#,
        options: .caseInsensitive
    )
    private static let gmlPos = try! NSRegularExpression(
        pattern: #"<gml:pos[^>]*>\s*([-\d.]+)\s+([-\d.]+)\s*</gml:pos>"#,
        options: .caseInsensitive
    )
    private static let timeTag = try! NSRegularExpression(
        pattern: #"<BsWfs:Time[^>]*>([^<]+)</BsWfs:Time>"#,
        options: .caseInsensitive
    )
    private static let lonParam = try! NSRegularExpression(
        pattern: #"<BsWfs:Parameter[^>]*name="longitude"[^>]*values="([-\d.]+)""#,
        options: .caseInsensitive
    )
    private static let latParam = try! NSRegularExpression(
        pattern: #"<BsWfs:Parameter[^>]*name="latitude"[^>]*values="([-\d.]+)""#,
        options: .caseInsensitive
    )

    static func parse(_ xml: String) -> [LightningStrike] {
        let ns = xml as NSString
        var out: [LightningStrike] = []
        let range = NSRange(location: 0, length: ns.length)
        memberBlock.enumerateMatches(in: xml, range: range) { match, _, _ in
            guard let match else { return }
            let inner = ns.substring(with: match.range(at: 1))
            let innerNS = inner as NSString
            let epoch = firstMatch(timeTag, in: inner).flatMap { parseTime($0) }
                ?? Int64(Date().timeIntervalSince1970 * 1000)

            if let pos = firstMatchGroups(gmlPos, in: inner, count: 3),
               let a = Double(pos[1]),
               let b = Double(pos[2]) {
                addStrike(&out, first: a, second: b, epoch: epoch)
                return
            }
            if let lon = firstMatch(lonParam, in: inner).flatMap(Double.init),
               let lat = firstMatch(latParam, in: inner).flatMap(Double.init) {
                addStrike(&out, first: lon, second: lat, epoch: epoch)
            }
        }
        return out
    }

    private static func addStrike(
        _ out: inout [LightningStrike],
        first: Double,
        second: Double,
        epoch: Int64
    ) {
        let (lat, lon) = inferLatLon(first, second)
        if (50.0 ... 72.0).contains(lat), (10.0 ... 40.0).contains(lon) {
            out.append(
                LightningStrike(
                    latitude: lat,
                    longitude: lon,
                    observedAtEpochMs: epoch,
                    source: .fmi
                )
            )
        }
    }

    private static func inferLatLon(_ a: Double, _ b: Double) -> (Double, Double) {
        let asLonLat = (10.0 ... 40.0).contains(a) && (50.0 ... 72.0).contains(b)
        let asLatLon = (50.0 ... 72.0).contains(a) && (10.0 ... 40.0).contains(b)
        switch (asLonLat, asLatLon) {
        case (true, _): return (b, a)
        case (_, true): return (a, b)
        default: return b > a ? (a, b) : (b, a)
        }
    }

    private static func parseTime(_ raw: String) -> Int64? {
        ISO8601Parser.epochMillis(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> String? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return ns.substring(with: m.range(at: 1))
    }

    private static func firstMatchGroups(
        _ regex: NSRegularExpression,
        in text: String,
        count: Int
    ) -> [String]? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges >= count else {
            return nil
        }
        return (1 ..< count).map { ns.substring(with: m.range(at: $0)) }
    }
}
