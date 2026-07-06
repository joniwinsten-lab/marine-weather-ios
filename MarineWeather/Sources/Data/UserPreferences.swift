import Foundation

enum UserPreferences {
    private static let windUnitKey = "windUnit"
    private static let weatherSourceKey = "weatherSource"
    private static let reviewLaunchCountKey = "in_app_review_launch_count"
    private static let reviewEngagementCountKey = "in_app_review_positive_engagement"
    private static let reviewFlowRequestedKey = "in_app_review_flow_requested"

    static let minLaunchCountForReview = 3
    static let minPositiveEngagementsForReview = 2

    static var windUnit: WindUnit {
        get {
            guard let raw = UserDefaults.standard.string(forKey: windUnitKey),
                  let unit = WindUnit(rawValue: raw) else {
                return .metersPerSecond
            }
            return unit
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: windUnitKey)
        }
    }

    static var weatherSource: SourceId {
        get {
            guard let raw = UserDefaults.standard.string(forKey: weatherSourceKey),
                  let source = SourceId(rawValue: raw) else {
                return .fmi
            }
            return source
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: weatherSourceKey)
        }
    }

    static var launchCount: Int {
        UserDefaults.standard.integer(forKey: reviewLaunchCountKey)
    }

    static var positiveEngagementCount: Int {
        UserDefaults.standard.integer(forKey: reviewEngagementCountKey)
    }

    static var reviewFlowRequested: Bool {
        UserDefaults.standard.bool(forKey: reviewFlowRequestedKey)
    }

    static var isEligibleForReviewPrompt: Bool {
        !reviewFlowRequested
            && launchCount >= minLaunchCountForReview
            && positiveEngagementCount >= minPositiveEngagementsForReview
    }

    static func recordAppLaunch() {
        let next = launchCount + 1
        UserDefaults.standard.set(next, forKey: reviewLaunchCountKey)
    }

    static func recordPositiveEngagement() {
        let next = positiveEngagementCount + 1
        UserDefaults.standard.set(next, forKey: reviewEngagementCountKey)
    }

    static func markReviewFlowRequested() {
        UserDefaults.standard.set(true, forKey: reviewFlowRequestedKey)
    }
}
