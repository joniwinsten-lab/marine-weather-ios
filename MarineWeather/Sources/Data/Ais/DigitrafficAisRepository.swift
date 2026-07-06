import Foundation

/// Fintraffic Digitraffic AIS REST (`/locations` + `/vessels`).
actor DigitrafficAisRepository {
    private let decoder = JSONDecoder()
    private var metadataByMmsi: [Int: AisVesselMetaRecord] = [:]

    /// Fast viewport-scoped fetch — positions only (no full metadata download).
    func fetchVesselsInViewport(_ viewport: MapViewport) async throws -> [AisVesselDisplay] {
        let fetchedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
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
        return try await withThrowingTaskGroup(of: AisVesselDisplay.self) { group in
            for mmsi in mmsis {
                group.addTask {
                    try await self.vesselForMmsi(mmsi, fetchedAtMs: fetchedAtMs)
                }
            }
            var results: [AisVesselDisplay] = []
            results.reserveCapacity(mmsis.count)
            for try await vessel in group {
                results.append(vessel)
            }
            return results
        }
    }

    func fetchNearbyBrowseItems(
        latitude: Double,
        longitude: Double,
        radiusKm: Int
    ) async throws -> [AisBrowseItem] {
        let fetchedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
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
            parseBrowseFromFeature(feature, fetchedAtMs: fetchedAtMs, source: .nearby)
        }
    }

    func searchVesselsMetadata(query: String) async throws -> [AisBrowseItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= AisTrackConfig.globalSearchMinChars else { return [] }
        var components = URLComponents(
            url: AppConfig.digitrafficBaseURL.appendingPathComponent("vessels"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "name", value: q)]
        guard let url = components.url else { return [] }
        let data = try await DigitrafficHTTPClient.getData(url: url)
        let records = try decoder.decode([AisVesselMetaRecord].self, from: data)
        return records.prefix(AisTrackConfig.globalSearchMax).map { meta in
            metadataByMmsi[meta.mmsi] = meta
            return AisBrowseItem(
                mmsi: meta.mmsi,
                name: meta.name,
                callSign: meta.callSign,
                latitude: nil,
                longitude: nil,
                sogKn: nil,
                lastSeenEpochMs: nil,
                source: .global
            )
        }
        .sorted { $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel) == .orderedAscending }
    }

    func lookupMetadata(mmsi: Int) async throws -> AisVesselMetaRecord? {
        try await cachedMetadata(mmsi: mmsi)
    }

    nonisolated func browseRadiusKm(zoom: Double) -> Int {
        switch zoom {
        case 11...: 8
        case 9..<11: 15
        case 7..<9: 30
        default: 50
        }
    }

    // MARK: - Private

    private func vesselForMmsi(_ mmsi: Int, fetchedAtMs: Int64) async throws -> AisVesselDisplay {
        let meta = try await cachedMetadata(mmsi: mmsi)
        if let location = try await fetchLocationRecord(mmsi: mmsi, fetchedAtMs: fetchedAtMs) {
            return location.toDisplay(meta: meta)
        }
        return meta.toDisplayWithoutLocation(mmsi: mmsi)
    }

    private func cachedMetadata(mmsi: Int) async throws -> AisVesselMetaRecord? {
        if let hit = metadataByMmsi[mmsi] { return hit }
        guard let fetched = try await fetchVesselMetadataRecord(mmsi: mmsi) else { return nil }
        metadataByMmsi[mmsi] = fetched
        return fetched
    }

    private func fetchLocationRecord(mmsi: Int, fetchedAtMs: Int64) async throws -> AisLocationRecord? {
        var components = URLComponents(
            url: AppConfig.digitrafficBaseURL.appendingPathComponent("locations"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "mmsi", value: String(mmsi))]
        guard let url = components.url else { return nil }
        let data = try await DigitrafficHTTPClient.getData(url: url)
        let collection = try decoder.decode(AisLocationFeatureCollection.self, from: data)
        guard let feature = collection.features.first else { return nil }
        return parseLocationRecord(feature, fetchedAtMs: fetchedAtMs)
    }

    private func fetchVesselMetadataRecord(mmsi: Int) async throws -> AisVesselMetaRecord? {
        let url = AppConfig.digitrafficBaseURL.appendingPathComponent("vessels/\(mmsi)")
        do {
            let data = try await DigitrafficHTTPClient.getData(url: url)
            return try decoder.decode(AisVesselMetaRecord.self, from: data)
        } catch {
            return nil
        }
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
