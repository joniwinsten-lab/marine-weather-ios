import Foundation

/// FMI precipitation forecast rasters for the storm timeline (Android `FmiForecastRadarRepository.kt`).
enum FmiForecastRadarRepository {
    private static let gridHalfSpanDeg = 4.5
    private static let wfsGridCells = 11
    private static let wfsBase = "https://opendata.fmi.fi/wfs"
    private static let storedQueryEdited =
        "fmi::forecast::edited::weather::scandinavia::point::multipointcoverage"
    private static let storedQueryMeps = "fmi::forecast::meps::surface::point::multipointcoverage"
    private static let timestepMinutes = 30
    private static let gribCacheTTLMs: Int64 = 5 * 60 * 1000

    private static var gribCache: GribCache?
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func buildForecastOverlays(
        anchor: Date,
        lat: Double,
        lon: Double
    ) async -> [Int: ForecastRasterOverlay] {
        let bounds = RadarGeoBounds(
            northLat: lat + gridHalfSpanDeg,
            westLon: lon - gridHalfSpanDeg,
            southLat: lat - gridHalfSpanDeg,
            eastLon: lon + gridHalfSpanDeg
        )

        let gribFields = await fetchHarmonieGribFields(anchor: anchor, bounds: bounds)
        if !gribFields.isEmpty {
            let gribOverlays = await Task.detached(priority: .utility) {
                buildOverlaysFromGrib(anchor: anchor, fields: gribFields, bounds: bounds)
            }.value
            if !gribOverlays.isEmpty {
                return gribOverlays
            }
        }

        let grid: PrecipGrid
        do {
            grid = try await fetchPrecipitationGridWfs(lat: lat, lon: lon, anchor: anchor, bounds: bounds)
        } catch {
            return [:]
        }
        return await Task.detached(priority: .utility) {
            buildOverlaysFromWfsGrid(anchor: anchor, grid: grid)
        }.value
    }

    // MARK: - GRIB

    private struct GribCache {
        let minuteBucket: Int64
        let boundsKey: String
        let fields: [FmiHarmonieGribParser.PrecipField]
        let fetchedAtMs: Int64
    }

    private static func fetchHarmonieGribFields(
        anchor: Date,
        bounds: RadarGeoBounds
    ) async -> [FmiHarmonieGribParser.PrecipField] {
        let cacheKey = boundsCacheKey(bounds)
        let minuteBucket = Int64(anchor.timeIntervalSince1970) / 60
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        if let cached = gribCache,
           cached.minuteBucket == minuteBucket,
           cached.boundsKey == cacheKey,
           nowMs - cached.fetchedAtMs < gribCacheTTLMs,
           !cached.fields.isEmpty {
            return cached.fields
        }

        let start = anchor
        let end =
            utcCalendar.date(byAdding: .minute, value: StormRadarTimeline.horizonMinutes, to: anchor) ?? anchor

        for origin in harmonieOriginCandidates(for: anchor) {
            let url = FmiHarmonieGribParser.buildDownloadURL(
                west: bounds.westLon,
                south: bounds.southLat,
                east: bounds.eastLon,
                north: bounds.northLat,
                start: start,
                end: end,
                originTime: origin
            )
            do {
                let data = try await WeatherHTTPClient.fetchBody(
                    url: url,
                    accept: "application/octet-stream,*/*",
                    timeoutSeconds: 45
                )
                guard data.count >= 100, data[data.startIndex] == UInt8(ascii: "G") else {
                    continue
                }
                let fields = FmiHarmonieGribParser.parseAll(data)
                guard !fields.isEmpty else { continue }
                gribCache = GribCache(
                    minuteBucket: minuteBucket,
                    boundsKey: cacheKey,
                    fields: fields,
                    fetchedAtMs: nowMs
                )
                return fields
            } catch {
                continue
            }
        }
        return []
    }

    private static func buildOverlaysFromGrib(
        anchor: Date,
        fields: [FmiHarmonieGribParser.PrecipField],
        bounds: RadarGeoBounds
    ) -> [Int: ForecastRasterOverlay] {
        buildOverlays(
            anchor: anchor,
            bounds: bounds,
            filePrefix: "fc_grib"
        ) { offset in
            guard let target = utcCalendar.date(byAdding: .minute, value: offset, to: anchor) else {
                return nil
            }
            return PrecipTimelineInterpolator.gribRatesAt(fields: fields, target: target)
        }
    }

    // MARK: - WFS fallback

    private struct PrecipGrid {
        let bounds: RadarGeoBounds
        let series: [[[FmiPrecipitationStep]]]
        let stepMinutes: Int
    }

    private static func buildOverlaysFromWfsGrid(
        anchor: Date,
        grid: PrecipGrid
    ) -> [Int: ForecastRasterOverlay] {
        buildOverlays(
            anchor: anchor,
            bounds: grid.bounds,
            filePrefix: "fc_wfs"
        ) { offset in
            guard let target = utcCalendar.date(byAdding: .minute, value: offset, to: anchor) else {
                return nil
            }
            return PrecipTimelineInterpolator.wfsRatesAt(
                series: grid.series,
                target: target,
                stepMinutes: grid.stepMinutes
            )
        }
    }

