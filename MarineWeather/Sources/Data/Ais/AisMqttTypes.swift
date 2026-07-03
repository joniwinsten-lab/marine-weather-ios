import Foundation

enum AisMqttConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case error
}

struct AisMqttInboundMessage: Sendable, Equatable {
    let topic: String
    let payload: Data
}

enum AisMqttUpdate: Sendable {
    case location(AisMqttLocationUpdate)
    case metadata(AisMqttMetadataUpdate)

    var mmsi: Int {
        switch self {
        case .location(let update): update.mmsi
        case .metadata(let update): update.mmsi
        }
    }
}

struct AisMqttLocationUpdate: Sendable, Equatable {
    let mmsi: Int
    let latitude: Double
    let longitude: Double
    let sogKn: Double?
    let cogDeg: Double?
    let headingDeg: Int?
    let navStatusCode: Int?
    let lastSeenEpochMs: Int64
}

struct AisMqttMetadataUpdate: Sendable, Equatable {
    let mmsi: Int
    let name: String?
    let callSign: String?
    let destination: String?
}

extension AisVesselDisplay {
    func applyingMqttUpdate(_ update: AisMqttUpdate) -> AisVesselDisplay {
        switch update {
        case .location(let loc):
            AisVesselDisplay(
                mmsi: mmsi,
                latitude: loc.latitude,
                longitude: loc.longitude,
                name: name,
                callSign: callSign,
                destination: destination,
                imo: imo,
                draughtTenthsM: draughtTenthsM,
                shipTypeCode: shipTypeCode,
                etaRaw: etaRaw,
                navStatusCode: loc.navStatusCode,
                sogKn: loc.sogKn,
                cogDeg: loc.cogDeg,
                headingDeg: loc.headingDeg,
                lastSeenEpochMs: loc.lastSeenEpochMs
            )
        case .metadata(let meta):
            AisVesselDisplay(
                mmsi: mmsi,
                latitude: latitude,
                longitude: longitude,
                name: meta.name ?? name,
                callSign: meta.callSign ?? callSign,
                destination: meta.destination ?? destination,
                imo: imo,
                draughtTenthsM: draughtTenthsM,
                shipTypeCode: shipTypeCode,
                etaRaw: etaRaw,
                navStatusCode: navStatusCode,
                sogKn: sogKn,
                cogDeg: cogDeg,
                headingDeg: headingDeg,
                lastSeenEpochMs: lastSeenEpochMs
            )
        }
    }
}
