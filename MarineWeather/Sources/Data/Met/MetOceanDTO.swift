import Foundation

/// MET Oceanforecast GeoJSON (same envelope as locationforecast; different instant details).
struct MetOceanFeature: Decodable {
    let properties: MetOceanProperties
}

struct MetOceanProperties: Decodable {
    let timeseries: [MetOceanTimeseries]
}

struct MetOceanTimeseries: Decodable {
    let time: String
    let data: MetOceanData
}

struct MetOceanData: Decodable {
    let instant: MetOceanInstant?
}

struct MetOceanInstant: Decodable {
    let details: MetOceanDetails?
}

struct MetOceanDetails: Decodable {
    let seaSurfaceWaveHeight: Double?

    enum CodingKeys: String, CodingKey {
        case seaSurfaceWaveHeight = "sea_surface_wave_height"
    }
}
