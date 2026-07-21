import Foundation
import UIKit

enum RoutePlanPDFExporter {
    static func writePDF(
        title: String,
        startLine: String,
        endLine: String,
        departureLine: String,
        legLine: String,
        boatSpeedLine: String,
        slotLabels: [String],
        sources: [(name: String, slotLines: [String])],
        disclaimer: String
    ) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("marine_weather_route_\(stamp).pdf")

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            var y: CGFloat = 48
            let margin: CGFloat = 48
            let maxWidth = pageRect.width - margin * 2

            func draw(_ text: String, size: CGFloat, bold: Bool) {
                let font = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let rect = CGRect(x: margin, y: y, width: maxWidth, height: 800)
                let box = (text as NSString).boundingRect(
                    with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attrs,
                    context: nil
                )
                (text as NSString).draw(in: rect, withAttributes: attrs)
                y += box.height + 6
            }

            draw(title, size: 18, bold: true)
            draw("Generated \(Date().formatted(date: .abbreviated, time: .shortened))", size: 10, bold: false)
            y += 4
            draw(startLine, size: 11, bold: false)
            draw(endLine, size: 11, bold: false)
            draw(departureLine, size: 11, bold: false)
            draw(legLine, size: 11, bold: false)
            draw(boatSpeedLine, size: 11, bold: false)
            y += 6
            draw(String(localized: "route_weather_title"), size: 13, bold: true)
            for (name, lines) in sources {
                draw(name, size: 12, bold: true)
                for (i, line) in lines.enumerated() where i < slotLabels.count {
                    draw("\(slotLabels[i]): \(line)", size: 10, bold: false)
                }
            }
            y += 8
            draw(disclaimer, size: 9, bold: false)
        }
        return url
    }
}
