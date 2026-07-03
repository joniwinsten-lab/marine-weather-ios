import SwiftUI

struct WindDirectionGlyph: View {
    let fromDegrees: Double
    var size: CGFloat = 44

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let inset = max(3, size * 0.12)
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

            let shaftWidth = max(2.5, size * 0.09)
            var shaft = Path()
            shaft.move(to: tip)
            shaft.addLine(to: center)
            context.stroke(shaft, with: .color(.accentColor), style: StrokeStyle(lineWidth: shaftWidth, lineCap: .round))

            let angle = atan2(center.y - tip.y, center.x - tip.x)
            let head = max(7, size * 0.24)
            let wingWidth = max(2.5, size * 0.07)
            for delta in [3.0 / 4.0 * .pi, -3.0 / 4.0 * .pi] {
                let wingAngle = angle + delta
                let end = CGPoint(
                    x: center.x + cos(wingAngle) * head * 0.55,
                    y: center.y + sin(wingAngle) * head * 0.55
                )
                var wing = Path()
                wing.move(to: center)
                wing.addLine(to: end)
                context.stroke(wing, with: .color(.accentColor), style: StrokeStyle(lineWidth: wingWidth, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
