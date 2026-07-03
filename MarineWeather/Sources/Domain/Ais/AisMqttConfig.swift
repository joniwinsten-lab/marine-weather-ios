import Foundation

/// Digitraffic AIS MQTT over WebSockets (Fintraffic open data).
enum AisMqttConfig {
    static let brokerURL = URL(string: "wss://meri.digitraffic.fi:443/mqtt")!
    static let username = "digitraffic"
    static let password = "digitrafficPassword"

    static let locationTopicSuffix = "location"
    static let metadataTopicSuffix = "metadata"

    static let reconnectPeriodMs: UInt64 = 5_000
    static let connectTimeoutMs: UInt64 = 15_000
    static let mapPublishThrottleMs: UInt64 = 300

    private static let topicMmsiRegex = try! NSRegularExpression(pattern: #"^vessels-v2/(\d+)/"#)

    static func locationTopic(mmsi: Int) -> String { "vessels-v2/\(mmsi)/\(locationTopicSuffix)" }

    static func metadataTopic(mmsi: Int) -> String { "vessels-v2/\(mmsi)/\(metadataTopicSuffix)" }

    static func mmsiFromTopic(_ topic: String) -> Int? {
        let range = NSRange(topic.startIndex..<topic.endIndex, in: topic)
        guard let match = topicMmsiRegex.firstMatch(in: topic, range: range),
              match.numberOfRanges > 1,
              let capture = Range(match.range(at: 1), in: topic) else { return nil }
        return Int(topic[capture])
    }

    static func isLocationTopic(_ topic: String) -> Bool {
        topic.contains("/\(locationTopicSuffix)")
    }

    static func isMetadataTopic(_ topic: String) -> Bool {
        topic.hasSuffix("/\(metadataTopicSuffix)")
    }
}
