import Foundation

enum SmhiLightningParser {
    static func parse(_ csv: String, lookbackEpochMs: Int64) -> [LightningStrike] {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        guard lines.count >= 2 else { return [] }
        let header = lines[0].split(separator: ";").map(String.init)
        guard let latIdx = header.firstIndex(of: "lat"),
              let lonIdx = header.firstIndex(of: "lon") else {
            return []
        }
        let yearIdx = header.firstIndex(of: "year")
        let monthIdx = header.firstIndex(of: "month")
        let dayIdx = header.firstIndex(of: "day")
        let hourIdx = header.firstIndex(of: "hours")
        let minIdx = header.firstIndex(of: "minutes")
        let secIdx = header.firstIndex(of: "seconds")

        var out: [LightningStrike] = []
        for line in lines.dropFirst() {
            let cols = line.split(separator: ";").map(String.init)
            guard cols.count > max(latIdx, lonIdx),
                  let lat = Double(cols[latIdx]),
                  let lon = Double(cols[lonIdx]),
                  let epoch = parseEpoch(
                    cols: cols,
                    yearIdx: yearIdx,
                    monthIdx: monthIdx,
                    dayIdx: dayIdx,
                    hourIdx: hourIdx,
                    minIdx: minIdx,
                    secIdx: secIdx
                  ),
                  epoch >= lookbackEpochMs,
                  (50.0 ... 72.0).contains(lat),
                  (8.0 ... 40.0).contains(lon) else {
                continue
            }
            out.append(
                LightningStrike(
                    latitude: lat,
                    longitude: lon,
                    observedAtEpochMs: epoch,
                    source: .smhi
                )
            )
        }
        return out
    }

    private static func parseEpoch(
        cols: [String],
        yearIdx: Int?,
        monthIdx: Int?,
        dayIdx: Int?,
        hourIdx: Int?,
        minIdx: Int?,
        secIdx: Int?
    ) -> Int64? {
        guard let yearIdx, let monthIdx, let dayIdx, let hourIdx, let minIdx, let secIdx,
              cols.count > max(yearIdx, monthIdx, dayIdx, hourIdx, minIdx, secIdx),
              let year = Int(cols[yearIdx]),
              let month = Int(cols[monthIdx]),
              let day = Int(cols[dayIdx]),
              let hour = Int(cols[hourIdx]),
              let minute = Int(cols[minIdx]),
              let second = Int(cols[secIdx]) else {
            return nil
        }
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.second = second
        c.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = Calendar(identifier: .gregorian).date(from: c) else { return nil }
        return Int64(date.timeIntervalSince1970 * 1000)
    }
}
