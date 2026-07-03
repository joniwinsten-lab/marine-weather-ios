import SwiftUI

/// One wind column (label, speed, gust, direction glyph) for compare and route cards.
struct WindForecastTimeSlot: View {
    let label: String
    let point: UnifiedTimePoint?
    let windUnit: WindUnit
    var dense: Bool = false
    var labelLineLimit: Int = 1

    var body: some View {
        Group {
            if dense {
                denseBody
            } else {
                standardBody
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var standardBody: some View {
        VStack(spacing: 4) {
            slotLabel
            metricsBlock(glyphSize: 36, speedSize: 20, unitSize: 11, gustSize: 11, degreeSize: 11)
            Spacer(minLength: 0)
        }
    }

    private var denseBody: some View {
        GeometryReader { geo in
            let glyphSize = WindSlotLayout.glyphSize(
                columnWidth: geo.size.width,
                columnHeight: geo.size.height
            )
            VStack(spacing: 3) {
                slotLabel
                metricsBlock(
                    glyphSize: glyphSize,
                    speedSize: min(26, glyphSize * 0.62),
                    unitSize: 11,
                    gustSize: 11,
                    degreeSize: 12
                )
                Spacer(minLength: 2)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }

    private var slotLabel: some View {
        Text(label)
            .font(.system(size: dense ? 11 : 12, weight: .semibold))
            .foregroundStyle(.tint)
            .lineLimit(labelLineLimit)
            .minimumScaleFactor(0.65)
    }

    @ViewBuilder
    private func metricsBlock(
        glyphSize: CGFloat,
        speedSize: CGFloat,
        unitSize: CGFloat,
        gustSize: CGFloat,
        degreeSize: CGFloat
    ) -> some View {
        if let point, let speedMs = point.windSpeedMs, let speed = WindFormatting.speed(speedMs, unit: windUnit) {
            Text(speed)
                .font(.system(size: speedSize, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(windUnit.label)
                .font(.system(size: unitSize))
                .foregroundStyle(.secondary)

            if let gustMs = point.windGustMs, let gust = WindFormatting.speed(gustMs, unit: windUnit) {
                Text("Max \(gust)")
                    .font(.system(size: gustSize))
                    .foregroundStyle(.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            if let from = point.windFromDeg {
                WindDirectionGlyph(fromDegrees: from, size: glyphSize)
                Text("\(Int(from.rounded()))°")
                    .font(.system(size: degreeSize, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("—")
                .font(.system(size: dense ? 16 : 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

enum WindSlotLayout {
    /// Scale wind-direction glyph to fill spare vertical space in dense weather cards.
    static func glyphSize(columnWidth: CGFloat, columnHeight: CGFloat) -> CGFloat {
        let byWidth = columnWidth * 0.92
        let byHeight = columnHeight * 0.48
        return min(max(28, min(byWidth, byHeight)), 52)
    }
}
