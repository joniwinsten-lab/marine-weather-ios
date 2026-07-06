#if DEBUG
/// Launch arguments for App Store screenshot / IAP review automation.
enum ScreenshotLaunch {
    static let iapReview: Bool = CommandLine.arguments.contains("-iapReviewScreenshot")

    static var initialTab: MainTab? {
        guard let tabArg = CommandLine.arguments.first(where: { $0.hasPrefix("-tab=") }) else {
            return nil
        }
        return MainTab(rawValue: String(tabArg.dropFirst(5)))
    }
}
#endif
