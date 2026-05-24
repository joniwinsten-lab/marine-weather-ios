import Foundation

/// Text marine outlooks for four Baltic countries (Android `MarineTextRepository`).
actor MarineTextRepository {
    private let decoder = JSONDecoder()

    func loadOverview(
        lat: Double,
        lon: Double,
        titlesByCountry: [String: String]
    ) async -> MarineTextOverview {
        var errors: [String] = []
        let t0 = Int64(Date().timeIntervalSince1970 * 1000)

        let seaDoc: MetSeaCollection? = await {
            do {
                let url = URL(string: "https://api.met.no/weatherapi/textforecast/3.0/sea_en.json")!
                let data = try await WeatherHTTPClient.fetchBody(url: url)
                return try decoder.decode(MetSeaCollection.self, from: data)
            } catch {
                errors.append("MET sea_en: \(error.localizedDescription)")
                return nil
            }
        }()

        let smhiSea = await loadSmhiSeaReportOrNull()
        let ee: EeMarine? = await {
            do {
                return try await loadEstoniaMarineEnglish()
            } catch {
                errors.append("EE forecast: \(error.localizedDescription)")
                return nil
            }
        }()

        var countries: [MarineCountryText] = []

        if let seaDoc {
            let features = seaDoc.features.compactMap { $0.toSeaFeature() }
            for code in ["NO", "SE", "FI"] {
                let box = LonLatBox.bbox(for: code)
                let pick = pickFeatureForCountry(features: features, lat: lat, lon: lon, box: box)
                var bodyText = pick?.toBodyText() ?? ""
                var label = bodyText.isEmpty ? nil : metSeaLabel(lastChange: seaDoc.lastChange, pick: pick)

                if bodyText.isEmpty {
                    switch code {
                    case "FI":
                        if let smhi = smhiSeaTextForPoint(report: smhiSea, lat: lat, lon: lon) {
                            bodyText = smhi.body
                            label = smhi.label
                        } else if let fmi = await loadFmiPointSummary(lat: lat, lon: lon) {
                            bodyText = fmi.body
                            label = fmi.label
                        }
                    case "SE":
                        if let smhi = smhiSeaTextForPoint(report: smhiSea, lat: lat, lon: lon) {
                            bodyText = smhi.body
                            label = smhi.label
                        } else if let smhiPt = await loadSmhiPointSummary(lat: lat, lon: lon) {
                            bodyText = smhiPt.body
                            label = smhiPt.label
                        }
                    default:
                        break
                    }
                }

                countries.append(
                    buildCountryCard(
                        code: code,
                        title: titlesByCountry[code] ?? code,
                        rawBody: bodyText,
                        label: label,
                        metProps: pick?.properties
                    )
                )
            }
        } else {
            for code in ["NO", "SE", "FI"] {
                var bodyText = ""
                var label: String?
                switch code {
                case "FI":
                    if let smhi = smhiSeaTextForPoint(report: smhiSea, lat: lat, lon: lon) {
                        bodyText = smhi.body
                        label = smhi.label
                    } else if let fmi = await loadFmiPointSummary(lat: lat, lon: lon) {
                        bodyText = fmi.body
                        label = fmi.label
                    }
                case "SE":
                    if let smhi = smhiSeaTextForPoint(report: smhiSea, lat: lat, lon: lon) {
                        bodyText = smhi.body
                        label = smhi.label
                    } else if let smhiPt = await loadSmhiPointSummary(lat: lat, lon: lon) {
                        bodyText = smhiPt.body
                        label = smhiPt.label
                    }
                default:
                    break
                }
                countries.append(
                    buildCountryCard(
                        code: code,
                        title: titlesByCountry[code] ?? code,
                        rawBody: bodyText,
                        label: label
                    )
                )
            }
        }

        if let ee {
            countries.append(
                buildCountryCard(
                    code: "EE",
                    title: titlesByCountry["EE"] ?? "EE",
                    rawBody: ee.body,
                    label: ee.validLabel
                )
            )
        } else {
            countries.append(
                buildCountryCard(
                    code: "EE",
                    title: titlesByCountry["EE"] ?? "EE",
                    rawBody: "",
                    label: nil
                )
            )
        }

        return MarineTextOverview(
            lastFetchedUtc: t0,
            metNorwaySeaLastChange: seaDoc?.lastChange,
            countries: countries,
            errors: errors
        )
    }

    // MARK: - Private

    private struct TextBlock {
        let body: String
        let label: String?
    }

    private func buildCountryCard(
        code: String,
        title: String,
        rawBody: String,
        label: String?,
        metProps: MetSeaProperties? = nil
    ) -> MarineCountryText {
        MarineCountryText(
            countryCode: code,
            title: title,
            publishedOrValidLabel: label,
            body: finalizeBody(rawBody),
            alertLevel: MarineForecastAlertClassifier.classify(
                rawText: rawBody,
                metWindWarning: metProps?.windWarning,
                metIceWarning: metProps?.iceWarning,
                metPolarlowWarning: metProps?.polarlowWarning
            ),
            servicePageURL: MarineServiceUrls.forCountry(code)
        )
    }

    private func finalizeBody(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return "" }
        if text.hasPrefix("At the map centre:") { return text }
        let summary = MarineTextSummarizer.summarize(text)
        if !summary.isEmpty { return summary }
        if text.count > 280 {
            return String(text.prefix(280)) + "…"
        }
        return text
    }

    private func loadSmhiSeaReportOrNull() async -> SmhiSeaReport? {
        let url = URL(string: "https://data-download.smhi.se/data/meteorology/texts/sea_report_sweden_sv.json")!
        do {
            let data = try await WeatherHTTPClient.fetchBody(url: url)
            return try decoder.decode(SmhiSeaReport.self, from: data)
        } catch {
            return nil
        }
    }

    private func metSeaLabel(lastChange: String?, pick: SeaFeature?) -> String? {
        let parts = [lastChange, pick?.intervalLabel()].compactMap { $0 }
        let joined = parts.joined(separator: " · ")
        return joined.isEmpty ? nil : joined
    }

    private func smhiSeaTextForPoint(report: SmhiSeaReport?, lat: Double, lon: Double) -> TextBlock? {
        guard let report else { return nil }
        guard let districtId = smhiDistrictForPoint(lat: lat, lon: lon) else { return nil }
        let districtName = Self.smhiDistrictNames[districtId] ?? ""
        let text = report.districts
            .first { $0.ids.contains(districtId) }?
            .text
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty { return nil }

        var body = ""
        if let overview = report.overview?.trimmingCharacters(in: .whitespacesAndNewlines), !overview.isEmpty {
            body += overview + "\n\n"
        }
        if !districtName.isEmpty {
            body += districtName + "\n\n"
        }
        body += text

        let labelParts = [
            report.updated.map { "SMHI · \($0)" },
            "Sea report",
        ].compactMap { $0 }
        return TextBlock(body: body.trimmingCharacters(in: .whitespacesAndNewlines), label: labelParts.joined(separator: " · "))
    }

    private func smhiDistrictForPoint(lat: Double, lon: Double) -> Int? {
        let matches = Self.smhiDistrictBoxes.filter { $0.value.contains(lon: lon, lat: lat) }
        if let best = matches.min(by: { $0.value.dist2(lon: lon, lat: lat) < $1.value.dist2(lon: lon, lat: lat) }) {
            return best.key
        }
        return Self.smhiDistrictBoxes.min(by: { $0.value.dist2(lon: lon, lat: lat) < $1.value.dist2(lon: lon, lat: lat) })?.key
    }

    private func loadFmiPointSummary(lat: Double, lon: Double) async -> TextBlock? {
        let latP = roundCoord(lat, decimals: 5)
        let lonP = roundCoord(lon, decimals: 5)
        var components = URLComponents(string: "https://opendata.fmi.fi/wfs")!
        components.queryItems = [
            URLQueryItem(name: "request", value: "getFeature"),
            URLQueryItem(name: "storedquery_id", value: "fmi::forecast::harmonie::surface::point::multipointcoverage"),
            URLQueryItem(name: "latlon", value: "\(latP),\(lonP)"),
            URLQueryItem(name: "parameters", value: "temperature,WindSpeedMS,WindDirection,WindGust"),
        ]
        do {
            let data = try await WeatherHTTPClient.fetchBody(url: components.url!)
            guard let xml = String(data: data, encoding: .utf8) else { return nil }
            let points = try FmiMultipointParser.parse(xml)
            return formatPointSummary(points: points, validLabel: "Ilmatieteen laitos")
        } catch {
            return nil
        }
    }

    private func loadSmhiPointSummary(lat: Double, lon: Double) async -> TextBlock? {
        let lonP = roundCoord(lon, decimals: 3)
        let latP = roundCoord(lat, decimals: 3)
        let url = URL(
            string: "https://opendata-download-metfcst.smhi.se/api/category/snow1g/version/1/geotype/point/lon/\(lonP)/lat/\(latP)/data.json"
        )!
        do {
            let data = try await WeatherHTTPClient.fetchBody(url: url)
            let dto = try decoder.decode(SmhiPointResponse.self, from: data)
            let forecast = SmhiMapper.toUnified(dto, fetchedAtUtc: Int64(Date().timeIntervalSince1970 * 1000))
            let label = dto.referenceTime.map { "SMHI · \($0)" } ?? "SMHI"
            return formatPointSummary(points: forecast.points, validLabel: label)
        } catch {
            return nil
        }
    }

    private func formatPointSummary(points: [UnifiedTimePoint], validLabel: String?) -> TextBlock? {
        guard let now = points.first else { return nil }
        let laterIndex = min(6, points.count - 1)
        let later = points[laterIndex]
        var body = "At the map centre: \(windPhrase(now))."
        if later.instantUtc != now.instantUtc {
            body += " Later: \(windPhrase(later))."
        }
        if let temp = now.airTempC {
            body += " Air about \(Int(temp.rounded())) °C."
        }
        return TextBlock(body: body.trimmingCharacters(in: .whitespacesAndNewlines), label: validLabel)
    }

    private func windPhrase(_ pt: UnifiedTimePoint) -> String {
        guard let spd = pt.windSpeedMs else { return "wind variable" }
        let dir = pt.windFromDeg.map { " from \(WindFormatting.cardinal(fromDegrees: $0))" } ?? ""
        let gust = pt.windGustMs.map { ", gusts to \(formatWind($0))" } ?? ""
        return "\(formatWind(spd))\(dir)\(gust)"
    }

    private func formatWind(_ ms: Double) -> String {
        String(format: "%.1f m/s", (ms * 10).rounded() / 10)
    }

    private func roundCoord(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (value * factor).rounded() / factor
    }

    private struct EeMarine {
        let validLabel: String?
        let body: String
    }

    private func loadEstoniaMarineEnglish() async throws -> EeMarine {
        let url = URL(string: "https://ilmateenistus.ee/ilma_andmed/xml/forecast.php?lang=eng")!
        let xml = try await WeatherHTTPClient.fetchText(url: url, accept: "text/xml;q=0.9, */*;q=0.8")
        let forecastRegex = try NSRegularExpression(pattern: #"<forecast\s+date="([^"]+)">([\s\S]*?)</forecast>"#)
        let ns = xml as NSString
        guard let match = forecastRegex.firstMatch(in: xml, range: NSRange(location: 0, length: ns.length)) else {
            return EeMarine(validLabel: nil, body: "")
        }
        let date = ns.substring(with: match.range(at: 1))
        let inner = ns.substring(with: match.range(at: 2))

        func extractPeriod(_ period: String) -> [String] {
            let periodRegex = try! NSRegularExpression(pattern: "<\(period)>([\\s\\S]*?)</\(period)>")
            let innerNS = inner as NSString
            guard let periodMatch = periodRegex.firstMatch(in: inner, range: NSRange(location: 0, length: innerNS.length)) else {
                return []
            }
            let block = innerNS.substring(with: periodMatch.range(at: 1))
            var out: [String] = []
            let seaRegex = try! NSRegularExpression(pattern: #"<sea>([\s\S]*?)</sea>"#)
            let blockNS = block as NSString
            seaRegex.enumerateMatches(in: block, range: NSRange(location: 0, length: blockNS.length)) { m, _, _ in
                guard let m else { return }
                let t = blockNS.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { out.append("— \(period) —\n\(t)") }
            }
            let peipsiRegex = try! NSRegularExpression(pattern: #"<peipsi>([\s\S]*?)</peipsi>"#)
            peipsiRegex.enumerateMatches(in: block, range: NSRange(location: 0, length: blockNS.length)) { m, _, _ in
                guard let m else { return }
                let t = blockNS.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { out.append("— \(period) — Lake Peipsi\n\(t)") }
            }
            return out
        }

        let chunks = extractPeriod("night") + extractPeriod("day")
        let nightSeaRegex = try! NSRegularExpression(pattern: #"<night>[\s\S]*?<sea>([\s\S]*?)</sea>"#)
        let firstNightSea: String = {
            guard let m = nightSeaRegex.firstMatch(in: inner, range: NSRange(inner.startIndex..., in: inner)) else {
                return ""
            }
            return (inner as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }()
        let validLine = firstNightSea
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("Forecast for Baltic Sea valid") }
        var labelParts = ["Forecast date: \(date)"]
        if let validLine, !validLine.isEmpty { labelParts.append(validLine) }
        return EeMarine(
            validLabel: labelParts.joined(separator: " · "),
            body: chunks.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func pickFeatureForCountry(
        features: [SeaFeature],
        lat: Double,
        lon: Double,
        box: LonLatBox
    ) -> SeaFeature? {
        let inBox = features.filter {
            box.contains(lon: $0.centroidLon, lat: $0.centroidLat) &&
            !$0.properties.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if inBox.isEmpty { return nil }
        let inside = inBox.filter { pointInPolygon(lon: lon, lat: lat, ring: $0.ringLonLat) }
        return inside.min(by: { $0.dist2(lon: lon, lat: lat) < $1.dist2(lon: lon, lat: lat) })
    }

    private func pointInPolygon(lon: Double, lat: Double, ring: [(Double, Double)]) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0 ..< ring.count {
            let xi = ring[i].0
            let yi = ring[i].1
            let xj = ring[j].0
            let yj = ring[j].1
            let denom = yj - yi
            let safeDenom = abs(denom) > 1e-12 ? denom : 1e-12
            let intersect = (yi > lat) != (yj > lat) &&
                lon < (xj - xi) * (lat - yi) / safeDenom + xi
            if intersect { inside.toggle() }
            j = i
        }
        return inside
    }

    private static let smhiDistrictNames: [Int: String] = [
        41: "Gulf of Bothnia (northern)",
        42: "Northern Quark",
        43: "Northern Bothnian Sea",
        44: "Southern Bothnian Sea",
        45: "Åland Sea",
        46: "Archipelago Sea",
        47: "Gulf of Finland",
        48: "Northern Baltic Proper",
        49: "Central Baltic Proper",
        50: "Gulf of Riga",
        51: "South-eastern Baltic",
        52: "Southern Baltic",
        53: "South-western Baltic",
        54: "The Belt",
        55: "The Sound",
        56: "Kattegat",
        57: "Skagerrak",
        58: "Lake Vänern",
        59: "German Bight",
        60: "Fisher",
        61: "South Utsira",
    ]

    private static let smhiDistrictBoxes: [Int: LonLatBox] = [
        41: LonLatBox(lonMin: 15, lonMax: 23, latMin: 63.5, latMax: 66.5),
        42: LonLatBox(lonMin: 19, lonMax: 22.5, latMin: 63, latMax: 66),
        43: LonLatBox(lonMin: 17, lonMax: 21.5, latMin: 62, latMax: 64.5),
        44: LonLatBox(lonMin: 17, lonMax: 21.5, latMin: 60.2, latMax: 63),
        45: LonLatBox(lonMin: 19, lonMax: 21.8, latMin: 59.5, latMax: 61),
        46: LonLatBox(lonMin: 21, lonMax: 23.8, latMin: 59.5, latMax: 61.5),
        47: LonLatBox(lonMin: 22.5, lonMax: 30.5, latMin: 59.3, latMax: 60.8),
        48: LonLatBox(lonMin: 18, lonMax: 26.5, latMin: 57.5, latMax: 59.8),
        49: LonLatBox(lonMin: 14, lonMax: 20.5, latMin: 55.5, latMax: 58.5),
        50: LonLatBox(lonMin: 20, lonMax: 27.5, latMin: 56.5, latMax: 58.5),
        51: LonLatBox(lonMin: 18, lonMax: 24.5, latMin: 54.5, latMax: 57.5),
        52: LonLatBox(lonMin: 14, lonMax: 18.5, latMin: 54, latMax: 56.5),
        53: LonLatBox(lonMin: 10, lonMax: 14.5, latMin: 54.5, latMax: 56.5),
        54: LonLatBox(lonMin: 10, lonMax: 16, latMin: 54, latMax: 56.5),
        55: LonLatBox(lonMin: 12, lonMax: 13.8, latMin: 55.4, latMax: 56.2),
        56: LonLatBox(lonMin: 10, lonMax: 12.8, latMin: 56, latMax: 58.5),
        57: LonLatBox(lonMin: 8.5, lonMax: 11.5, latMin: 57.5, latMax: 59.2),
    ]
}

// MARK: - MET sea JSON

private struct MetSeaCollection: Decodable {
    let lastChange: String?
    let features: [MetSeaFeature]
}

private struct MetSeaFeature: Decodable {
    let geometry: MetPolygon?
    let forecastWhen: MetWhen?
    let properties: MetSeaProperties?

    enum CodingKeys: String, CodingKey {
        case geometry
        case forecastWhen = "when"
        case properties
    }

    func toSeaFeature() -> SeaFeature? {
        guard let coords = geometry?.coordinates?.first, coords.count >= 3 else { return nil }
        let ring = coords.map { ($0[0], $0[1]) }
        var sLon = 0.0
        var sLat = 0.0
        for (lo, la) in ring {
            sLon += lo
            sLat += la
        }
        let n = Double(ring.count)
        guard let props = properties else { return nil }
        return SeaFeature(
            centroidLon: sLon / n,
            centroidLat: sLat / n,
            ringLonLat: ring,
            areaApprox: polygonArea(ring),
            properties: props,
            whenInterval: forecastWhen?.interval
        )
    }
}

private struct MetPolygon: Decodable {
    let coordinates: [[[Double]]]?
}

private struct MetWhen: Decodable {
    let interval: [String]?
}

private struct MetSeaProperties: Decodable {
    let area: String?
    let title: String?
    let text: String
    let windWarning: String?
    let iceWarning: String?
    let polarlowWarning: String?

    enum CodingKeys: String, CodingKey {
        case area, title, text
        case windWarning = "wind_warning"
        case iceWarning = "ice_warning"
        case polarlowWarning = "polarlow_warning"
    }
}

private struct SeaFeature {
    let centroidLon: Double
    let centroidLat: Double
    let ringLonLat: [(Double, Double)]
    let areaApprox: Double
    let properties: MetSeaProperties
    let whenInterval: [String]?

    func intervalLabel() -> String? {
        guard let whenInterval, whenInterval.count >= 2 else { return nil }
        return "\(whenInterval[0]) … \(whenInterval[1])"
    }

    func dist2(lon: Double, lat: Double) -> Double {
        let dLon = lon - centroidLon
        let dLat = lat - centroidLat
        return dLon * dLon + dLat * dLat
    }

    func toBodyText() -> String {
        var lines: [String] = []
        if let area = properties.area { lines.append(area) }
        if let title = properties.title { lines.append(title) }
        lines.append(properties.text.trimmingCharacters(in: .whitespacesAndNewlines))
        if let w = properties.windWarning, !w.isEmpty { lines.append(w.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let i = properties.iceWarning, !i.isEmpty { lines.append(i.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let p = properties.polarlowWarning, !p.isEmpty { lines.append(p.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SmhiSeaReport: Decodable {
    let overview: String?
    let updated: String?
    let districts: [SmhiSeaDistrict]
}

private struct SmhiSeaDistrict: Decodable {
    let ids: [Int]
    let text: String
}

private struct LonLatBox {
    let lonMin: Double
    let lonMax: Double
    let latMin: Double
    let latMax: Double

    func contains(lon: Double, lat: Double) -> Bool {
        lon >= lonMin && lon <= lonMax && lat >= latMin && lat <= latMax
    }

    func dist2(lon: Double, lat: Double) -> Double {
        let cLon = (lonMin + lonMax) / 2
        let cLat = (latMin + latMax) / 2
        let dLon = lon - cLon
        let dLat = lat - cLat
        return dLon * dLon + dLat * dLat
    }

    static func bbox(for code: String) -> LonLatBox {
        switch code {
        case "NO": LonLatBox(lonMin: 3, lonMax: 32, latMin: 57, latMax: 72)
        case "SE": LonLatBox(lonMin: 10, lonMax: 25.5, latMin: 54.5, latMax: 69.5)
        case "FI": LonLatBox(lonMin: 19, lonMax: 32.5, latMin: 59, latMax: 70.5)
        default: LonLatBox(lonMin: -180, lonMax: 180, latMin: -90, latMax: 90)
        }
    }
}

private func polygonArea(_ ring: [(Double, Double)]) -> Double {
    guard ring.count >= 3 else { return 0 }
    var sum = 0.0
    for i in 0 ..< ring.count {
        let p = ring[i]
        let q = ring[(i + 1) % ring.count]
        sum += p.0 * q.1 - q.0 * p.1
    }
    return 0.5 * abs(sum)
}