    private static func buildOverlays(
        anchor: Date,
        bounds: RadarGeoBounds,
        filePrefix: String,
        ratesForOffset: (Int) -> [[Double]]?
    ) -> [Int: ForecastRasterOverlay] {
        let cacheDir = forecastCacheDirectory()
        var out: [Int: ForecastRasterOverlay] = [:]
        let anchorSec = Int64(anchor.timeIntervalSince1970)

        for offset in StormRadarTimeline.offsetsMinutes where offset > 0 {
            guard let rates = ratesForOffset(offset),
                  PrecipRateRaster.hasSignificantForecastPrecip(rates),
                  let png = PrecipRateRaster.renderForecastGrid(rates) else {
                continue
            }
            let file = cacheDir.appendingPathComponent("\(filePrefix)_\(offset)_\(anchorSec).png")
            do {
                try png.write(to: file, options: .atomic)
                out[offset] = ForecastRasterOverlay(fileURL: file.path, bounds: bounds)
            } catch {
                continue
            }
        }
        return out
    }

    private static func fetchPrecipitationGridWfs(
        lat: Double,
        lon: Double,
        anchor: Date,
        bounds: RadarGeoBounds
    ) async throws -> PrecipGrid {
        let step = (gridHalfSpanDeg * 2) / Double(wfsGridCells - 1)
        let lats = (0 ..< wfsGridCells).map { i in lat - gridHalfSpanDeg + Double(i) * step }
        let lons = (0 ..< wfsGridCells).map { i in lon - gridHalfSpanDeg + Double(i) * step }
        let start =
            utcCalendar.date(byAdding: .minute, value: -StormRadarTimeline.horizonMinutes, to: anchor) ?? anchor
        let end =
            utcCalendar.date(byAdding: .minute, value: StormRadarTimeline.horizonMinutes, to: anchor) ?? anchor

        var series = Array(
            repeating: Array(repeating: [FmiPrecipitationStep](), count: wfsGridCells),
            count: wfsGridCells
        )

        await withTaskGroup(of: (Int, Int, [FmiPrecipitationStep]).self) { group in
            for row in 0 ..< wfsGridCells {
                for col in 0 ..< wfsGridCells {
                    let pointLat = lats[row]
                    let pointLon = lons[col]
                    group.addTask {
                        let steps = await fetchPointSeries(
                            lat: pointLat,
                            lon: pointLon,
                            start: start,
                            end: end
                        )
                        return (row, col, steps)
                    }
                }
            }
            for await result in group {
                series[result.0][result.1] = result.2
            }
        }

        return PrecipGrid(bounds: bounds, series: series, stepMinutes: timestepMinutes)
    }

    private static func fetchPointSeries(
        lat: Double,
        lon: Double,
        start: Date,
        end: Date
    ) async -> [FmiPrecipitationStep] {
        let edited = await fetchMultipointSeries(
            storedQueryId: storedQueryEdited,
            lat: lat,
            lon: lon,
            start: start,
            end: end
        )
        if !edited.isEmpty, edited.contains(where: { $0.amountMm > 0 }) {
            return edited
        }
        return await fetchMultipointSeries(
            storedQueryId: storedQueryMeps,
            lat: lat,
            lon: lon,
            start: start,
            end: end
        )
    }

    private static func fetchMultipointSeries(
        storedQueryId: String,
        lat: Double,
        lon: Double,
        start: Date,
        end: Date
    ) async -> [FmiPrecipitationStep] {
        var components = URLComponents(string: wfsBase)!
        components.queryItems = [
            URLQueryItem(name: "request", value: "getFeature"),
            URLQueryItem(name: "storedquery_id", value: storedQueryId),
            URLQueryItem(name: "latlon", value: "\(roundCoord(lat, decimals: 4)),\(roundCoord(lon, decimals: 4))"),
            URLQueryItem(name: "parameters", value: "PrecipitationAmount"),
            URLQueryItem(name: "timestep", value: String(timestepMinutes)),
            URLQueryItem(name: "starttime", value: FmiInstantFormat.toParam(start)),
            URLQueryItem(name: "endtime", value: FmiInstantFormat.toParam(end)),
        ]
        guard let url = components.url else { return [] }
        do {
            let xml = try await WeatherHTTPClient.fetchText(url: url, accept: "application/xml,*/*")
            return try FmiPrecipitationMultipointParser.parse(xml)
        } catch {
            return []
        }
    }

    private static func harmonieOriginCandidates(for anchor: Date) -> [Date] {
        var candidates: [Date] = []
        let primary = harmonieOriginTime(for: anchor)
        candidates.append(primary)
        for hoursBack in [6, 12, 18] {
            if let earlier = utcCalendar.date(byAdding: .hour, value: -hoursBack, to: primary) {
                candidates.append(earlier)
            }
        }
        var seen = Set<Int64>()
        return candidates.filter { date in
            let key = Int64(date.timeIntervalSince1970)
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private static func harmonieOriginTime(for anchor: Date) -> Date {
        let hour = utcCalendar.component(.hour, from: anchor)
        var runHour = ((hour - 1) / 6) * 6
        var dayAnchor = anchor
        if runHour < 0 {
            runHour = 18
            dayAnchor = utcCalendar.date(byAdding: .day, value: -1, to: anchor) ?? anchor
        }
        var comps = utcCalendar.dateComponents([.year, .month, .day], from: dayAnchor)
        comps.hour = runHour
        comps.minute = 0
        comps.second = 0
        return utcCalendar.date(from: comps) ?? anchor
    }

    private static func boundsCacheKey(_ bounds: RadarGeoBounds) -> String {
        [
            Int(bounds.westLon * 10),
            Int(bounds.southLat * 10),
            Int(bounds.eastLon * 10),
            Int(bounds.northLat * 10),
        ].map(String.init).joined(separator: ",")
    }

    private static func roundCoord(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (value * factor).rounded() / factor
    }

    private static func forecastCacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("storm_fmi_forecast", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
