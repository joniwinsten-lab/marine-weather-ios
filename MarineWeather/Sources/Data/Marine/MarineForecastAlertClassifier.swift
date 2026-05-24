import Foundation

/// Detects marine warnings or softer notices in source text (Android `MarineForecastAlertClassifier`).
enum MarineForecastAlertClassifier {
    private static let noWarningsLine = try! NSRegularExpression(
        pattern: #"(?i)^\s*(no\s+warnings?|ingen\s+varningar?|inga\s+varningar?|ei\s+varoituksia?|varoituksia\s+ei|uten\s+varsler?)\s*\.?\s*$"#
    )

    private static let warningPatterns: [NSRegularExpression] = [
        #"(?i)\b(wind\s+warning|ice\s+warning|polarlow\s+warning|polarlow)\b"#,
        #"(?i)\b(warning|varoitus|varning|varsel)\b"#,
        #"(?i)\b(near\s+)?gale\s+\d"#,
        #"(?i)\b(storm|hurricane)\s+\d"#,
        #"(?i)\b(strong\s+wind|kova\s+tuuli|hård\s+vind)\s+(warning|varoitus|varning)"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    private static let noticePatterns: [NSRegularExpression] = [
        #"(?i)\b(risk\s+of|possible|locally|attention|caution|observe)\b"#,
        #"(?i)\b(huomio|huomautus|anmärkning|merknad|bemerkning)\b"#,
        #"(?i)\b(fog|sumu|tåke|tåka|uku|visibility|näkyvyys|sikt)\b"#,
        #"(?i)\b(poor\s+visibility|reduced\s+visibility|näkyvyys\s+heikko)"#,
        #"(?i)\b(moderate|rough|very\s+rough|kova\s+aallokko)\b"#,
        #"(?i)\b(showers?|sleet|thunder|ukkonen|åska)\b"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    static func classify(
        rawText: String,
        metWindWarning: String? = nil,
        metIceWarning: String? = nil,
        metPolarlowWarning: String? = nil
    ) -> MarineForecastAlertLevel {
        if [metWindWarning, metIceWarning, metPolarlowWarning].contains(where: { !($0 ?? "").isEmpty }) {
            return .warning
        }

        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text.hasPrefix("At the map centre:") {
            return .none
        }
        if containsWarning(text) { return .warning }
        if containsNotice(text) { return .notice }
        return .none
    }

    private static func containsWarning(_ text: String) -> Bool {
        for line in text.lines where !line.isEmpty {
            if matches(noWarningsLine, line) { continue }
            for pattern in warningPatterns where matches(pattern, line) {
                if !isBenignWarningMention(line) { return true }
            }
        }
        return false
    }

    private static func containsNotice(_ text: String) -> Bool {
        if noWarningsOnlyReport(text) { return false }
        return noticePatterns.contains { matches($0, text) }
    }

    private static func noWarningsOnlyReport(_ text: String) -> Bool {
        let alertLines = text.lines.filter { line in
            !line.isEmpty && (
                matches(noWarningsLine, line) ||
                warningPatterns.contains { matches($0, line) } ||
                noticePatterns.contains { matches($0, line) }
            )
        }
        return !alertLines.isEmpty && alertLines.allSatisfy { matches(noWarningsLine, $0) }
    }

    private static func isBenignWarningMention(_ line: String) -> Bool {
        matches(noWarningsLine, line) ||
            line.range(of: #"(?i)without\s+warning"#, options: .regularExpression) != nil
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}

private extension String {
    var lines: [String] {
        components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
