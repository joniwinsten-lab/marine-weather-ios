import Foundation

/// Route along Finnish fairways (Väylävirasto navigointilinjat — same network as Traficom planning charts).
/// Port of Android `VaylaFairwayRouter.kt`; returns nil when no fairway path exists.
enum VaylaFairwayRouter {
    private static let startKey = "__START__"
    private static let endKey = "__END__"
    private static let maxPages = 18
    private static let pageLimit = 400
    private static let maxSegments = 12_000
    private static let snapRadiusM = 3500.0
    private static let snapNearest = 14
    private static let endpointBridgeMinM = 1.0
    private static let endpointBridgeMaxM = 150.0

    /// Use `f=json` — `f=application/geo+json` returns HTTP 500 from this OGC endpoint (2026).
    private static let itemsBase =
        "https://avoinapi.vaylapilvi.fi/vaylatiedot/ogc/features/v1/collections/vesivaylatiedot:navigointilinjat_uusi/items"

    static func routeAlongNavLines(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) async -> [RouteCoordinate]? {
        let bbox = paddedBbox(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
        guard let segments = await fetchSegments(bbox: bbox), !segments.isEmpty else { return nil }
        let graph = buildGraph(segments: segments)
        guard !graph.isEmpty else { return nil }
        guard let pathKeys = shortestPathKeys(
            adj: graph,
            startLat: lat1,
            startLon: lon1,
            endLat: lat2,
            endLon: lon2
        ) else { return nil }
        return keysToPolyline(pathKeys: pathKeys, lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
    }

    private static func paddedBbox(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> String {
        let minLat = min(lat1, lat2)
        let maxLat = max(lat1, lat2)
        let minLon = min(lon1, lon2)
        let maxLon = max(lon1, lon2)
        let spanLat = max(abs(maxLat - minLat), 0.02)
        let spanLon = max(abs(maxLon - minLon), 0.03)
        let padLat = min(0.35, max(0.04, spanLat * 0.55))
        let padLon = min(0.55, max(0.06, spanLon * 0.55))
        let bMinLon = min(180, max(-180, minLon - padLon))
        let bMinLat = min(85, max(-85, minLat - padLat))
        let bMaxLon = min(180, max(-180, maxLon + padLon))
        let bMaxLat = min(85, max(-85, maxLat + padLat))
        return "\(bMinLon),\(bMinLat),\(bMaxLon),\(bMaxLat)"
    }

    private static func fetchSegments(bbox: String) async -> [[RouteCoordinate]]? {
        var segments: [[RouteCoordinate]] = []
        segments.reserveCapacity(512)
        var url = URL(string: itemsBase)!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "bbox", value: bbox),
            URLQueryItem(name: "f", value: "json"),
            URLQueryItem(name: "limit", value: String(pageLimit)),
        ]
        url = components.url!
        var pages = 0

        while pages < maxPages, segments.count < maxSegments {
            let body: String
            do {
                body = try await WeatherHTTPClient.fetchText(
                    url: url,
                    accept: "application/json, application/geo+json"
                )
            } catch {
                return nil
            }
            guard let data = body.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            let features = root["features"] as? [[String: Any]] ?? []
            for feature in features {
                guard let geom = feature["geometry"] as? [String: Any],
                      let type = geom["type"] as? String else { continue }
                switch type {
                case "LineString":
                    if let coords = geom["coordinates"], let line = lineStringToLatLon(coords), line.count >= 2 {
                        segments.append(line)
                    }
                case "MultiLineString":
                    guard let parts = geom["coordinates"] as? [Any] else { continue }
                    for part in parts {
                        if let line = lineStringToLatLon(part), line.count >= 2 {
                            segments.append(line)
                        }
                    }
                default:
                    break
                }
            }
            pages += 1
            guard let next = nextPageURL(from: root["links"]) else { break }
            url = next
        }
        return segments
    }

    private static func lineStringToLatLon(_ coordsElement: Any) -> [RouteCoordinate]? {
        guard let arr = coordsElement as? [Any] else { return nil }
        var out: [RouteCoordinate] = []
        out.reserveCapacity(arr.count)
        for ptEl in arr {
            guard let pt = ptEl as? [Any], pt.count >= 2 else { continue }
            let lon = jsonDouble(pt[0])
            let lat = jsonDouble(pt[1])
            guard let lon, let lat else { continue }
            out.append((lat, lon))
        }
        return out.count >= 2 ? out : nil
    }

    private static func jsonDouble(_ value: Any) -> Double? {
        if let n = value as? Double { return n }
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func nextPageURL(from links: Any?) -> URL? {
        guard let links = links as? [[String: Any]] else { return nil }
        for link in links {
            guard (link["rel"] as? String) == "next",
                  let href = link["href"] as? String,
                  let url = URL(string: href) else { continue }
            return url
        }
        return nil
    }

    private static func nodeKey(lat: Double, lon: Double) -> String {
        String(format: "%.5f,%.5f", locale: Locale(identifier: "en_US_POSIX"), lat, lon)
    }

    private static func parseKey(_ key: String) -> RouteCoordinate {
        let idx = key.firstIndex(of: ",")!
        let lat = Double(key[..<idx])!
        let lon = Double(key[key.index(after: idx)...])!
        return (lat, lon)
    }

    private static func buildGraph(
        segments: [[RouteCoordinate]]
    ) -> [String: [(node: String, weight: Double)]] {
        var adj: [String: [(String, Double)]] = [:]
        func addUndirected(_ a: String, _ b: String, _ w: Double) {
            guard a != b, w > 0 else { return }
            adj[a, default: []].append((b, w))
            adj[b, default: []].append((a, w))
        }
        for seg in segments {
            for i in 0..<(seg.count - 1) {
                let aPt = seg[i]
                let bPt = seg[i + 1]
                let a = nodeKey(lat: aPt.lat, lon: aPt.lon)
                let b = nodeKey(lat: bPt.lat, lon: bPt.lon)
                let w = GeoMath.haversineMeters(lat1: aPt.lat, lon1: aPt.lon, lat2: bPt.lat, lon2: bPt.lon)
                addUndirected(a, b, w)
            }
        }
        var endpoints = Set<String>()
        for seg in segments where seg.count >= 2 {
            let first = seg[0]
            let last = seg[seg.count - 1]
            endpoints.insert(nodeKey(lat: first.lat, lon: first.lon))
            endpoints.insert(nodeKey(lat: last.lat, lon: last.lon))
        }
        let epList = Array(endpoints)
        if epList.count <= 2200 {
            for i in 0..<epList.count {
                let ai = epList[i]
                let (la1, lo1) = parseKey(ai)
                for j in (i + 1)..<epList.count {
                    let bj = epList[j]
                    let (la2, lo2) = parseKey(bj)
                    let d = GeoMath.haversineMeters(lat1: la1, lon1: lo1, lat2: la2, lon2: lo2)
                    if d >= endpointBridgeMinM, d <= endpointBridgeMaxM {
                        addUndirected(ai, bj, d)
                    }
                }
            }
        }
        return adj
    }

    private static func shortestPathKeys(
        adj: [String: [(node: String, weight: Double)]],
        startLat: Double,
        startLon: Double,
        endLat: Double,
        endLon: Double
    ) -> [String]? {
        let graphNodes = Array(adj.keys)
        guard !graphNodes.isEmpty else { return nil }
        let snapStart = nearestNodes(lat: startLat, lon: startLon, nodes: graphNodes, k: snapNearest, maxM: snapRadiusM)
        let snapEnd = nearestNodes(lat: endLat, lon: endLon, nodes: graphNodes, k: snapNearest, maxM: snapRadiusM)
        guard !snapStart.isEmpty, !snapEnd.isEmpty else { return nil }

        var work: [String: [(String, Double)]] = [:]
        for (k, v) in adj { work[k] = v }
        func ensureEdge(from: String, to: String, w: Double) {
            work[from, default: []].append((to, w))
        }
        for (n, d) in snapStart {
            ensureEdge(from: startKey, to: n, w: d)
            ensureEdge(from: n, to: startKey, w: d)
        }
        for (n, d) in snapEnd {
            ensureEdge(from: endKey, to: n, w: d)
            ensureEdge(from: n, to: endKey, w: d)
        }

        var dist: [String: Double] = [startKey: 0]
        var prev: [String: String] = [:]
        var pq: [(node: String, cost: Double)] = [(startKey, 0)]
        while !pq.isEmpty {
            pq.sort { $0.cost < $1.cost }
            let (u, du) = pq.removeFirst()
            if du > (dist[u] ?? .infinity) { continue }
            if u == endKey { break }
            for (v, w) in work[u] ?? [] {
                let nd = du + w
                if nd < (dist[v] ?? .infinity) {
                    dist[v] = nd
                    prev[v] = u
                    pq.append((v, nd))
                }
            }
        }
        guard dist[endKey] != nil else { return nil }
        var path: [String] = []
        var cur: String? = endKey
        while let c = cur {
            path.append(c)
            if c == startKey { break }
            cur = prev[c]
        }
        guard path.last == startKey else { return nil }
        return path.reversed()
    }

    private static func nearestNodes(
        lat: Double,
        lon: Double,
        nodes: [String],
        k: Int,
        maxM: Double
    ) -> [(String, Double)] {
        nodes
            .map { key -> (String, Double) in
                let (la, lo) = parseKey(key)
                return (key, GeoMath.haversineMeters(lat1: lat, lon1: lon, lat2: la, lon2: lo))
            }
            .filter { $0.1 <= maxM }
            .sorted { $0.1 < $1.1 }
            .prefix(k)
            .map { $0 }
    }

    private static func keysToPolyline(
        pathKeys: [String],
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> [RouteCoordinate] {
        let inner = pathKeys.dropFirst().dropLast()
        var out: [RouteCoordinate] = [(lat1, lon1)]
        out.reserveCapacity(inner.count + 2)
        for k in inner {
            out.append(parseKey(k))
        }
        out.append((lat2, lon2))
        return out
    }
}
