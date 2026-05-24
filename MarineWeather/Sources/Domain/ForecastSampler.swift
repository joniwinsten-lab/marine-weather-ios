import Foundation

enum ForecastSampler {
  /// Picks the forecast step closest to reference + offset hours (0, 3, 6, 12).
  static func sampleAtOffsets(
    points: [UnifiedTimePoint],
    referenceMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
    offsetsHours: [Int] = [0, 3, 6, 12]
  ) -> [UnifiedTimePoint?] {
    guard !points.isEmpty else { return offsetsHours.map { _ in nil } }
    return offsetsHours.map { hours in
      let target = referenceMillis + Int64(hours) * 3_600_000
      return points.min(by: { abs($0.instantUtc - target) < abs($1.instantUtc - target) })
    }
  }
}
