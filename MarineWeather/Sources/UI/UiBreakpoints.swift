import CoreGraphics

/// Layout thresholds ported from Android `UiBreakpoints.kt` (width in points ≈ dp on iPad).
enum UiBreakpoints {
    static let navigationRailMinWidth: CGFloat = 600
    static let navigationRailWidth: CGFloat = 88
    static let twoPaneMinWidth: CGFloat = 680
    static let weatherPaneDenseMinWidth: CGFloat = 360
    static let routeWeatherScrollMaxHeight: CGFloat = 520
    static let routeForecastCardMinHeight: CGFloat = 128
    static let extendedWindRowHeight: CGFloat = 40
    static let stackedMapHeightFraction: CGFloat = 0.52
    static let stackedPanelHeightFraction: CGFloat = 0.48

    /// Compare tab split (map | weather).
    static let compareMapWidthFraction: CGFloat = 0.65
    static let compareWeatherWidthFraction: CGFloat = 0.35
    static let paywallMaxWidth: CGFloat = 480
    static let extendedWindTableMaxWidth: CGFloat = 520
    static let extendedWindMapWidthFraction: CGFloat = 0.56
    static let extendedWindTableWidthFraction: CGFloat = 0.44

    /// Permanent side rail on iPad; hamburger menu on iPhone.
    static func showsNavigationRail(width: CGFloat) -> Bool {
        width >= navigationRailMinWidth
    }

    /// Side-by-side map + panel (iPad landscape). iPhone uses stacked + scroll even in landscape.
    static func useTwoPaneLayout(width: CGFloat) -> Bool {
        width >= twoPaneMinWidth && showsNavigationRail(width: width)
    }

    static func weatherUsesDenseLayout(width: CGFloat, height: CGFloat) -> Bool {
        useTwoPaneLayout(width: width) && height >= 420
    }

    static func routeWeatherUsesScroll(height: CGFloat) -> Bool {
        height < routeWeatherScrollMaxHeight
    }
}
