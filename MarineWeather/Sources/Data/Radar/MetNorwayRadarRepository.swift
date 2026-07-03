import Foundation

/// MET Norway Radar 2.0 PNG composites (Android `MetNorwayRadarRepository.kt`).
enum MetNorwayRadarRepository {
    static let areaNordic = "nordic"

    static let nordicBounds = RadarGeoBounds(
        northLat: 72.0,
        westLon: 4.0,
        southLat: 54.5,
        eastLon: 35.0
    )

    static func loadLatestOverlay(area: String = areaNordic) async -> ActiveRadarOverlay? {
        let frames = await loadRecentFrames(area: area, frameCount: 1)
        guard let frame = frames.last else { return nil }
        return ActiveRadarOverlay(
            sourceId: .metNordic,
            kind: .geoImage,
            sourceLabel: "MET Norway (\(area))",
            timeLabel: frame.timeLabel,
            wmsTileUrlTemplate: nil,
            geoImageUrl: frame.geoImageUrl,
            geoBounds: frame.geoBounds
        )
    }

    private static func loadRecentFrames(area: String, frameCount: Int) async -> [RadarAnimationFrame] {
        guard let available = await fetchAvailable() else { return [] }
        let images =
            available
            .filter {
                $0.params.area == area &&
                $0.params.content == "image" &&
                $0.params.type == "reflectivity"
            }
            .sorted { $0.params.time < $1.params.time }
        guard !images.isEmpty else { return [] }
        let picked = images.suffix(frameCount)
        return picked.compactMap { entry in
            guard let ms = ISO8601Parser.epochMillis(entry.params.time) else { return nil }
            let instant = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
            return RadarAnimationFrame(
                sourceId: .metNordic,
                kind: .geoImage,
                timeIso: entry.params.time,
                timeLabel: FmiInstantFormat.toDisplayHHmm(instant),
                offsetMinutesFromNow: 0,
                wmsTileUrlTemplate: nil,
                geoImageUrl: entry.uri,
                geoBounds: nordicBounds
            )
        }
    }

    private static func fetchAvailable() async -> [MetRadarEntry]? {
        guard let url = URL(string: "https://api.met.no/weatherapi/radar/2.0/available.json") else {
            return nil
        }
        do {
            let data = try await RadarHTTPClient.getData(url: url)
            return try JSONDecoder().decode([MetRadarEntry].self, from: data)
        } catch {
            return nil
        }
    }
}

private struct MetRadarEntry: Decodable {
    let uri: String
    let params: MetRadarParams
}

private struct MetRadarParams: Decodable {
    let area: String
    let content: String
    let time: String
    let type: String
}
