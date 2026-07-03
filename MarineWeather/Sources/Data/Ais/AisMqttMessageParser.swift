import Foundation

/// Parses Digitraffic MQTT topics and JSON payloads (flat + GeoJSON).
struct AisMqttMessageParser: Sendable {
    private let decoder = JSONDecoder()
    private let clockMs: @Sendable () -> Int64

    init(clockMs: @escaping @Sendable () -> Int64 = {
        Int64(Date().timeIntervalSince1970 * 1000)
    }) {
        self.clockMs = clockMs
    }

    func parseTopicMmsi(_ topic: String) -> Int? {
        AisMqttConfig.mmsiFromTopic(topic)
    }

    func parseMessage(topic: String, payload: Data) -> AisMqttUpdate? {
        guard let mmsi = parseTopicMmsi(topic),
              let root = try? decoder.decode([String: JSONValue].self, from: payload) else {
            return nil
        }

        if AisMqttConfig.isMetadataTopic(topic) {
            return parseMetadata(mmsi: mmsi, root: root).map { .metadata($0) }
        }
        if AisMqttConfig.isLocationTopic(topic) {
            return parseLocation(mmsi: mmsi, root: root).map { .location($0) }
        }
        return nil
    }

    private func parseMetadata(mmsi: Int, root: [String: JSONValue]) -> AisMqttMetadataUpdate? {
        let props = root["properties"]?.objectValue ?? root
        let name = props.stringOrNil("name")
        let callSign = props.stringOrNil("callSign")
        let destination = props.stringOrNil("destination")
        guard name != nil || callSign != nil || destination != nil else { return nil }
        return AisMqttMetadataUpdate(mmsi: mmsi, name: name, callSign: callSign, destination: destination)
    }

    private func parseLocation(mmsi: Int, root: [String: JSONValue]) -> AisMqttLocationUpdate? {
        if let flatLat = root.doubleOrNil("lat"), let flatLon = root.doubleOrNil("lon") {
            return AisMqttLocationUpdate(
                mmsi: mmsi,
                latitude: flatLat,
                longitude: flatLon,
                sogKn: root.doubleOrNil("sog"),
                cogDeg: sanitizeCog(root.doubleOrNil("cog")),
                headingDeg: sanitizeHeading(root.intOrNil("heading")),
                navStatusCode: root.intOrNil("navStat"),
                lastSeenEpochMs: Self.normalizeEpochMs(root.int64OrNil("time")) ?? clockMs()
            )
        }

        guard let geometry = root["geometry"]?.objectValue,
              let coords = geometry["coordinates"]?.arrayValue,
              coords.count >= 2,
              let lon = coords[0].doubleValue,
              let lat = coords[1].doubleValue,
              lat.isFinite, lon.isFinite else { return nil }

        let props = root["properties"]?.objectValue ?? [:]
        let lastSeen =
            Self.normalizeEpochMs(props.int64OrNil("timestampExternal"))
            ?? Self.normalizeEpochMs(props.int64OrNil("timestamp"))
            ?? clockMs()

        return AisMqttLocationUpdate(
            mmsi: mmsi,
            latitude: lat,
            longitude: lon,
            sogKn: props.doubleOrNil("sog"),
            cogDeg: sanitizeCog(props.doubleOrNil("cog")),
            headingDeg: sanitizeHeading(props.intOrNil("heading")),
            navStatusCode: props.intOrNil("navStat"),
            lastSeenEpochMs: lastSeen
        )
    }

    private func sanitizeCog(_ cog: Double?) -> Double? {
        guard let cog, cog.isFinite, cog >= 0, cog < 360 else { return nil }
        return cog
    }

    private func sanitizeHeading(_ heading: Int?) -> Int? {
        guard let heading, (0...359).contains(heading), heading != 511 else { return nil }
        return heading
    }

    static func normalizeEpochMs(_ raw: Int64?) -> Int64? {
        guard let raw else { return nil }
        return raw < 1_000_000_000_000 ? raw * 1000 : raw
    }
}

// MARK: - Loose JSON helpers

private enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case object([String: JSONValue])
    case array([JSONValue])
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): value
        case .string(let value): Double(value)
        default: nil
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func stringOrNil(_ key: String) -> String? {
        guard case .string(let value)? = self[key] else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func doubleOrNil(_ key: String) -> Double? { self[key]?.doubleValue }

    func intOrNil(_ key: String) -> Int? {
        guard let value = self[key]?.doubleValue else { return nil }
        return Int(value)
    }

    func int64OrNil(_ key: String) -> Int64? {
        switch self[key] {
        case .number(let value): Int64(value)
        case .string(let value): Int64(value)
        default: nil
        }
    }
}
