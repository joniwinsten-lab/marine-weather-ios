import SwiftUI

struct WindDirectionGlyph: View {
    let fromDegrees: Double
    var size: CGFloat = 44

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let inset: CGFloat = size < 28 ? 3 : 6
            let radius = min(canvasSize.width, canvasSize.height) / 2 - inset
            let radians = (fromDegrees - 90) * .pi / 180
            let tip = CGPoint(
                x: center.x + cos(radians) * radius,
                y: center.y + sin(radians) * radius
            )

            let ring = Path(ellipseIn: CGRect(
                x: center.x - radius - 2,
                y: center.y - radius - 2,
                width: (radius + 2) * 2,
                height: (radius + 2) * 2
            ))
            context.fill(ring, with: .color(.accentColor.opacity(0.12)))

            var shaft = Path()
            shaft.move(to: tip)
            shaft.addLine(to: center)
            context.stroke(shaft, with: .color(.accentColor), style: StrokeStyle(lineWidth: size < 28 ? 2 : 4, lineCap: .round))

            let angle = atan2(center.y - tip.y, center.x - tip.x)
            let head = size < 28 ? 7.0 : 11.0
            for delta in [3.0 / 4.0 * .pi, -3.0 / 4.0 * .pi] {
                let wingAngle = angle + delta
                let end = CGPoint(
                    x: center.x + cos(wingAngle) * head * 0.55,
                    y: center.y + sin(wingAngle) * head * 0.55
                )
                var wing = Path()
                wing.move(to: center)
                wing.addLine(to: end)
                context.stroke(wing, with: .color(.accentColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
