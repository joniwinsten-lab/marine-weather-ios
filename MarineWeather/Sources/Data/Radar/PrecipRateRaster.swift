import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Precipitation raster (mm/h) for storm forecast overlay (Android `PrecipRateRaster.kt`).
enum PrecipRateRaster {
    static let gridCells = 9
    static let minDisplayMmPerH = 0.45
    static let minFrameMaxMmPerH = 0.65
    static let minWetCellFraction = 0.012

    private static let forecastMinDisplayMmPerH = 0.08
    private static let forecastMinFrameMaxMmPerH = 0.12
    private static let forecastMinWetCellFraction = 0.001

    /// Forecast overlay tuned to resemble smooth radar mosaic (higher res + extra blur).
    static func renderForecastGrid(_ ratesMmPerH: [[Double]]) -> Data? {
        renderGrid(
            ratesMmPerH: ratesMmPerH,
            widthPx: 1024,
            heightPx: 1024,
            gridSmoothPasses: 2,
            outerFadeMarginFraction: 0.05,
            displayFloorMmPerH: forecastMinDisplayMmPerH
        )
    }

    static func renderGrid(
        ratesMmPerH: [[Double]],
        widthPx: Int = 512,
        heightPx: Int = 512,
        gridSmoothPasses: Int = 1,
        outerFadeMarginFraction: Double = 0.12,
        displayFloorMmPerH: Double = minDisplayMmPerH
    ) -> Data? {
        guard !ratesMmPerH.isEmpty, !ratesMmPerH[0].isEmpty else { return nil }
        let grid = prepareForRender(
            ratesMmPerH,
            gridSmoothPasses: gridSmoothPasses,
            displayFloorMmPerH: displayFloorMmPerH
        )
        let rows = grid.count
        let cols = grid[0].count
        let maxRow = max(rows - 1, 0)
        let maxCol = max(cols - 1, 0)

        var pixels = [UInt8](repeating: 0, count: widthPx * heightPx * 4)
        for y in 0 ..< heightPx {
            let gy = heightPx <= 1 ? 0.0 : Double(y) * Double(maxRow) / Double(heightPx - 1)
            let outerY = outerEdgeAlphaFactor(y, size: heightPx, marginFraction: outerFadeMarginFraction)
            for x in 0 ..< widthPx {
                let gx = widthPx <= 1 ? 0.0 : Double(x) * Double(maxCol) / Double(widthPx - 1)
                let outerX = outerEdgeAlphaFactor(x, size: widthPx, marginFraction: outerFadeMarginFraction)
                let rate = bilinearSample(grid, rowF: gy, colF: gx)
                let edge = edgeSoftnessFactor(
                    grid,
                    rowF: gy,
                    colF: gx,
                    centerRate: rate,
                    displayFloor: displayFloorMmPerH
                )
                let color = colorForRate(
                    rate,
                    edgeSoftness: edge,
                    outerFade: min(outerX, outerY),
                    minRate: displayFloorMmPerH
                )
                let idx = (y * widthPx + x) * 4
                pixels[idx] = color.r
                pixels[idx + 1] = color.g
                pixels[idx + 2] = color.b
                pixels[idx + 3] = color.a
            }
        }

        return pngData(pixels: pixels, width: widthPx, height: heightPx)
    }

    static func maxRateMmPerH(_ grid: [[Double]]) -> Double {
        grid.flatMap { $0 }.max() ?? 0
    }

    static func hasSignificantPrecip(_ grid: [[Double]]) -> Bool {
        hasSignificantPrecip(
            grid,
            displayFloor: minDisplayMmPerH,
            frameMax: minFrameMaxMmPerH,
            wetFraction: minWetCellFraction
        )
    }

    static func hasSignificantForecastPrecip(_ grid: [[Double]]) -> Bool {
        hasSignificantPrecip(
            grid,
            displayFloor: forecastMinDisplayMmPerH,
            frameMax: forecastMinFrameMaxMmPerH,
            wetFraction: forecastMinWetCellFraction
        )
    }

    private static func hasSignificantPrecip(
        _ grid: [[Double]],
        displayFloor: Double,
        frameMax: Double,
        wetFraction: Double
    ) -> Bool {
        let prepared = clampNoiseFloor(grid, floorMmPerH: displayFloor)
        if maxRateMmPerH(prepared) < frameMax { return false }
        let flat = prepared.flatMap { $0 }
        guard !flat.isEmpty else { return false }
        let wet = flat.filter { $0 >= displayFloor }.count
        return Double(wet) / Double(flat.count) >= wetFraction
    }

    static func prepareForRender(
        _ grid: [[Double]],
        gridSmoothPasses: Int,
        displayFloorMmPerH: Double = minDisplayMmPerH
    ) -> [[Double]] {
        let clamped = clampNoiseFloor(grid, floorMmPerH: displayFloorMmPerH)
        if gridSmoothPasses <= 0 || maxRateMmPerH(clamped) < displayFloorMmPerH {
            return clamped
        }
        return smoothGrid(clamped, passes: gridSmoothPasses)
    }

    private static func clampNoiseFloor(_ grid: [[Double]], floorMmPerH: Double) -> [[Double]] {
        grid.map { row in row.map { $0 < floorMmPerH ? 0 : $0 } }
    }

