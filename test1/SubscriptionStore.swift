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
///
/// Transactions that arrive outside a purchase or restore call (Ask-to-Buy
/// approvals, renewals) set `shouldSendReceipt` and post
/// `receiptNeedsSendingNotification`; AppDelegate answers it with the launch
/// receipt retry.
@MainActor
@objc final class SubscriptionStore: NSObject {
    @objc static let shared = SubscriptionStore()

    /// Posted on the main queue after `shouldSendReceipt` was set for a
    /// transaction that no purchase or restore caller is registering.
    @objc static let receiptNeedsSendingNotification =
        Notification.Name("SubscriptionStoreReceiptNeedsSending")

    private static let productID = "1YRNOADSORLIMITS"

    private var product: Product?
    private var updatesTask: Task<Void, Never>?
    /// Purchase and restore calls in progress. Their ObjC callers POST the
    /// receipt themselves, so the updates listener stays out of the way
    /// meanwhile rather than racing them with a second POST.
    private var callerRegistrations = 0
    /// Transactions purchase() already returned to its caller, in case the
    /// updates listener sees them after the call has ended.
    private var purchaseHandledIDs = Set<UInt64>()

    private override init() {
        super.init()
    }

    /// Starts listening for transactions that arrive outside a purchase call
    /// (renewals, Ask-to-Buy approvals, unfinished transactions at launch).
    /// Every transaction is finished, verified or not, as the StoreKit 1
    /// observer did before.
    @objc func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                await self?.handleUpdate(result)
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
            self.callerRegistrations += 1
            defer { self.callerRegistrations -= 1 }
            do {
                let product = try await self.resolveProduct()
                switch try await product.purchase() {
                case .success(.verified(let transaction)):
                    self.purchaseHandledIDs.insert(transaction.id)
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
            self.callerRegistrations += 1
            defer { self.callerRegistrations -= 1 }
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

    private func handleUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            // An approval or renewal nobody else will report: flag the receipt
            // for upload before finishing, so a crash in between still leaves
            // the launch retry armed.
            let needsServer = transaction.productID == Self.productID
                && transaction.revocationDate == nil
                && callerRegistrations == 0
                && !purchaseHandledIDs.contains(transaction.id)
            if needsServer {
                UserDefaults.standard.set(true, forKey: "shouldSendReceipt")
            }
            await transaction.finish()
            if needsServer {
                NotificationCenter.default.post(
                    name: Self.receiptNeedsSendingNotification, object: nil)
            }
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
