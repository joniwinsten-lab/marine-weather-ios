import Foundation

enum LightningSourceId: String, Codable {
    case fmi = "fmi"
    case smhi = "smhi"
}

struct LightningStrike: Equatable, Identifiable {
    var id: String { "\(source.rawValue):\(latitude):\(longitude):\(observedAtEpochMs)" }
    let latitude: Double
    let longitude: Double
    let observedAtEpochMs: Int64
    let source: LightningSourceId
}
