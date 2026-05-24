import Foundation

enum MarineForecastAlertLevel: Equatable {
    case none
    case notice
    case warning
}

struct MarineCountryText: Identifiable, Equatable {
    var id: String { countryCode }
    let countryCode: String
    let title: String
    let publishedOrValidLabel: String?
    let body: String
    let alertLevel: MarineForecastAlertLevel
    let servicePageURL: URL
}

struct MarineTextOverview: Equatable {
    let lastFetchedUtc: Int64
    let metNorwaySeaLastChange: String?
    let countries: [MarineCountryText]
    let errors: [String]
}

enum MarineServiceUrls {
    static func forCountry(_ countryCode: String) -> URL {
        switch countryCode {
        case "FI":
            URL(string: "https://www.ilmatieteenlaitos.fi/saatiedotus-merenkulkijoille")!
        case "SE":
            URL(string: "https://www.smhi.se/vader/vader-till-havs/sjorapporten")!
        case "NO":
            URL(string: "https://havvarsel.no/")!
        case "EE":
            URL(string: "https://www.ilmateenistus.ee/meri/mereilm/")!
        default:
            URL(string: "https://www.ilmatieteenlaitos.fi/saatiedotus-merenkulkijoille")!
        }
    }
}
