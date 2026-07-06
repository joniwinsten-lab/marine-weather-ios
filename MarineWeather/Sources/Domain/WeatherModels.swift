import Foundation

enum SourceId: String, CaseIterable, Identifiable, Codable {
    case metNorway = "MET_NORWAY"
    case smhi = "SMHI"
    case fmi = "FMI"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .metNorway: "MET Norway"
        case .smhi: "SMHI (Sweden)"
        case .fmi: "FMI (Finland)"
        }
    }

    var shortName: String {
        switch self {
        case .metNorway: "MET"
        case .smhi: "SMHI"
        case .fmi: "FMI"
        }
    }
}

struct WeatherSource: Equatable {
    let id: SourceId
    let attributionURL: URL
    let licenseURL: URL
}

enum WeatherSources {
    static let metNorway = WeatherSource(
        id: .metNorway,
        attributionURL: URL(string: "https://api.met.no/")!,
        licenseURL: URL(string: "https://api.met.no/doc/TermsOfService")!
    )
    static let smhi = WeatherSource(
        id: .smhi,
        attributionURL: URL(string: "https://www.smhi.se/")!,
        licenseURL: URL(string: "https://www.smhi.se/en/legal-information/terms-of-use")!
    )
    static let fmi = WeatherSource(
        id: .fmi,
        attributionURL: URL(string: "https://www.ilmatieteenlaitos.fi/")!,
        licenseURL: URL(string: "https://en.ilmatieteenlaitos.fi/open-data-licence")!
    )

    static func source(for id: SourceId) -> WeatherSource {
        switch id {
        case .metNorway: metNorway
        case .smhi: smhi
        case .fmi: fmi
        }
    }
}

struct UnifiedTimePoint: Equatable {
    let instantUtc: Int64
    let airTempC: Double?
    let windSpeedMs: Double?
    let windFromDeg: Double?
    let windGustMs: Double?
    let precipitationMmPerH: Double?
    let thunderProbPercent: Double?
    /// FMI smart-symbol code (1–99 day, +100 night). See ilmatieteenlaitos.fi/saamerkkien-selitykset.
    let weatherSymbolCode: Int?
}

struct UnifiedForecast: Equatable {
    let source: WeatherSource
    let fetchedAtUtc: Int64
    let modelInfo: String?
    let points: [UnifiedTimePoint]
}

struct SourceForecastState: Equatable {
    var forecast: UnifiedForecast?
    var errorMessage: String?
    var loading: Bool

    static let idle = SourceForecastState(forecast: nil, errorMessage: nil, loading: false)
}

enum WindUnit: String, CaseIterable, Identifiable {
    case metersPerSecond
    case knots

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metersPerSecond: "m/s"
        case .knots: "kn"
        }
    }
}

extension Double {
    var msToKnots: Double { self * 1.943_844 }
}
