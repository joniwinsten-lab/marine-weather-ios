import Foundation

/// Local 3-day route premium trial (Android `UserPreferencesRepository.routeTrial*`).
enum RouteTrialPreferences {
    private static let startKey = "route_trial_start_epoch_ms"
    private static let trialDurationMs: Int64 = 3 * 24 * 3_600_000

    static var trialWasStarted: Bool {
        trialStartEpochMs() != nil
    }

    static var isTrialActive: Bool {
        guard let start = trialStartEpochMs() else { return false }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return now - start < trialDurationMs
    }

    /// Returns false if trial was already used on this device.
    @discardableResult
    static func startTrial() -> Bool {
        guard !trialWasStarted else { return false }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        UserDefaults.standard.set(now, forKey: startKey)
        return true
    }

    #if DEBUG
    static func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: startKey)
    }
    #endif

    private static func trialStartEpochMs() -> Int64? {
        guard let value = UserDefaults.standard.object(forKey: startKey) else { return nil }
        if let ms = value as? Int64 { return ms }
        if let ms = value as? Int { return Int64(ms) }
        if let number = value as? NSNumber { return number.int64Value }
        return nil
    }
}
