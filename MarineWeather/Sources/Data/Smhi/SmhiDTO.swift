import Foundation

struct SmhiPointResponse: Decodable {
    let referenceTime: String?
    let timeSeries: [SmhiTimeSeriesEntry]

    enum CodingKeys: String, CodingKey {
        case referenceTime
        case timeSeries
    }
}

struct SmhiTimeSeriesEntry: Decodable {
    let time: String
    let data: SmhiData
}

struct SmhiData: Decodable {
    let airTemperature: Double?
    let windFromDirection: Double?
    let windSpeed: Double?
    let windSpeedOfGust: Double?
    let thunderstormProbability: Double?
    let precipitationAmountMeanDeterministic: Double?
    let precipitationAmountMean: Double?

    enum CodingKeys: String, CodingKey {
        case airTemperature = "air_temperature"
        case windFromDirection = "wind_from_direction"
        case windSpeed = "wind_speed"
        case windSpeedOfGust = "wind_speed_of_gust"
        case thunderstormProbability = "thunderstorm_probability"
        case precipitationAmountMeanDeterministic = "precipitation_amount_mean_deterministic"
        case precipitationAmountMean = "precipitation_amount_mean"
    }
}
