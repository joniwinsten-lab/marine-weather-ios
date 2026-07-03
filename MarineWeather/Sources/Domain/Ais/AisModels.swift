import CoreLocation
import Foundation

/// Visible map bounds for AIS filtering and refresh.
struct MapViewport: Sendable {
    let southWest: CLLocationCoordinate2D
    let northEast: CLLocationCoordinate2D
    let zoom: Double
    let centerLatitude: Double

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (southWest.latitude + northEast.latitude) / 2,
            longitude: (southWest.longitude + northEast.longitude) / 2
        )
    }

    var centerLongitude: Double {
        (southWest.longitude + northEast.longitude) / 2
    }

    static func aroundCenter(
        latitude: Double,
        longitude: Double,
        zoom: Double,
        paddingDegrees: Double = 0.22
    ) -> MapViewport {
        MapViewport(
            southWest: CLLocationCoordinate2D(
                latitude: latitude - paddingDegrees,
                longitude: longitude - paddingDegrees
            ),
            northEast: CLLocationCoordinate2D(
                latitude: latitude + paddingDegrees,
                longitude: longitude + paddingDegrees
            ),
            zoom: zoom,
            centerLatitude: latitude
        )
    }

    func spanMetersNorthSouth() -> Double {
        let minLat = min(southWest.latitude, northEast.latitude)
        let maxLat = max(southWest.latitude, northEast.latitude)
        return GeoMath.haversineMeters(
            lat1: minLat, lon1: centerLongitude,
            lat2: maxLat, lon2: centerLongitude
        )
    }

    func spanMetersEastWest() -> Double {
        let minLon = min(southWest.longitude, northEast.longitude)
        let maxLon = max(southWest.longitude, northEast.longitude)
        return GeoMath.haversineMeters(
            lat1: centerLatitude, lon1: minLon,
            lat2: centerLatitude, lon2: maxLon
        )
    }

    func centerMovedMeters(_ other: MapViewport) -> Double {
        GeoMath.haversineMeters(
            lat1: centerLatitude, lon1: centerLongitude,
            lat2: other.centerLatitude, lon2: other.centerLongitude
        )
    }

    /// Radius for Digitraffic `locations?latitude=&longitude=&radius=` covering visible bounds.
    func queryRadiusKm() -> Int {
        let radiusM = max(spanMetersNorthSouth(), spanMetersEastWest()) / 2.0 * 1.15
        return Int(radiusM / 1000.0).clamped(to: 8...80)
    }

    /// True when the map moved enough to warrant a new AIS fetch (zoom-aware, not fixed degrees).
    func regionChangedSignificantly(_ previous: MapViewport) -> Bool {
        if abs(zoom - previous.zoom) > 0.25 { return true }
        let spanM = max(spanMetersNorthSouth(), 500)
        return centerMovedMeters(previous) > spanM * 0.08
    }
}

/// Merged AIS position + vessel metadata for map display and detail sheet.
struct AisVesselDisplay: Equatable, Sendable, Identifiable {
    var id: Int { mmsi }
    let mmsi: Int
    let latitude: Double
    let longitude: Double
    let name: String?
    let callSign: String?
    let destination: String?
    let imo: Int?
    let draughtTenthsM: Int?
    let shipTypeCode: Int?
    let etaRaw: Int?
    let navStatusCode: Int?
    let sogKn: Double?
    let cogDeg: Double?
    let headingDeg: Int?
    /// Last AIS fix time (epoch ms). Used for stale detection and dead reckoning.
    let lastSeenEpochMs: Int64?

    var displayLabel: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return "MMSI \(mmsi)"
    }

    /// Bearing for course vector: COG when moving, else bow heading.
    var courseBearingDeg: Double? {
        if let sog = sogKn, sog >= AppConfig.aisMinSogForVectorKn,
           let cog = cogDeg, cog.isFinite, cog >= 0, cog < 360 {
            return cog
        }
        if let heading = headingDeg, (0...359).contains(heading) {
            return Double(heading)
        }
        return nil
    }

    var showsCourseVector: Bool {
        guard let sog = sogKn, sog >= AppConfig.aisMinSogForVectorKn else { return false }
        return courseBearingDeg != nil
    }

    func courseVectorEnd(
        minutes: Double = AppConfig.aisCourseVectorMinutes
    ) -> CLLocationCoordinate2D? {
        guard let end = AisVesselMotion.courseVectorEndAt(vessel: self, minutes: minutes) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: end.latitude, longitude: end.longitude)
    }
}

enum AisViewportFilter {
    /// Whether a coordinate lies inside [viewport] with optional padding (degrees).
    static func contains(
        latitude: Double,
        longitude: Double,
        viewport: MapViewport,
        paddingDegrees: Double = 0.08
    ) -> Bool {
        let minLat = min(viewport.southWest.latitude, viewport.northEast.latitude) - paddingDegrees
        let maxLat = max(viewport.southWest.latitude, viewport.northEast.latitude) + paddingDegrees
        let minLon = min(viewport.southWest.longitude, viewport.northEast.longitude) - paddingDegrees
        let maxLon = max(viewport.southWest.longitude, viewport.northEast.longitude) + paddingDegrees
        return latitude >= minLat && latitude <= maxLat
            && longitude >= minLon && longitude <= maxLon
    }

    /// Keep vessels inside visible bounds (with padding) up to `maxCount`, nearest to centre first.
    static func filter(
        _ vessels: [AisVesselDisplay],
        viewport: MapViewport,
        maxCount: Int = AppConfig.aisMaxVesselsOnMap,
        paddingDegrees: Double = 0.08
    ) -> [AisVesselDisplay] {
        let minLat = min(viewport.southWest.latitude, viewport.northEast.latitude) - paddingDegrees
        let maxLat = max(viewport.southWest.latitude, viewport.northEast.latitude) + paddingDegrees
        let minLon = min(viewport.southWest.longitude, viewport.northEast.longitude) - paddingDegrees
        let maxLon = max(viewport.southWest.longitude, viewport.northEast.longitude) + paddingDegrees

        let center = viewport.center
        var inBounds: [AisVesselDisplay] = []
        inBounds.reserveCapacity(min(vessels.count, maxCount + 64))

        for vessel in vessels {
            guard vessel.latitude >= minLat, vessel.latitude <= maxLat,
                  vessel.longitude >= minLon, vessel.longitude <= maxLon else { continue }
            inBounds.append(vessel)
        }

        guard inBounds.count > maxCount else { return inBounds }

        inBounds.sort { lhs, rhs in
            let d0 = GeoMath.haversineMeters(
                lat1: center.latitude, lon1: center.longitude,
                lat2: lhs.latitude, lon2: lhs.longitude
            )
            let d1 = GeoMath.haversineMeters(
                lat1: center.latitude, lon1: center.longitude,
                lat2: rhs.latitude, lon2: rhs.longitude
            )
            return d0 < d1
        }
        return Array(inBounds.prefix(maxCount))
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
