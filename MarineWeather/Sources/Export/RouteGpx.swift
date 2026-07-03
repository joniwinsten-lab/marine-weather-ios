import Foundation

enum RouteGpx {
    static func build(routeName: String, points: [RouteCoordinate]) -> String {
        precondition(points.count >= 2, "GPX route needs at least two points")
        let timeStr = ISO8601DateFormatter().string(from: Date())
        let safeName = xmlEscape(routeName.isEmpty ? "Route" : routeName)
        var lines: [String] = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<gpx version="1.1" creator="Marine Weather" xmlns="http://www.topografix.com/GPX/1/1">"#,
            "  <metadata>",
            "    <name>\(safeName)</name>",
            "    <time>\(timeStr)</time>",
            "  </metadata>",
            "  <rte>",
            "    <name>\(safeName)</name>",
            "    <type>Route planning (not for primary navigation)</type>",
        ]
        for pt in points {
            lines.append("    <rtept lat=\"\(pt.lat)\" lon=\"\(pt.lon)\">")
            lines.append("      <time>\(timeStr)</time>")
            lines.append("    </rtept>")
        }
        lines.append("  </rte>")
        lines.append("</gpx>")
        return lines.joined(separator: "\n")
    }

    private static func xmlEscape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count + 8)
        for c in s {
            switch c {
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "&": out += "&amp;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default: out.append(c)
            }
        }
        return out
    }
}
