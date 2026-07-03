import Foundation

/// Primes HTTP cache for map style and nearby tiles (Android `MapTileWarmup.kt`).
enum MapTileWarmup {
    static func warm(
        lat: Double,
        lon: Double,
        zoom: Int = Int(AppConfig.defaultCompareZoom.rounded())
    ) async {
        guard lat.isFinite, lon.isFinite else { return }
        await Task.detached(priority: .utility) {
            await fetch(AppConfig.mapStyleURL)
            if let planet = URL(string: "https://tiles.openfreemap.org/planet") {
                await fetch(planet)
            }
            for z in (zoom - 1) ... (zoom + 1) where z >= 0 {
                let (tileX, tileY) = latLonToTileXY(lat: lat, lon: lon, zoom: z)
                for dx in -1 ... 1 {
                    for dy in -1 ... 1 {
                        let x = tileX + dx
                        let y = tileY + dy
                        guard x >= 0, y >= 0 else { continue }
                        let vector = AppConfig.vectorTilesTemplate
                            .replacingOccurrences(of: "{z}", with: String(z))
                            .replacingOccurrences(of: "{x}", with: String(x))
                            .replacingOccurrences(of: "{y}", with: String(y))
                        if let url = URL(string: vector) {
                            await fetch(url)
                        }
                        if z <= 6 {
                            let raster = AppConfig.ne2RasterTemplate
                                .replacingOccurrences(of: "{z}", with: String(z))
                                .replacingOccurrences(of: "{x}", with: String(x))
                                .replacingOccurrences(of: "{y}", with: String(y))
                            if let url = URL(string: raster) {
                                await fetch(url)
                            }
                        }
                    }
                }
            }
        }.value
    }

    /// Prefetch tiles covering a route corridor (HTTP disk cache for MapLibre).
    static func warmRouteCorridor(
        routePoints: [(lat: Double, lon: Double)],
        minZoom: Int = 8,
        maxZoom: Int = 13
    ) async {
        guard routePoints.count >= 2,
              let bounds = GeoMath.boundsAroundPolyline(routePoints, paddingDeg: 0.15) else { return }
        await Task.detached(priority: .utility) {
            await fetch(AppConfig.mapStyleURL)
            let maxTilesPerZoom = 120
            for z in minZoom...maxZoom {
                let (xMin, yMin) = latLonToTileXY(lat: bounds.maxLat, lon: bounds.minLon, zoom: z)
                let (xMax, yMax) = latLonToTileXY(lat: bounds.minLat, lon: bounds.maxLon, zoom: z)
                let xLo = max(0, min(xMin, xMax))
                let xHi = max(xMin, xMax)
                let yLo = max(0, min(yMin, yMax))
                let yHi = max(yMin, yMax)
                var tileBudget = maxTilesPerZoom
                for x in xLo...xHi {
                    if tileBudget <= 0 { break }
                    for y in yLo...yHi {
                        if tileBudget <= 0 { break }
                        tileBudget -= 1
                        let vector = AppConfig.vectorTilesTemplate
                            .replacingOccurrences(of: "{z}", with: String(z))
                            .replacingOccurrences(of: "{x}", with: String(x))
                            .replacingOccurrences(of: "{y}", with: String(y))
                        if let url = URL(string: vector) {
                            await fetch(url)
                        }
                        if z <= 6 {
                            let raster = AppConfig.ne2RasterTemplate
                                .replacingOccurrences(of: "{z}", with: String(z))
                                .replacingOccurrences(of: "{x}", with: String(x))
                                .replacingOccurrences(of: "{y}", with: String(y))
                            if let url = URL(string: raster) {
                                await fetch(url)
                            }
                        }
                    }
                }
            }
        }.value
    }

    private static func fetch(_ url: URL) async {
        var request = URLRequest(url: url)
        request.setValue(AppConfig.weatherUserAgent, forHTTPHeaderField: "User-Agent")
        _ = try? await MapHTTPConfiguration.urlSession.data(for: request)
    }

    /// Web Mercator tile index (Android `latLonToTileXY`).
    static func latLonToTileXY(lat: Double, lon: Double, zoom: Int) -> (x: Int, y: Int) {
        let z = min(max(zoom, 0), 22)
        let n = 1 << z
        let x = Int(floor((lon + 180.0) / 360.0 * Double(n))).clamped(to: 0 ... n - 1)
        let latRad = lat * .pi / 180.0
        let y =
            Int(
                floor(
                    (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * Double(n)
                )
            ).clamped(to: 0 ... n - 1)
        return (x, y)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
