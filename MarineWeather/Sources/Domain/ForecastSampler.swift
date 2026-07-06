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

  /// Nearest forecast step for each of the next `hours` whole hours from now.
  static func sampleHourlyNext(
    points: [UnifiedTimePoint],
    hours: Int = 24,
    referenceMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
    timeZone: TimeZone = .current
  ) -> [(label: String, point: UnifiedTimePoint?)] {
    guard hours > 0, !points.isEmpty else { return [] }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let referenceDate = Date(timeIntervalSince1970: TimeInterval(referenceMillis) / 1000)
    let hourStart = calendar.dateInterval(of: .hour, for: referenceDate)?.start ?? referenceDate

    let targets: [Int64] = (0 ..< hours).compactMap { offset in
      guard let target = calendar.date(byAdding: .hour, value: offset, to: hourStart) else { return nil }
      return Int64(target.timeIntervalSince1970 * 1000)
    }

    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "HH:mm"

    var minInstant: Int64 = 0
    return targets.enumerated().map { index, target in
      let eligible = points.filter { $0.instantUtc >= minInstant }
      let pool = eligible.isEmpty ? points : eligible
      let point = pool.min(by: { abs($0.instantUtc - target) < abs($1.instantUtc - target) })
      if let point {
        minInstant = point.instantUtc
      }

      let date = Date(timeIntervalSince1970: TimeInterval(target) / 1000)
      let label = index == 0
        ? String(localized: "weather_now")
        : formatter.string(from: date)
      return (label, point)
    }
  }

  /// One sample per local day (today + next days) with human-readable labels.
  /// Skips today when hourly data already covers the next 24 hours.
  static func sampleDailyWithLabels(
    points: [UnifiedTimePoint],
    numDays: Int = 7,
    timeZone: TimeZone = .current,
    skipToday: Bool = true
  ) -> [(label: String, point: UnifiedTimePoint?)] {
    let startOffset = skipToday ? 1 : 0
    let samples = sampleDailyNearLocalNoon(
      points: points,
      timeZone: timeZone,
      numDays: numDays + startOffset
    )
    let daySamples = Array(samples.dropFirst(startOffset))

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let todayStart = calendar.startOfDay(for: Date())

    let weekdayFormatter = DateFormatter()
    weekdayFormatter.timeZone = timeZone
    weekdayFormatter.setLocalizedDateFormatFromTemplate("EEE")

    return daySamples.enumerated().map { index, point in
      let dayOffset = index + startOffset
      let label: String
      switch dayOffset {
      case 0:
        label = String(localized: "weather_day_today")
      case 1:
        label = String(localized: "weather_day_tomorrow")
      default:
        if let date = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) {
          label = weekdayFormatter.string(from: date)
        } else {
          label = "—"
        }
      }
      return (label, point)
    }
  }
}