    private static func smoothGrid(_ grid: [[Double]], passes: Int) -> [[Double]] {
        var current = grid
        for _ in 0 ..< passes {
            current = boxBlur3x3(current)
        }
        return current
    }

    private static func boxBlur3x3(_ grid: [[Double]]) -> [[Double]] {
        let rows = grid.count
        let cols = grid[0].count
        return (0 ..< rows).map { r in
            (0 ..< cols).map { c in
                var sum = 0.0
                var count = 0
                for dr in -1 ... 1 {
                    for dc in -1 ... 1 {
                        let rr = min(max(r + dr, 0), rows - 1)
                        let cc = min(max(c + dc, 0), cols - 1)
                        sum += grid[rr][cc]
                        count += 1
                    }
                }
                return sum / Double(count)
            }
        }
    }

    private static func bilinearSample(_ grid: [[Double]], rowF: Double, colF: Double) -> Double {
        let rows = grid.count
        let cols = grid[0].count
        guard rows > 0, cols > 0 else { return 0 }
        let r = min(max(rowF, 0), Double(rows - 1))
        let c = min(max(colF, 0), Double(cols - 1))
        let r0 = Int(floor(r))
        let c0 = Int(floor(c))
        let r1 = min(r0 + 1, rows - 1)
        let c1 = min(c0 + 1, cols - 1)
        let dr = r - Double(r0)
        let dc = c - Double(c0)
        let v00 = grid[r0][c0]
        let v01 = grid[r0][c1]
        let v10 = grid[r1][c0]
        let v11 = grid[r1][c1]
        let top = v00 * (1 - dc) + v01 * dc
        let bottom = v10 * (1 - dc) + v11 * dc
        return top * (1 - dr) + bottom * dr
    }

    private static func edgeSoftnessFactor(
        _ grid: [[Double]],
        rowF: Double,
        colF: Double,
        centerRate: Double,
        displayFloor: Double = minDisplayMmPerH
    ) -> Double {
        if centerRate < displayFloor { return 1 }
        let rows = grid.count
        let cols = grid[0].count
        guard rows >= 2, cols >= 2 else { return 1 }
        let r = min(max(rowF, 0), Double(rows - 1))
        let c = min(max(colF, 0), Double(cols - 1))
        let r0 = Int(floor(r))
        let c0 = Int(floor(c))
        let r1 = min(r0 + 1, rows - 1)
        let c1 = min(c0 + 1, cols - 1)
        let samples = [grid[r0][c0], grid[r0][c1], grid[r1][c0], grid[r1][c1]]
        let wet = samples.filter { $0 >= displayFloor }.count
        switch wet {
        case 4: return 1.0
        case 3: return 0.9
        case 2: return 0.7
        case 1: return 0.45
        default: return 0.2
        }
    }

    private static func outerEdgeAlphaFactor(_ coord: Int, size: Int, marginFraction: Double) -> Double {
        guard size > 1, marginFraction > 0 else { return 1 }
        let margin = max(Double(size) * marginFraction, 1)
        let dist = min(Double(coord), Double(size - 1 - coord))
        return smoothstep(dist / margin)
    }

    private static func smoothstep(_ t: Double) -> Double {
        let x = min(max(t, 0), 1)
        return x * x * (3 - 2 * x)
    }

    private static func colorForRate(
        _ mmPerH: Double,
        edgeSoftness: Double,
        outerFade: Double,
        minRate: Double = minDisplayMmPerH
    ) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        if mmPerH < minRate { return (0, 0, 0, 0) }
        let t = min(1.0, mmPerH / 8.0)
        let (r, g, b) = paletteRgb(t)
        let alpha = Int((100 + t * 140) * min(max(edgeSoftness, 0.15), 1) * min(max(outerFade, 0), 1))
        return (r, g, b, UInt8(min(max(alpha, 0), 255)))
    }

    private static func paletteRgb(_ t: Double) -> (UInt8, UInt8, UInt8) {
        let stops: [(Double, (Int, Int, Int))] = [
            (0.00, (80, 200, 120)),
            (0.25, (120, 210, 90)),
            (0.50, (240, 220, 60)),
            (0.75, (255, 140, 40)),
            (1.00, (220, 50, 50)),
        ]
        if t <= stops[0].0 { return byteTriple(stops[0].1) }
        for i in 0 ..< stops.count - 1 {
            let (t0, c0) = stops[i]
            let (t1, c1) = stops[i + 1]
            if t <= t1 {
                let w = t1 <= t0 ? 1.0 : (t - t0) / (t1 - t0)
                return (
                    lerp(c0.0, c1.0, w),
                    lerp(c0.1, c1.1, w),
                    lerp(c0.2, c1.2, w)
                )
            }
        }
        return byteTriple(stops.last!.1)
    }

    private static func byteTriple(_ rgb: (Int, Int, Int)) -> (UInt8, UInt8, UInt8) {
        (UInt8(rgb.0), UInt8(rgb.1), UInt8(rgb.2))
    }

    private static func lerp(_ a: Int, _ b: Int, _ t: Double) -> UInt8 {
        UInt8(min(max(Int(Double(a) + Double(b - a) * t), 0), 255))
    }

    private static func pngData(pixels: [UInt8], width: Int, height: Int) -> Data? {
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }
        return UIImage(cgImage: cgImage).pngData()
    }
}
