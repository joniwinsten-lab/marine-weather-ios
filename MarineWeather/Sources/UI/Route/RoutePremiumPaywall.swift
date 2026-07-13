import StoreKit
import SwiftUI
#if DEBUG
import UIKit
#endif

/// StoreKit 2 paywall for route + 12-day wind (Android `RoutePremiumPaywall`).
struct RoutePremiumPaywall: View {
    @Bindable var premium: PremiumAccess
    var onUnlocked: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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

                monthlySubscriptionCard

                Button {
                    Task {
                        await premium.purchaseLifetime()
                        if premium.isPremium { onUnlocked() }
                    }
                } label: {
                    Text(lifetimeButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!lifetimeReady || premium.isPurchasing)

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

                if premium.showTrialOffer {
                    Button {
                        premium.startTrial()
                        if premium.isPremium { onUnlocked() }
                    } label: {
                        Text(String(localized: "route_premium_trial_secondary"))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .multilineTextAlignment(.center)
                }

                subscriptionLegalDisclosure

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
        #if DEBUG
        .task {
            guard ScreenshotLaunch.openTermsForReview else { return }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await UIApplication.shared.open(AppConfig.termsOfUseURL)
        }
        #endif
    }

    private var monthlySubscriptionCard: some View {
        VStack(spacing: 10) {
            Text(String(localized: "route_premium_monthly_heading"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(monthlyPriceLabel)
                .font(.system(size: 36, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(String(localized: "route_premium_monthly_per_period"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await premium.purchaseMonthly()
                    if premium.isPremium { onUnlocked() }
                }
            } label: {
                Text(String(format: String(localized: "route_premium_subscribe_cta"), monthlyPriceLabel))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!monthlyReady || premium.isPurchasing)

            Text(String(localized: "route_premium_sub_recurring_hint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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

    private var monthlyPriceLabel: String {
        premium.subscriptionProduct?.displayPrice ?? monthlyFallbackPrice
    }

    private var subscriptionLegalDisclosure: some View {
        VStack(spacing: 6) {
            Text(
                String(
                    format: String(localized: "route_premium_sub_legal_disclosure"),
                    monthlyPriceLabel
                )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }

    private var legalLinks: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                Link(String(localized: "route_premium_privacy_policy"), destination: AppConfig.privacyPolicyURL)
                Link(String(localized: "route_premium_terms_of_use"), destination: AppConfig.termsOfUseURL)
            }
            .font(.caption.weight(.medium))

            Text(AppConfig.termsOfUseURL.absoluteString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .padding(.top, 4)
    }
}
