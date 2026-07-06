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
                precipitationMmPerH: tuple.precipitationMmPerH,
                thunderProbPercent: nil,
                weatherSymbolCode: tuple.weatherSymbolCode
            )
        }
    }

    private struct FmiTuple {
        let weatherSymbolCode: Int?
        let airTempC: Double
        let windSpeedMs: Double
        let windFromDeg: Double
        let windGustMs: Double?
        let precipitationMmPerH: Double?
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
        let lines = block
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let firstLine = lines.first else { return [] }

        let columnCount = firstLine.split(whereSeparator: \.isWhitespace).count
        let usesWeatherSymbol = columnCount >= 6

        return lines.compactMap { line -> FmiTuple? in
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 4 else { return nil }

            if usesWeatherSymbol, parts.count >= 6,
               let symbol = intValue(parts[0]),
               let temp = Double(parts[1]),
               let speed = Double(parts[2]),
               let direction = Double(parts[3]) {
                let gust = parts.count > 4 ? Double(parts[4]) : nil
                let precip = parts.count > 5 ? Double(parts[5]) : nil
                return FmiTuple(
                    weatherSymbolCode: symbol,
                    airTempC: temp,
                    windSpeedMs: speed,
                    windFromDeg: direction,
                    windGustMs: gust.flatMap { $0.isNaN ? nil : $0 },
                    precipitationMmPerH: precip.flatMap { $0.isNaN ? nil : $0 }
                )
            }

            guard let temp = Double(parts[0]),
                  let speed = Double(parts[1]),
                  let direction = Double(parts[2]) else {
                return nil
            }
            let gust = parts.count > 3 ? Double(parts[3]) : nil
            return FmiTuple(
                weatherSymbolCode: nil,
                airTempC: temp,
                windSpeedMs: speed,
                windFromDeg: direction,
                windGustMs: gust.flatMap { $0.isNaN ? nil : $0 },
                precipitationMmPerH: nil
            )
        }
    }

    private static func intValue(_ string: String) -> Int? {
        if let value = Int(string) { return value }
        guard let value = Double(string), !value.isNaN else { return nil }
        return Int(value.rounded())
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
