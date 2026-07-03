import Foundation

/// Fintraffic Digitraffic AIS REST (`/locations` + `/vessels`).
actor DigitrafficAisRepository {
    private let decoder = JSONDecoder()
    private var metadataCache: [Int: AisVesselMetaRecord]?

    /// Full fetch: locations + vessel metadata (slow — use on first load).
    func fetchAllVessels() async throws -> [AisVesselDisplay] {
        let fetchedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        let locations = try await fetchLocations(fetchedAtMs: fetchedAtMs)
        let metadataByMmsi = try await ensureMetadataCacheLocked()
        return locations.map { $0.toDisplay(meta: metadataByMmsi[$0.mmsi]) }
    }

    /// Positions only (~7 MB) — for 60 s polling without re-downloading metadata.
    func fetchLocationUpdates() async throws -> [AisVesselDisplay] {
        let fetchedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        return try await fetchLocations(fetchedAtMs: fetchedAtMs).map { $0.toDisplay(meta: nil) }
    }

    /// Fast viewport-scoped fetch (map pan) — uses Digitraffic radius query, not full `/locations`.
    func fetchVesselsInViewport(_ viewport: MapViewport) async throws -> [AisVesselDisplay] {
        let fetchedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        let metadataByMmsi = try await ensureMetadataCacheLocked()
        let radius = viewport.queryRadiusKm()
        var components = URLComponents(
            url: AppConfig.digitrafficBaseURL.appendingPathComponent("locations"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(viewport.center.latitude)),
            URLQueryItem(name: "longitude", value: String(viewport.center.longitude)),
            URLQueryItem(name: "radius", value: String(radius)),
        ]
        guard let url = components.url else { return [] }
        let data = try await DigitrafficHTTPClient.getData(url: url)
        let collection = try decoder.decode(AisLocationFeatureCollection.self, from: data)
        return collection.features.compactMap { feature in
            guard let record = parseLocationRecord(feature, fetchedAtMs: fetchedAtMs) else { return nil }
            return record.toDisplay(meta: metadataByMmsi[record.mmsi])
        }
    }

    func fetchVesselsForMmsis(_ mmsis: Set<Int>) async throws -> [AisVesselDisplay] {
        guard !mmsis.isEmpty else { return [] }
        let fetchedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        let metadataByMmsi = try await ensureMetadataCacheLocked()
        let byMmsi = Dictionary(
            uniqueKeysWithValues: try await fetchLocations(fetchedAtMs: fetchedAtMs)
                .filter { mmsis.contains($0.mmsi) }
                .map { ($0.mmsi, $0) }
        )
        return mmsis.map { mmsi in
            if let location = byMmsi[mmsi] {
                location.toDisplay(meta: metadataByMmsi[mmsi])
            } else {
                metadataByMmsi[mmsi].toDisplayWithoutLocation(mmsi: mmsi)
            }
        }
    }

    func fetchNearbyBrowseItems(
        latitude: Double,
        longitude: Double,
        radiusKm: Int
    ) async throws -> [AisBrowseItem] {
        let fetchedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        let metadataByMmsi = try await ensureMetadataCacheLocked()
        var components = URLComponents(
            url: AppConfig.digitrafficBaseURL.appendingPathComponent("locations"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radiusKm)),
        ]
        guard let url = components.url else { return [] }
        let data = try await DigitrafficHTTPClient.getData(url: url)
        let collection = try decoder.decode(AisLocationFeatureCollection.self, from: data)
        return collection.features.compactMap { feature in
            parseBrowseFromFeature(
                feature,
                fetchedAtMs: fetchedAtMs,
                metadataByMmsi: metadataByMmsi,
                source: .nearby
            )
        }
    }

    func searchVesselsMetadata(query: String) async throws -> [AisBrowseItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.count >= AisTrackConfig.globalSearchMinChars else { return [] }
        let metadataByMmsi = try await ensureMetadataCacheLocked()
        var hits: [AisBrowseItem] = []
        for (mmsi, meta) in metadataByMmsi {
            let hay = [String(mmsi), meta.name, meta.callSign]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()
            guard hay.contains(q) else { continue }
            hits.append(
                AisBrowseItem(
                    mmsi: mmsi,
                    name: meta.name,
                    callSign: meta.callSign,
                    latitude: nil,
                    longitude: nil,
                    sogKn: nil,
                    lastSeenEpochMs: nil,
                    source: .global
                )
            )
            if hits.count >= AisTrackConfig.globalSearchMax { break }
        }
        return hits.sorted { $0.displayLabel.lowercased() < $1.displayLabel.lowercased() }
    }

    func lookupMetadata(mmsi: Int) async throws -> AisVesselMetaRecord? {
        try await ensureMetadataCacheLocked()[mmsi]
    }

    nonisolated func browseRadiusKm(zoom: Double) -> Int {
        switch zoom {
        case 11...: 8
        case 9..<11: 15
        case 7..<9: 30
        default: 50
        }
    }

    private func ensureMetadataCacheLocked() async throws -> [Int: AisVesselMetaRecord] {
        if let metadataCache { return metadataCache }
        let fetched = try await fetchVesselMetadata()
        metadataCache = fetched
        return fetched
    }

    private func fetchLocations(fetchedAtMs: Int64) async throws -> [AisLocationRecord] {
        let url = AppConfig.digitrafficBaseURL.appendingPathComponent("locations")
        let data = try await DigitrafficHTTPClient.getData(url: url)
        let collection = try decoder.decode(AisLocationFeatureCollection.self, from: data)
        return collection.features.compactMap { parseLocationRecord($0, fetchedAtMs: fetchedAtMs) }
    }

    private func fetchVesselMetadata() async throws -> [Int: AisVesselMetaRecord] {
        let url = AppConfig.digitrafficBaseURL.appendingPathComponent("vessels")
        let data = try await DigitrafficHTTPClient.getData(url: url)
        let records = try decoder.decode([AisVesselMetaRecord].self, from: data)
        return Dictionary(uniqueKeysWithValues: records.map { ($0.mmsi, $0) })
    }

    private func parseLocationRecord(
        _ feature: AisLocationFeature,
        fetchedAtMs: Int64
    ) -> AisLocationRecord? {
        guard feature.geometry.coordinates.count >= 2 else { return nil }
        let lon = feature.geometry.coordinates[0]
        let lat = feature.geometry.coordinates[1]
        guard lat.isFinite, lon.isFinite else { return nil }
        return AisLocationRecord(
            mmsi: feature.mmsi,
            latitude: lat,
            longitude: lon,
            sogKn: feature.properties.sog,
            cogDeg: Self.sanitizeCog(feature.properties.cog),
            headingDeg: Self.sanitizeHeading(feature.properties.heading),
            navStatusCode: feature.properties.navStat,
            lastSeenEpochMs: resolveLastSeenEpochMs(feature.properties, fetchedAtMs: fetchedAtMs)
        )
    }

    private func parseBrowseFromFeature(
        _ feature: AisLocationFeature,
        fetchedAtMs: Int64,
        metadataByMmsi: [Int: AisVesselMetaRecord],
        source: AisBrowseSource
    ) -> AisBrowseItem? {
        guard let record = parseLocationRecord(feature, fetchedAtMs: fetchedAtMs) else { return nil }
        let meta = metadataByMmsi[record.mmsi]
        return AisBrowseItem(
            mmsi: record.mmsi,
            name: meta?.name,
            callSign: meta?.callSign,
            latitude: record.latitude,
            longitude: record.longitude,
            sogKn: record.sogKn,
            lastSeenEpochMs: record.lastSeenEpochMs,
            source: source
        )
    }

    private func resolveLastSeenEpochMs(
        _ properties: AisLocationProperties,
        fetchedAtMs: Int64
    ) -> Int64 {
        AisMqttMessageParser.normalizeEpochMs(properties.timestampExternal)
            ?? AisMqttMessageParser.normalizeEpochMs(properties.timestamp)
            ?? fetchedAtMs
    }

    private static func sanitizeCog(_ cog: Double?) -> Double? {
        guard let cog, cog.isFinite, cog >= 0, cog < 360 else { return nil }
        return cog
    }

    private static func sanitizeHeading(_ heading: Int?) -> Int? {
        guard let heading, (0...359).contains(heading) else { return nil }
        return heading
    }
}

