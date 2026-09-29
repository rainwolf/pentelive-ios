import Foundation
import StoreKit

/// The one subscription product, as the ObjC UI needs it: an identifier and a
/// price string already formatted for the user's storefront.
@objc final class SubscriptionProduct: NSObject {
    @objc let productID: String
    @objc let displayPrice: String

    init(productID: String, displayPrice: String) {
        self.productID = productID
        self.displayPrice = displayPrice
        super.init()
    }
}

@objc enum SubscriptionPurchaseResult: Int {
    case purchased
    case cancelled
    case pending
    case failed
}

/// StoreKit 2 wrapper for the yearly no-ads/no-limits subscription.
///
/// Entitlement is owned by the pente.org server: the app only needs to buy,
/// restore and finish transactions, then upload the receipt (done by the ObjC
/// callers). Every completion is delivered on the main queue.
@MainActor
@objc final class SubscriptionStore: NSObject {
    @objc static let shared = SubscriptionStore()

    private static let productID = "1YRNOADSORLIMITS"

    private var product: Product?
    private var updatesTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    /// Starts listening for transactions that arrive outside a purchase call
    /// (renewals, Ask-to-Buy approvals, unfinished transactions at launch).
    /// Every transaction is finished, verified or not, as RMStore did.
    @objc func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task.detached(priority: .background) {
            for await result in Transaction.updates {
                await SubscriptionStore.finish(result)
            }
        }
    }

    @objc func loadProduct(completion: @escaping (SubscriptionProduct?, NSError?) -> Void) {
        Task { @MainActor in
            do {
                let products = try await Product.products(for: [Self.productID])
                guard let product = products.first(where: { $0.id == Self.productID }) else {
                    completion(nil, nil)
                    return
                }
                self.product = product
                completion(SubscriptionProduct(productID: product.id,
                                               displayPrice: product.displayPrice),
                           nil)
            } catch {
                completion(nil, error as NSError)
            }
        }
    }

    @objc func purchase(completion: @escaping (SubscriptionPurchaseResult, NSError?) -> Void) {
        Task { @MainActor in
            do {
                let product = try await self.resolveProduct()
                switch try await product.purchase() {
                case .success(.verified(let transaction)):
                    await transaction.finish()
                    completion(.purchased, nil)
                case .success(.unverified(let transaction, let verificationError)):
                    await transaction.finish()
                    completion(.failed, verificationError as NSError)
                case .userCancelled:
                    completion(.cancelled, nil)
                case .pending:
                    completion(.pending, nil)
                @unknown default:
                    completion(.failed, Self.error("Unknown purchase result"))
                }
            } catch {
                completion(.failed, error as NSError)
            }
        }
    }

    @objc func restore(completion: @escaping (NSError?) -> Void) {
        Task { @MainActor in
            do {
                try await AppStore.sync()
                completion(nil)
            } catch {
                completion(error as NSError)
            }
        }
    }

    // MARK: - Private

    private func resolveProduct() async throws -> Product {
        if let product {
            return product
        }
        let products = try await Product.products(for: [Self.productID])
        guard let product = products.first(where: { $0.id == Self.productID }) else {
            throw Self.error("Subscription product is not available")
        }
        self.product = product
        return product
    }

    private nonisolated static func finish(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await transaction.finish()
        case .unverified(let transaction, let verificationError):
            NSLog("SubscriptionStore: finishing unverified transaction %llu (%@): %@",
                  transaction.id, transaction.productID,
                  verificationError.localizedDescription)
            await transaction.finish()
        }
    }

    private static func error(_ description: String) -> NSError {
        NSError(domain: "SubscriptionStore", code: 1,
                userInfo: [NSLocalizedDescriptionKey: description])
    }
}
