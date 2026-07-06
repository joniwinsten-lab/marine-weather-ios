import StoreKit
import SwiftUI

/// StoreKit 2 paywall for route + 12-day wind (Android `RoutePremiumPaywall`).
struct RoutePremiumPaywall: View {
    @Bindable var premium: PremiumAccess
    var onUnlocked: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                Text(String(localized: "route_premium_title"))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(String(localized: "route_premium_body"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if premium.showTrialOffer {
                    Button {
                        premium.startTrial()
                        if premium.isPremium { onUnlocked() }
                    } label: {
                        Text(String(localized: "route_premium_trial_cta"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    Task {
                        await premium.purchaseLifetime()
                        if premium.isPremium { onUnlocked() }
                    }
                } label: {
                    Text(lifetimeButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!lifetimeReady || premium.isPurchasing)

                Button {
                    Task {
                        await premium.purchaseMonthly()
                        if premium.isPremium { onUnlocked() }
                    }
                } label: {
                    Text(monthlyButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!monthlyReady || premium.isPurchasing)

                Text(String(localized: "route_premium_sub_recurring_hint"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task {
                        await premium.restorePurchases()
                        if premium.isPremium { onUnlocked() }
                    }
                } label: {
                    Text(String(localized: "route_premium_restore"))
                }
                .buttonStyle(.bordered)
                .disabled(premium.isPurchasing)

                if premium.isPurchasing {
                    ProgressView()
                }

                if let error = premium.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if premium.productsUnavailable, premium.billingReady, !premium.iapReviewScreenshotMode {
                    Text(String(localized: "route_premium_prices_unavailable"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                    if !premium.billingDiagnostic.isEmpty {
                        Text(premium.billingDiagnostic)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                    }
                }

                Text(String(localized: "route_premium_vat_note"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(String(localized: "route_premium_trial_appstore_note"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                legalLinks

                #if DEBUG
                if !premium.iapReviewScreenshotMode {
                    Button(String(localized: "route_premium_dev_unlock")) {
                        premium.unlockForTesting()
                        onUnlocked()
                    }
                    .font(.caption)
                    .padding(.top, 4)
                }
                #endif
            }
            .padding(20)
            .frame(maxWidth: UiBreakpoints.paywallMaxWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await premium.ensureProductsLoaded()
        }
    }

    private var lifetimeReady: Bool {
        #if DEBUG
        if premium.iapReviewScreenshotMode { return true }
        #endif
        return premium.billingReady && premium.lifetimeProduct != nil
    }

    private var monthlyReady: Bool {
        #if DEBUG
        if premium.iapReviewScreenshotMode { return true }
        #endif
        return premium.billingReady && premium.subscriptionProduct != nil
    }

    private var lifetimeButtonTitle: String {
        let price = premium.lifetimeProduct?.displayPrice ?? lifetimeFallbackPrice
        return String(format: String(localized: "route_premium_buy_once"), price)
    }

    private var monthlyButtonTitle: String {
        let price = premium.subscriptionProduct?.displayPrice ?? monthlyFallbackPrice
        return String(format: String(localized: "route_premium_subscribe_monthly"), price)
    }

    private var lifetimeFallbackPrice: String {
        if !premium.billingReady {
            return String(localized: "route_premium_price_loading")
        }
        return AppConfig.premiumLifetimeReferenceDisplay
    }

    private var monthlyFallbackPrice: String {
        if !premium.billingReady {
            return String(localized: "route_premium_price_loading")
        }
        return AppConfig.premiumMonthlyReferenceDisplay
    }

    private var legalLinks: some View {
        HStack(spacing: 20) {
            Link(String(localized: "route_premium_privacy_policy"), destination: AppConfig.privacyPolicyURL)
            Link(String(localized: "route_premium_terms_of_use"), destination: AppConfig.termsOfUseURL)
        }
        .font(.caption)
        .padding(.top, 4)
    }
}
