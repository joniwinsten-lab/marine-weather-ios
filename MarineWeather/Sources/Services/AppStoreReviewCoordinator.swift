import Foundation
import StoreKit
import UIKit

/// SKStoreReviewController prompt after meaningful engagement (Android `PlayInAppReviewCoordinator`).
@MainActor
enum AppStoreReviewCoordinator {
    private static let promptDelayNs: UInt64 = 3_000_000_000
    private static var promptTask: Task<Void, Never>?

    static func recordAppLaunch() {
        UserPreferences.recordAppLaunch()
    }

    static func onPositiveEngagement() {
        UserPreferences.recordPositiveEngagement()
        schedulePromptIfEligible()
    }

    static func onAppUiReady() {
        schedulePromptIfEligible()
    }

    private static func schedulePromptIfEligible() {
        guard UserPreferences.isEligibleForReviewPrompt else { return }
        promptTask?.cancel()
        promptTask = Task {
            try? await Task.sleep(nanoseconds: promptDelayNs)
            guard !Task.isCancelled, UserPreferences.isEligibleForReviewPrompt else { return }
            UserPreferences.markReviewFlowRequested()
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
}
