import Foundation
import UIKit

/// The five App Store products (spec 1). Prices always come from StoreKit.
enum StoreProducts {
    static let yearly = "1YRNOADSORLIMITS"
    static let monthPass = "month_pass"
    static let vacations = ["vacation_10", "vacation_30", "vacation_60"]
    static let vacationDays = ["vacation_10": 10, "vacation_30": 30, "vacation_60": 60]
    static let all = [yearly, monthPass] + vacations
}

/// A StoreKit product as the Store screen needs it.
struct StoreProductInfo: Equatable {
    let id: String
    let displayPrice: String
}

/// One StoreKit 2 transaction as `StoreService` handles it. `jws` is the
/// `jwsRepresentation` of its `VerificationResult`, posted whether or not it
/// verified locally (spec 5.1).
struct StoreTransaction: Equatable {
    let id: UInt64
    let productID: String
    let jws: String
    let verified: Bool
    let isRevoked: Bool
}

/// The answer to one GET of /gameServer/appStorePurchase.
enum StoreInfoResult: Equatable {
    case info(StoreInfo)
    case failed
    case sessionLost
}

enum PurchaseOutcome: Equatable {
    case transaction(StoreTransaction)
    case cancelled
    case pending
    case failed
}

enum StoreSyncError: Error, Equatable {
    /// The player cancelled the Apple ID prompt.
    case cancelled
    case failed
}

/// pente.org's /gameServer/appStorePurchase, on the logged-in session.
@MainActor
protocol StoreServerClient: AnyObject {
    func fetchInfo(username: String) async -> StoreInfoResult
    func post(signedTransaction: String) async -> StoreReply
}

/// Everything `StoreService` needs from StoreKit 2. The real adapter is
/// `StoreKitTransactionSource`; tests use a fake.
@MainActor
protocol TransactionSource: AnyObject {
    var canMakePayments: Bool { get }
    func products(for ids: [String]) async -> [StoreProductInfo]
    /// `purchase(confirmIn: scene, options:)` on iOS 17+ when a scene is
    /// given, `purchase(options:)` otherwise; always with the token.
    func purchase(productID: String, token: UUID, scene: UIWindowScene?) async -> PurchaseOutcome
    func unfinished() async -> [StoreTransaction]
    /// The latest transaction of each `Transaction.currentEntitlements` item.
    func latestEntitlements() async -> [StoreTransaction]
    func finish(_ transactionID: UInt64) async
    /// `AppStore.sync()`; throws `StoreSyncError.cancelled` for a cancelled
    /// Apple ID prompt, `.failed` otherwise.
    func sync() async throws
    /// Starts the `Transaction.updates` listener; `onUpdate` runs on the main
    /// actor after each update was recorded.
    func startListening(_ onUpdate: @escaping @MainActor () -> Void)
    /// `AppStore.showManageSubscriptions(in:)`; false when it failed.
    func showManageSubscriptions(in scene: UIWindowScene) async -> Bool
}

@MainActor
protocol StoreClock: AnyObject {
    func now() -> Date
    /// Runs `work` on the main actor after `seconds`.
    func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor () -> Void)
}

@MainActor
protocol StoreMessageSink: AnyObject {
    func show(_ message: StoreMessage)
}

/// The app around the Store: session, foreground state, re-login, dashboard.
@MainActor
protocol StoreHost: AnyObject {
    /// The logged-in pente.org username, lowercased; nil unless
    /// `navC.loggedIn` is set (spec 5.1 "Session").
    var username: String? { get }
    var isInForeground: Bool { get }
    /// HTTP 401: mark the session gone and log in again as the app does
    /// elsewhere; the post-login resync then sends what is unfinished.
    func sessionLost()
    /// After a `success*` or a revocation: refresh the dashboard so
    /// `PentePlayer.subscriber` updates.
    func entitlementsChanged()
}
