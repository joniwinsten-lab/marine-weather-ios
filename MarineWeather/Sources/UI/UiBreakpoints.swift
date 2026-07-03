import CoreGraphics

/// Layout thresholds ported from Android `UiBreakpoints.kt` (width in points ≈ dp on iPad).
enum UiBreakpoints {
    static let navigationRailMinWidth: CGFloat = 600
    static let navigationRailWidth: CGFloat = 88
    static let twoPaneMinWidth: CGFloat = 680
    static let weatherPaneDenseMinWidth: CGFloat = 360

    /// Compare tab split (map | weather).
    static let compareMapWidthFraction: CGFloat = 0.65
    static let compareWeatherWidthFraction: CGFloat = 0.35
    static let paywallMaxWidth: CGFloat = 480
    static let extendedWindTableMaxWidth: CGFloat = 520
    static let extendedWindMapWidthFraction: CGFloat = 0.56
    static let extendedWindTableWidthFraction: CGFloat = 0.44
}