// MARK: - DTOs

private struct AisLocationFeatureCollection: Decodable {
    let features: [AisLocationFeature]
}

private struct AisLocationFeature: Decodable {
    let mmsi: Int
    let geometry: AisPointGeometry
    let properties: AisLocationProperties
}

private struct AisPointGeometry: Decodable {
    let coordinates: [Double]
}

private struct AisLocationProperties: Decodable {
    let sog: Double?
    let cog: Double?
    let heading: Int?
    let navStat: Int?
    let timestampExternal: Int64?
    let timestamp: Int64?
}

private struct AisLocationRecord {
    let mmsi: Int
    let latitude: Double
    let longitude: Double
    let sogKn: Double?
    let cogDeg: Double?
    let headingDeg: Int?
    let navStatusCode: Int?
    let lastSeenEpochMs: Int64
}

struct AisVesselMetaRecord: Decodable, Sendable {
    let mmsi: Int
    let name: String?
    let callSign: String?
    let destination: String?
    let imo: Int?
    let draught: Int?
    let shipType: Int?
    let eta: Int?
}

private extension AisLocationRecord {
    func toDisplay(meta: AisVesselMetaRecord?) -> AisVesselDisplay {
        AisVesselDisplay(
            mmsi: mmsi,
            latitude: latitude,
            longitude: longitude,
            name: meta?.name,
            callSign: meta?.callSign,
            destination: meta?.destination,
            imo: meta?.imo,
            draughtTenthsM: meta?.draught,
            shipTypeCode: meta?.shipType,
            etaRaw: meta?.eta,
            navStatusCode: navStatusCode,
            sogKn: sogKn,
            cogDeg: cogDeg,
            headingDeg: headingDeg,
            lastSeenEpochMs: lastSeenEpochMs
        )
    }
}

private extension AisVesselMetaRecord? {
    func toDisplayWithoutLocation(mmsi: Int) -> AisVesselDisplay {
        AisVesselDisplay(
            mmsi: mmsi,
            latitude: .nan,
            longitude: .nan,
            name: self?.name,
            callSign: self?.callSign,
            destination: self?.destination,
            imo: self?.imo,
            draughtTenthsM: self?.draught,
            shipTypeCode: self?.shipType,
            etaRaw: self?.eta,
            navStatusCode: nil,
            sogKn: nil,
            cogDeg: nil,
            headingDeg: nil,
            lastSeenEpochMs: nil
        )
    }
}
