import Foundation
import OSLog
import StoreKit

private let storeKitLog = Logger(subsystem: "fi.veneappi.MarineWeather", category: "StoreKit")

/// StoreKit 2 for route premium products (lifetime + monthly subscription).
@MainActor
final class StoreKitRoutePremiumService {
    private(set) var billingReady = false
    private(set) var productsUnavailable = false
    private(set) var productQueryDiagnostic = ""
    private(set) var lifetimeProduct: Product?
    private(set) var subscriptionProduct: Product?
    private(set) var hasActivePurchase = false

    private var transactionListener: Task<Void, Never>?

    func start() async {
        transactionListener = Task { await listenForTransactionUpdates() }
        await loadProducts()
        await syncEntitlements()
        billingReady = true
    }

    func refreshProducts() async {
        guard billingReady else { return }
        await loadProducts()
    }

    func syncEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.isActivePremium(transaction) {
                owned = true
            }
        }
        hasActivePurchase = owned
    }

    func purchaseLifetime() async throws {
        guard let product = lifetimeProduct else {
            throw StoreKitPremiumError.productUnavailable
        }
        try await purchase(product)
    }

    func purchaseMonthly() async throws {
        guard let product = subscriptionProduct else {
            throw StoreKitPremiumError.productUnavailable
        }
        try await purchase(product)
    }

    private func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await syncEntitlements()
        case .userCancelled:
            throw StoreKitPremiumError.userCancelled
        case .pending:
            throw StoreKitPremiumError.pending
        @unknown default:
            throw StoreKitPremiumError.unknown
        }
    }

    private func loadProducts() async {
        let ids = [
            AppConfig.billingRoutePremiumLifetime,
            AppConfig.billingRoutePremiumMonthly,
        ]
        productQueryDiagnostic = "querying App Store products…"
        do {
            let products = try await Product.products(for: ids)
            lifetimeProduct = products.first { $0.id == AppConfig.billingRoutePremiumLifetime }
            subscriptionProduct = products.first { $0.id == AppConfig.billingRoutePremiumMonthly }
            let hasLifetimePrice = lifetimeProduct != nil
            let hasSubPrice = subscriptionProduct != nil
            productsUnavailable = !hasLifetimePrice && !hasSubPrice
            if productsUnavailable {
                let returned = products.map(\.id).joined(separator: ", ")
                productQueryDiagnostic =
                    "v\(AppConfig.marketingVersion); requested=\(ids.joined(separator: ",")); returned=[\(returned)]"
            } else {
                productQueryDiagnostic =
                    "v\(AppConfig.marketingVersion); lifetime=\(lifetimeProduct?.displayPrice ?? "?"); monthly=\(subscriptionProduct?.displayPrice ?? "?")"
            }
            #if DEBUG
            if productsUnavailable {
                storeKitLog.debug(
                    "No products for \(ids, privacy: .public). Returned: \(products.map(\.id), privacy: .public). Enable StoreKit Configuration: MarineWeather/Configuration/Products.storekit"
                )
            }
            #endif
        } catch {
            lifetimeProduct = nil
            subscriptionProduct = nil
            productsUnavailable = true
            productQueryDiagnostic = "v\(AppConfig.marketingVersion); query failed: \(error.localizedDescription)"
            #if DEBUG
            storeKitLog.debug("Product.products failed: \(String(describing: error), privacy: .public)")
            #endif
        }
    }

    private func listenForTransactionUpdates() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await transaction.finish()
            await syncEntitlements()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private static func isActivePremium(_ transaction: Transaction) -> Bool {
        guard transaction.revocationDate == nil else { return false }
        switch transaction.productID {
        case AppConfig.billingRoutePremiumLifetime:
            return true
        case AppConfig.billingRoutePremiumMonthly:
            guard let expiration = transaction.expirationDate else { return false }
            return expiration > Date()
        default:
            return false
        }
    }
}

enum StoreKitPremiumError: LocalizedError {
    case productUnavailable
    case userCancelled
    case pending
    case unknown

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return String(localized: "route_premium_prices_unavailable")
        case .userCancelled:
            return nil
        case .pending:
            return String(localized: "route_premium_purchase_pending")
        case .unknown:
            return String(localized: "route_premium_purchase_unavailable")
        }
    }
}
