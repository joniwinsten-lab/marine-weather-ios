import Foundation

/// Short on-screen outlook (about two sentences), prioritising warnings (Android `MarineTextSummarizer`).
enum MarineTextSummarizer {
    private static let warningHint = try! NSRegularExpression(
        pattern: #"(?i)\b(warning|varoitus|varning|alert|gale|storm|kuling|hazard|ice\s+warning|wind\s+warning|polarlow)\b"#
    )
    private static let sentenceSplit = try! NSRegularExpression(pattern: #"(?<=[.!?])\s+"#)

    static func summarize(_ raw: String, maxSentences: Int = 2) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if normalized.isEmpty { return "" }

        let sentences = splitSentences(normalized)
        if sentences.isEmpty {
            if normalized.count > 280 {
                return String(normalized.prefix(280)) + "…"
            }
            return normalized
        }

        let warnings = sentences.filter { containsWarningHint($0) }
        let rest = sentences.filter { !containsWarningHint($0) }
        let picked = (warnings + rest).prefix(maxSentences)
        let joined = picked.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".!?")) }.joined(separator: ". ")
        return joined.isEmpty ? "" : joined + "."
    }

    private static func splitSentences(_ text: String) -> [String] {
        let ns = text as NSString
        let matches = sentenceSplit.matches(in: text, range: NSRange(location: 0, length: ns.length))
        var parts: [String] = []
        var lastEnd = 0
        for match in matches {
            let end = match.range.location
            if end > lastEnd {
                parts.append(ns.substring(with: NSRange(location: lastEnd, length: end - lastEnd)))
            }
            lastEnd = match.range.location + match.range.length
        }
        if lastEnd < ns.length {
            parts.append(ns.substring(from: lastEnd))
        }
        if parts.isEmpty {
            parts = [text]
        }
        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 10 }
    }

    private static func containsWarningHint(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return warningHint.firstMatch(in: text, range: range) != nil
    }
}
