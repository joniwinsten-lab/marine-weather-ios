import Foundation

/// Great-circle and polyline helpers (Android `GeoMath.kt`).
enum GeoMath {
    static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadiusM = 6_371_000.0
        let p1 = lat1 * .pi / 180
        let p2 = lat2 * .pi / 180
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(p1) * cos(p2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusM * c
    }

    static func greatCirclePoints(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double,
        segments: Int = 48
    ) -> [(lat: Double, lon: Double)] {
        if segments < 1 { return [(lat1, lon1), (lat2, lon2)] }
        var results: [(Double, Double)] = []
        results.reserveCapacity(segments + 1)
        let lat1r = lat1 * .pi / 180
        let lon1r = lon1 * .pi / 180
        let lat2r = lat2 * .pi / 180
        let lon2r = lon2 * .pi / 180
        let dLat = lat2r - lat1r
        let dLon = lon2r - lon1r
        let hav = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1r) * cos(lat2r) * sin(dLon / 2) * sin(dLon / 2)
        let d = 2 * atan2(sqrt(min(1, max(0, hav))), sqrt(min(1, max(0, 1 - hav))))
        if d < 1e-6 { return [(lat1, lon1), (lat2, lon2)] }
        let sinD = sin(d)
        for i in 0...segments {
            let f = Double(i) / Double(segments)
            let a = sin((1 - f) * d) / sinD
            let b = sin(f * d) / sinD
            let x = a * cos(lat1r) * cos(lon1r) + b * cos(lat2r) * cos(lon2r)
            let y = a * cos(lat1r) * sin(lon1r) + b * cos(lat2r) * sin(lon2r)
            let z = a * sin(lat1r) + b * sin(lat2r)
            let lat = atan2(z, sqrt(x * x + y * y)) * 180 / .pi
            let lon = atan2(y, x) * 180 / .pi
            results.append((lat, lon))
        }
        return results
    }

    static func metersToNauticalMiles(_ meters: Double) -> Double { meters / 1852.0 }

    /// Great-circle destination from start, bearing (° true), distance (nm).
    static func destinationPoint(
        lat: Double,
        lon: Double,
        bearingDeg: Double,
        distanceNm: Double
    ) -> (lat: Double, lon: Double) {
        guard distanceNm > 0, distanceNm.isFinite, bearingDeg.isFinite else {
            return (lat, lon)
        }
        let earthRadiusM = 6_371_000.0
        let distanceM = distanceNm * 1852.0
        let bearing = bearingDeg * .pi / 180
        let lat1 = lat * .pi / 180
        let lon1 = lon * .pi / 180
        let lat2 = asin(
            sin(lat1) * cos(distanceM / earthRadiusM)
                + cos(lat1) * sin(distanceM / earthRadiusM) * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(distanceM / earthRadiusM) * cos(lat1),
            cos(distanceM / earthRadiusM) - sin(lat1) * sin(lat2)
        )
        return (lat2 * 180 / .pi, lon2 * 180 / .pi)
    }

    static func polylineLengthMeters(_ points: [(lat: Double, lon: Double)]) -> Double {
        guard points.count >= 2 else { return 0 }
        var sum = 0.0
        for i in 0..<(points.count - 1) {
            let a = points[i]
            let b = points[i + 1]
            sum += haversineMeters(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
        }
        return sum
    }

    /// Point along polyline at `fraction` of total path length (0 = start, 1 = end).
    static func pointAlongPolyline(
        _ points: [(lat: Double, lon: Double)],
        fraction: Double
    ) -> (lat: Double, lon: Double) {
        guard !points.isEmpty else { return (0, 0) }
        let f = min(1, max(0, fraction))
        if points.count == 1 { return points[0] }
        if f <= 0 { return points[0] }
        if f >= 1 { return points[points.count - 1] }
        let total = polylineLengthMeters(points)
        if total < 1e-3 { return points[points.count - 1] }
        let target = f * total
        var acc = 0.0
        for i in 0..<(points.count - 1) {
            let a = points[i]
            let b = points[i + 1]
            let seg = haversineMeters(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon)
            if acc + seg >= target {
                let t = seg > 1e-6 ? min(1, max(0, (target - acc) / seg)) : 0
                return (a.lat + t * (b.lat - a.lat), a.lon + t * (b.lon - a.lon))
            }
            acc += seg
        }
        return points[points.count - 1]
    }

    struct LatLonBounds {
        let minLat: Double
        let minLon: Double
        let maxLat: Double
        let maxLon: Double
    }

    static func boundsAroundPolyline(
        _ points: [(lat: Double, lon: Double)],
        paddingDeg: Double = 0.12
    ) -> LatLonBounds? {
        guard let first = points.first else { return nil }
        var minLat = first.lat
        var maxLat = first.lat
        var minLon = first.lon
        var maxLon = first.lon
        for point in points.dropFirst() {
            minLat = min(minLat, point.lat)
            maxLat = max(maxLat, point.lat)
            minLon = min(minLon, point.lon)
            maxLon = max(maxLon, point.lon)
        }
        return LatLonBounds(
            minLat: minLat - paddingDeg,
            minLon: minLon - paddingDeg,
            maxLat: maxLat + paddingDeg,
            maxLon: maxLon + paddingDeg
        )
    }

    /// Sample points along route for offline prefetch — at most `maxPoints`, roughly every `spacingNm`.
    static func samplePointsAlongRoute(
        _ points: [(lat: Double, lon: Double)],
        maxPoints: Int = 24,
        spacingNm: Double = 25.0
    ) -> [(lat: Double, lon: Double)] {
        guard !points.isEmpty else { return [] }
        if points.count == 1 { return points }
        let totalM = polylineLengthMeters(points)
        let totalNm = metersToNauticalMiles(totalM)
        if totalNm < 1e-3 {
            return [points.first!, points.last!]
        }
        let spacingM = spacingNm * 1852.0
        let countBySpacing = max(1, Int(totalM / spacingM)) + 1
        let count = min(maxPoints, countBySpacing)
        let safeCount = max(2, count)
        return (0..<safeCount).map { i in
            let frac = Double(i) / Double(safeCount - 1)
            return pointAlongPolyline(points, fraction: frac)
        }
    }
}
