import Foundation

struct MetFeature: Decodable {
    let properties: MetProperties
}

struct MetProperties: Decodable {
    let meta: MetMeta?
    let timeseries: [MetTimeseries]
}

struct MetMeta: Decodable {
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
    }
}

struct MetTimeseries: Decodable {
    let time: String
    let data: MetData
}

struct MetData: Decodable {
    let instant: MetInstant?
    let next1Hours: MetNextHours?

    enum CodingKeys: String, CodingKey {
        case instant
        case next1Hours = "next_1_hours"
    }
}

struct MetInstant: Decodable {
    let details: MetInstantDetails?
}

struct MetInstantDetails: Decodable {
    let airTemperature: Double?
    let windSpeed: Double?
    let windFromDirection: Double?
    let windSpeedOfGust: Double?

    enum CodingKeys: String, CodingKey {
        case airTemperature = "air_temperature"
        case windSpeed = "wind_speed"
        case windFromDirection = "wind_from_direction"
        case windSpeedOfGust = "wind_speed_of_gust"
    }
}

struct MetNextHours: Decodable {
    let details: MetNextDetails?
}

struct MetNextDetails: Decodable {
    let precipitationAmount: Double?
    let probabilityOfThunder: Double?

    enum CodingKeys: String, CodingKey {
        case precipitationAmount = "precipitation_amount"
        case probabilityOfThunder = "probability_of_thunder"
    }
}
