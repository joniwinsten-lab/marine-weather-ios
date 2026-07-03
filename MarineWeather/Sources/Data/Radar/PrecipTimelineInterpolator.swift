import Foundation

/// Time-interpolates precipitation grids (Android `PrecipTimelineInterpolator.kt`).
enum PrecipTimelineInterpolator {
    static func gribRatesAt(
        fields: [FmiHarmonieGribParser.PrecipField],
        target: Date
    ) -> [[Double]]? {
        guard !fields.isEmpty else { return nil }
        let sorted = fields.sorted { $0.validity < $1.validity }
        let targetMs = Int64(target.timeIntervalSince1970 * 1000)
        let first = sorted[0]
        let last = sorted[sorted.count - 1]
        let firstMs = Int64(first.validity.timeIntervalSince1970 * 1000)
        let lastMs = Int64(last.validity.timeIntervalSince1970 * 1000)

        if targetMs <= firstMs {
            return mmGridToRatesMmPerH(first.amountMm, stepMinutes: first.stepMinutes)
        }
        if targetMs >= lastMs {
            return mmGridToRatesMmPerH(last.amountMm, stepMinutes: last.stepMinutes)
        }

        guard let beforeIdx = sorted.lastIndex(where: {
            Int64($0.validity.timeIntervalSince1970 * 1000) <= targetMs
        }), beforeIdx + 1 < sorted.count else {
            return mmGridToRatesMmPerH(last.amountMm, stepMinutes: last.stepMinutes)
        }

        let a = sorted[beforeIdx]
        let b = sorted[beforeIdx + 1]
        let spanMs = Int64(b.validity.timeIntervalSince1970 * 1000) -
            Int64(a.validity.timeIntervalSince1970 * 1000)
        guard spanMs > 0 else {
            return mmGridToRatesMmPerH(a.amountMm, stepMinutes: a.stepMinutes)
        }
        let weightB = Double(targetMs - Int64(a.validity.timeIntervalSince1970 * 1000)) / Double(spanMs)
        let blended = blendMmGrids(a.amountMm, b.amountMm, weightB: weightB) ?? a.amountMm
        let stepMinutes = max(a.stepMinutes, b.stepMinutes)
        return mmGridToRatesMmPerH(blended, stepMinutes: stepMinutes)
    }

    static func wfsRatesAt(
        series: [[[FmiPrecipitationStep]]],
        target: Date,
        stepMinutes: Int
    ) -> [[Double]] {
        let targetMs = Int64(target.timeIntervalSince1970 * 1000)
        let cells = series.count
        return (0 ..< cells).map { row in
            (0 ..< cells).map { col in
                let steps = series[row][col]
                let mm = interpolateStepAmountMm(steps, targetMs: targetMs) ?? 0
                let hours = Double(stepMinutes) / 60.0
                return hours <= 0 ? mm : mm / hours
            }
        }
    }

    private static func interpolateStepAmountMm(
        _ steps: [FmiPrecipitationStep],
        targetMs: Int64
    ) -> Double? {
        guard !steps.isEmpty else { return nil }
        if steps.count == 1 { return steps[0].amountMm }
        let sorted = steps.sorted { $0.epochMs < $1.epochMs }
        if targetMs <= sorted[0].epochMs { return sorted[0].amountMm }
        if targetMs >= sorted.last!.epochMs { return sorted.last!.amountMm }
        guard let beforeIdx = sorted.lastIndex(where: { $0.epochMs <= targetMs }),
              beforeIdx + 1 < sorted.count else {
            return sorted.last?.amountMm
        }
        let a = sorted[beforeIdx]
        let b = sorted[beforeIdx + 1]
        let span = b.epochMs - a.epochMs
        if span <= 0 { return a.amountMm }
        let weightB = Double(targetMs - a.epochMs) / Double(span)
        return a.amountMm * (1 - weightB) + b.amountMm * weightB
    }

    private static func blendMmGrids(
        _ a: [[Double]],
        _ b: [[Double]],
        weightB: Double
    ) -> [[Double]]? {
        guard !a.isEmpty, !b.isEmpty, a.count == b.count, a[0].count == b[0].count else {
            return nil
        }
        let w = min(max(weightB, 0), 1)
        var out = [[Double]]()
        out.reserveCapacity(a.count)
        for row in 0 ..< a.count {
            var line = [Double]()
            line.reserveCapacity(a[row].count)
            for col in 0 ..< a[row].count {
                line.append(a[row][col] * (1 - w) + b[row][col] * w)
            }
            out.append(line)
        }
        return out
    }

    private static func mmGridToRatesMmPerH(_ mm: [[Double]], stepMinutes: Int) -> [[Double]] {
        let hours = Double(stepMinutes) / 60.0
        var out = [[Double]]()
        out.reserveCapacity(mm.count)
        for row in mm {
            var line = [Double]()
            line.reserveCapacity(row.count)
            for amount in row {
                line.append(hours <= 0 ? amount : amount / hours)
            }
            out.append(line)
        }
        return out
    }
}
