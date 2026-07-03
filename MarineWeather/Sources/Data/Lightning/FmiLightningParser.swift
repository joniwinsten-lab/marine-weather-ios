import Foundation

/// Parses FMI WFS 2.0 simple-feature lightning responses (gml:pos and BsWfs parameters).
/// Uses string scanning — not whole-document `NSRegularExpression` (can crash on large WFS payloads).
enum FmiLightningParser {
    private static let memberOpen = "<wfs:member>"
    private static let memberClose = "</wfs:member>"
    private static let maxStrikes = 3_000

    static func parse(_ xml: String) -> [LightningStrike] {
        var out: [LightningStrike] = []
        out.reserveCapacity(256)
        var searchFrom = xml.startIndex

        while out.count < maxStrikes, searchFrom < xml.endIndex {
            guard let open = xml.range(
                of: memberOpen,
                options: .caseInsensitive,
                range: searchFrom ..< xml.endIndex
            ) else { break }
            guard let close = xml.range(
                of: memberClose,
                options: .caseInsensitive,
                range: open.upperBound ..< xml.endIndex
            ) else { break }

            let inner = String(xml[open.upperBound ..< close.lowerBound])
            if let strike = parseMember(inner) {
                out.append(strike)
            }
            searchFrom = close.upperBound
        }
        return out
    }

    // MARK: - Member parsing

    private static func parseMember(_ inner: String) -> LightningStrike? {
        let epoch = parseTime(extractTagContent(tag: "BsWfs:Time", in: inner))
            ?? Int64(Date().timeIntervalSince1970 * 1000)

        if let pos = extractGmlPos(inner) {
            return strike(first: pos.0, second: pos.1, epoch: epoch)
        }
        if let lon = extractParameterValue(name: "longitude", in: inner),
           let lat = extractParameterValue(name: "latitude", in: inner) {
            return strike(first: lon, second: lat, epoch: epoch)
        }
        return nil
    }

    private static func strike(first: Double, second: Double, epoch: Int64) -> LightningStrike? {
        let (lat, lon) = inferLatLon(first, second)
        guard (50.0 ... 72.0).contains(lat), (10.0 ... 40.0).contains(lon) else { return nil }
        return LightningStrike(
            latitude: lat,
            longitude: lon,
            observedAtEpochMs: epoch,
            source: .fmi
        )
    }

    private static func extractGmlPos(_ text: String) -> (Double, Double)? {
        guard let open = text.range(of: "<gml:pos", options: .caseInsensitive),
              let gt = text.range(of: ">", range: open.upperBound ..< text.endIndex),
              let close = text.range(of: "</gml:pos>", options: .caseInsensitive, range: gt.upperBound ..< text.endIndex)
        else { return nil }

        let content = text[gt.upperBound ..< close.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = content.split(whereSeparator: { $0.isWhitespace || $0 == "\t" })
        guard parts.count >= 2,
              let a = Double(parts[0]),
              let b = Double(parts[1]) else {
            return nil
        }
        return (a, b)
    }

    private static func extractTagContent(tag: String, in text: String) -> String? {
        let open = "<\(tag)"
        guard let openRange = text.range(of: open, options: .caseInsensitive),
              let gt = text.range(of: ">", range: openRange.upperBound ..< text.endIndex),
              let close = text.range(of: "</\(tag)>", options: .caseInsensitive, range: gt.upperBound ..< text.endIndex)
        else { return nil }
        return String(text[gt.upperBound ..< close.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractParameterValue(name: String, in text: String) -> Double? {
        let patterns = [
            "name=\"\(name)\"",
            "name='\(name)'",
            "name=\(name)",
        ]
        for pattern in patterns {
            guard let nameRange = text.range(of: pattern, options: .caseInsensitive) else { continue }
            let tail = text[nameRange.upperBound...]
            if let valuesRange = tail.range(of: "values=\"", options: .caseInsensitive) {
                let after = tail[valuesRange.upperBound...]
                if let end = after.firstIndex(of: "\"") {
                    return Double(after[..<end])
                }
            }
            if let valuesRange = tail.range(of: "values='", options: .caseInsensitive) {
                let after = tail[valuesRange.upperBound...]
                if let end = after.firstIndex(of: "'") {
                    return Double(after[..<end])
                }
            }
        }
        return nil
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

    private static func parseTime(_ raw: String?) -> Int64? {
        guard let raw else { return nil }
        return ISO8601Parser.epochMillis(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
