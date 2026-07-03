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

  /// Nearest forecast step to each target instant (epoch millis).
  static func sampleAtTargetMillis(
    points: [UnifiedTimePoint],
    targetsMillis: [Int64]
  ) -> [UnifiedTimePoint?] {
    guard !points.isEmpty else { return targetsMillis.map { _ in nil } }
    return targetsMillis.map { target in
      points.min(by: { abs($0.instantUtc - target) < abs($1.instantUtc - target) })
    }
  }

  /// One sample per local calendar day (today + next days), closest to local noon.
  static func sampleDailyNearLocalNoon(
    points: [UnifiedTimePoint],
    timeZone: TimeZone = .current,
    numDays: Int = 13
  ) -> [UnifiedTimePoint?] {
    guard numDays > 0 else { return [] }
    guard !points.isEmpty else { return Array(repeating: nil, count: numDays) }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let todayStart = calendar.startOfDay(for: Date())

    return (0..<numDays).map { offset in
      guard let dayStart = calendar.date(byAdding: .day, value: offset, to: todayStart),
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart),
            let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)
      else { return nil }

      let dayStartMs = Int64(dayStart.timeIntervalSince1970 * 1000)
      let dayEndMs = Int64(dayEnd.timeIntervalSince1970 * 1000)
      let noonMs = Int64(noon.timeIntervalSince1970 * 1000)
      let inDay = points.filter { $0.instantUtc >= dayStartMs && $0.instantUtc < dayEndMs }
      guard !inDay.isEmpty else { return nil }
      return inDay.min(by: { abs($0.instantUtc - noonMs) < abs($1.instantUtc - noonMs) })
    }
  }
}
