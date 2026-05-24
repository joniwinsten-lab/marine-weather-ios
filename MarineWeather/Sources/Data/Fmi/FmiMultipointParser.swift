import Foundation

enum FmiMultipointParser {
    private static let positionsBlock = try! NSRegularExpression(
        pattern: "<gmlcov:positions>\\s*([\\s\\S]*?)\\s*</gmlcov:positions>",
        options: [.caseInsensitive]
    )
    private static let tupleBlock = try! NSRegularExpression(
        pattern: "<gml:doubleOrNilReasonTupleList>\\s*([\\s\\S]*?)\\s*</gml:doubleOrNilReasonTupleList>",
        options: [.caseInsensitive]
    )

    static func parse(_ xml: String) throws -> [UnifiedTimePoint] {
        if xml.localizedCaseInsensitiveContains("ExceptionReport") {
            throw FmiParseError.errorResponse
        }

        guard let positionsXml = firstCapture(positionsBlock, in: xml) else {
            throw FmiParseError.missingPositions
        }
        guard let tuplesXml = firstCapture(tupleBlock, in: xml) else {
            throw FmiParseError.missingTuples
        }

        let times = parsePositions(positionsXml)
        let tuples = parseTuples(tuplesXml)
        guard times.count == tuples.count else {
            throw FmiParseError.countMismatch(times: times.count, tuples: tuples.count)
        }

        return zip(times, tuples).map { instant, tuple in
            UnifiedTimePoint(
                instantUtc: instant,
                airTempC: tuple.airTempC,
                windSpeedMs: tuple.windSpeedMs,
                windFromDeg: tuple.windFromDeg,
                windGustMs: tuple.windGustMs,
                precipitationMmPerH: nil,
                thunderProbPercent: nil
            )
        }
    }

    private struct FmiTuple {
        let airTempC: Double
        let windSpeedMs: Double
        let windFromDeg: Double
        let windGustMs: Double?
    }

    private static func firstCapture(_ regex: NSRegularExpression, in text: String) -> String? {
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }

    private static func parsePositions(_ block: String) -> [Int64] {
        block
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> Int64? in
                let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count >= 3, let epoch = Int64(parts[2]) else { return nil }
                return epoch * 1000
            }
    }

    private static func parseTuples(_ block: String) -> [FmiTuple] {
        block
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> FmiTuple? in
                let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
                guard parts.count >= 3,
                      let temp = Double(parts[0]),
                      let speed = Double(parts[1]),
                      let direction = Double(parts[2]) else {
                    return nil
                }
                let gust = parts.count > 3 ? Double(parts[3]) : nil
                return FmiTuple(
                    airTempC: temp,
                    windSpeedMs: speed,
                    windFromDeg: direction,
                    windGustMs: gust.flatMap { $0.isNaN ? nil : $0 }
                )
            }
    }
}

enum FmiParseError: LocalizedError {
    case errorResponse
    case missingPositions
    case missingTuples
    case countMismatch(times: Int, tuples: Int)

    var errorDescription: String? {
        switch self {
        case .errorResponse: "FMI error response"
        case .missingPositions: "FMI positions block missing"
        case .missingTuples: "FMI tuple block missing"
        case .countMismatch(let times, let tuples): "FMI positions \(times) != tuples \(tuples)"
        }
    }
}
