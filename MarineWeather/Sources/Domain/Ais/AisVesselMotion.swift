import CoreLocation
import Foundation

/// Stale / dead-reckoning helpers for AIS map display (ported from web track prototype).
enum AisVesselMotion {
    /// No AIS fix for this long → treat as stale (web: 30 min).
    static let staleMs: Int64 = 30 * 60 * 1000

    /// Max dead-reckoned drift without a new fix (web: 2 min).
    static let maxDriftMs: Int64 = 120_000

    static func isActive(
        vessel: AisVesselDisplay,
        nowEpochMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> Bool {
        guard let lastSeen = vessel.lastSeenEpochMs else { return false }
        return nowEpochMs - lastSeen < staleMs
    }

    static func isMoving(vessel: AisVesselDisplay) -> Bool {
        guard let sog = vessel.sogKn else { return false }
        return sog >= AppConfig.aisMinSogForVectorKn
    }

    /// Map position: last AIS fix, optionally dead-reckoned by SOG/COG until `maxDriftMs`.
    static func displayPosition(
        vessel: AisVesselDisplay,
        nowEpochMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> (latitude: Double, longitude: Double)? {
        guard vessel.latitude.isFinite, vessel.longitude.isFinite else { return nil }
        if !isActive(vessel: vessel, nowEpochMs: nowEpochMs)
            || !isMoving(vessel: vessel)
            || vessel.lastSeenEpochMs == nil {
            return (vessel.latitude, vessel.longitude)
        }
        let elapsedMs = min(
            max(nowEpochMs - (vessel.lastSeenEpochMs ?? nowEpochMs), 0),
            maxDriftMs
        )
        if elapsedMs <= 0 { return (vessel.latitude, vessel.longitude) }
        guard let bearing = vessel.courseBearingDeg,
              let sog = vessel.sogKn else {
            return (vessel.latitude, vessel.longitude)
        }
        let distanceNm = sog * (Double(elapsedMs) / 3_600_000.0)
        guard distanceNm > 0.0001 else { return (vessel.latitude, vessel.longitude) }
        let end = GeoMath.destinationPoint(
            lat: vessel.latitude,
            lon: vessel.longitude,
            bearingDeg: bearing,
            distanceNm: distanceNm
        )
        return (end.lat, end.lon)
    }

    static func courseVectorEndAt(
        vessel: AisVesselDisplay,
        nowEpochMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        minutes: Double = AppConfig.aisCourseVectorMinutes
    ) -> (latitude: Double, longitude: Double)? {
        guard let pos = displayPosition(vessel: vessel, nowEpochMs: nowEpochMs),
              let sog = vessel.sogKn,
              sog >= AppConfig.aisMinSogForVectorKn,
              let bearing = vessel.courseBearingDeg else { return nil }
        let distanceNm = sog * minutes / 60.0
        guard distanceNm > 0.0001 else { return nil }
        let end = GeoMath.destinationPoint(
            lat: pos.latitude,
            lon: pos.longitude,
            bearingDeg: bearing,
            distanceNm: distanceNm
        )
        return (end.lat, end.lon)
    }

    static func needsLiveMapTick(
        vessels: [AisVesselDisplay],
        nowEpochMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> Bool {
        vessels.contains { vessel in
            isActive(vessel: vessel, nowEpochMs: nowEpochMs)
                && isMoving(vessel: vessel)
                && vessel.lastSeenEpochMs != nil
        }
    }

    static func needsLiveMapTick(
        _ vessels: [AisVesselDisplay],
        nowEpochMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> Bool {
        needsLiveMapTick(vessels: vessels, nowEpochMs: nowEpochMs)
    }

    static func isActive(
        _ vessel: AisVesselDisplay,
        nowEpochMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> Bool {
        isActive(vessel: vessel, nowEpochMs: nowEpochMs)
    }

    static func isMoving(_ vessel: AisVesselDisplay) -> Bool {
        isMoving(vessel: vessel)
    }

    static func displayCoordinate(
        vessel: AisVesselDisplay,
        nowEpochMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> CLLocationCoordinate2D? {
        guard let pos = displayPosition(vessel: vessel, nowEpochMs: nowEpochMs) else { return nil }
        return CLLocationCoordinate2D(latitude: pos.latitude, longitude: pos.longitude)
    }
}
