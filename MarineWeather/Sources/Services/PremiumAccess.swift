import Foundation
import Observation
import StoreKit

/// Why route / 12-day wind is unlocked (for UI and debug).
enum PremiumUnlockSource: Equatable {
    case none
    case appStore
    case trial
    case debugOverride
}

/// Premium gate: StoreKit purchase, optional local trial, DEBUG override.
@MainActor
@Observable
final class PremiumAccess {
    static let shared = PremiumAccess()

    private let store = StoreKitRoutePremiumService()

    private(set) var purchaseError: String?
    private(set) var isPurchasing = false
    private(set) var billingReady = false
    private(set) var productsUnavailable = false
    private(set) var billingDiagnostic = ""
    private(set) var lifetimeProduct: Product?
    private(set) var subscriptionProduct: Product?
    private(set) var isPremium = false
    private(set) var unlockSource: PremiumUnlockSource = .none

    /// DEBUG screenshot automation; always false in Release.
    private(set) var iapReviewScreenshotMode = false

    #if DEBUG
    private static let debugUnlockKey = "route_premium_debug_unlock"
    #endif

    var showTrialOffer: Bool { !RouteTrialPreferences.trialWasStarted }

    private init() {
        refreshPremiumStatus()
    }

    func start() async {
        #if DEBUG
        if ScreenshotLaunch.iapReview {
            configureForIAPReviewScreenshot()
            return
        }
        #endif
        await store.start()
        syncFromStore()
    }

    /// Loads StoreKit products; safe to call from paywall before or after app `start()`.
    func ensureProductsLoaded() async {
        #if DEBUG
        if iapReviewScreenshotMode { return }
        #endif
        if !store.billingReady {
            await store.start()
        } else {
            await store.refreshProducts()
        }
        syncFromStore()
    }

    func restorePurchases() async {
        purchaseError = nil
        isPurchasing = true
        defer { isPurchasing = false }
        await store.syncEntitlements()
        syncFromStore()
        if !store.hasActivePurchase {
            purchaseError = String(localized: "route_premium_restore_none")
        }
    }

    func startTrial() {
        purchaseError = nil
        if !RouteTrialPreferences.startTrial() {
            purchaseError = String(localized: "route_premium_trial_already_used")
        }
        refreshPremiumStatus()
    }

    func purchaseLifetime() async {
        await runPurchase { try await store.purchaseLifetime() }
    }

    func purchaseMonthly() async {
        await runPurchase { try await store.purchaseMonthly() }
    }

    #if DEBUG
    func unlockForTesting() {
        UserDefaults.standard.set(true, forKey: Self.debugUnlockKey)
        refreshPremiumStatus()
    }

    /// Clears local trial and debug unlock. StoreKit test purchases remain until cleared in Xcode.
    func resetTestingPremiumState() {
        UserDefaults.standard.removeObject(forKey: Self.debugUnlockKey)
        RouteTrialPreferences.resetForTesting()
        purchaseError = nil
        iapReviewScreenshotMode = false
        refreshPremiumStatus()
    }

    /// App Store Connect IAP review screenshot (`-iapReviewScreenshot` launch arg).
    func configureForIAPReviewScreenshot() {
        resetTestingPremiumState()
        iapReviewScreenshotMode = true
        billingReady = true
        productsUnavailable = false
        billingDiagnostic = ""
        purchaseError = nil
    }
    #endif

    private func runPurchase(_ operation: () async throws -> Void) async {
        purchaseError = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await operation()
            syncFromStore()
        } catch let error as StoreKitPremiumError {
            if case .userCancelled = error { return }
            purchaseError = error.localizedDescription
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func syncFromStore() {
        billingReady = store.billingReady
        productsUnavailable = store.productsUnavailable
        billingDiagnostic = store.productQueryDiagnostic
        lifetimeProduct = store.lifetimeProduct
        subscriptionProduct = store.subscriptionProduct
        refreshPremiumStatus()
    }

    private func refreshPremiumStatus() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: Self.debugUnlockKey) {
            isPremium = true
            unlockSource = .debugOverride
            return
        }
        #endif

        if RouteTrialPreferences.isTrialActive {
            isPremium = true
            unlockSource = .trial
            return
        }

        if store.hasActivePurchase {
            isPremium = true
            unlockSource = .appStore
            return
        }

        isPremium = false
        unlockSource = .none
    }
}

#if DEBUG
extension PremiumUnlockSource {
    var debugLabel: String {
        switch self {
        case .none: String(localized: "route_premium_source_none")
        case .appStore: String(localized: "route_premium_source_app_store")
        case .trial: String(localized: "route_premium_source_trial")
        case .debugOverride: String(localized: "route_premium_source_debug")
        }
    }
}
#endif
