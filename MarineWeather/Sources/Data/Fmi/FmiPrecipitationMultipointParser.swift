import Foundation

/// Parses FMI WFS multipoint precipitation coverage (Android `FmiPrecipitationMultipointParser.kt`).
enum FmiPrecipitationMultipointParser {
    static func parse(_ xml: String) throws -> [FmiPrecipitationStep] {
        if xml.localizedCaseInsensitiveContains("ExceptionReport") {
            throw FmiForecastError.fmiErrorResponse
        }
        guard let positions = extractTag("gmlcov:positions", in: xml) else {
            throw FmiForecastError.missingPositions
        }
        guard let tuples = extractTag("gml:doubleOrNilReasonTupleList", in: xml) else {
            throw FmiForecastError.missingTuples
        }
        let epochs = parsePositionEpochs(positions)
        let amounts = parseAmounts(tuples)
        guard epochs.count == amounts.count else {
            throw FmiForecastError.countMismatch(epochs: epochs.count, tuples: amounts.count)
        }
        return zip(epochs, amounts).map { FmiPrecipitationStep(epochMs: $0, amountMm: $1) }
    }

    private static func extractTag(_ tag: String, in xml: String) -> String? {
        let open = "<\(tag)"
        guard let openRange = xml.range(of: open, options: .caseInsensitive),
              let gt = xml.range(of: ">", range: openRange.upperBound ..< xml.endIndex),
              let close = xml.range(of: "</\(tag)>", options: .caseInsensitive, range: gt.upperBound ..< xml.endIndex)
        else { return nil }
        return String(xml[gt.upperBound ..< close.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parsePositionEpochs(_ block: String) -> [Int64] {
        block
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> Int64? in
                let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count >= 3, let seconds = TimeInterval(parts[2]) else { return nil }
                return Int64(seconds * 1000)
            }
    }

    private static func parseAmounts(_ block: String) -> [Double] {
        block
            .split(whereSeparator: \.isNewline)
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.compare("nan", options: .caseInsensitive) == .orderedSame { return 0 }
                return Double(trimmed) ?? 0
            }
    }
}

enum FmiForecastError: LocalizedError {
    case fmiErrorResponse
    case missingPositions
    case missingTuples
    case countMismatch(epochs: Int, tuples: Int)

    var errorDescription: String? {
        switch self {
        case .fmiErrorResponse: "FMI forecast error response"
        case .missingPositions: "FMI precipitation positions missing"
        case .missingTuples: "FMI precipitation values missing"
        case .countMismatch(let e, let t): "FMI precip positions \(e) != tuples \(t)"
        }
    }
}
