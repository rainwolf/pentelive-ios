import Foundation
import UIKit
import XCTest
@testable import penteLive

enum StoreFixtures {
    static let tokenA = UUID(uuidString: "00000000-0001-8000-8000-00000000000a")!
    static let tokenB = UUID(uuidString: "00000000-0002-8000-8000-00000000000b")!
    static let fixedNow = Date(timeIntervalSince1970: 1_791_000_000) // 2026-10-03 UTC
    static let allProducts = [
        StoreProductInfo(id: "1YRNOADSORLIMITS", displayPrice: "$9.99"),
        StoreProductInfo(id: "month_pass", displayPrice: "$1.99"),
        StoreProductInfo(id: "vacation_10", displayPrice: "$0.99"),
        StoreProductInfo(id: "vacation_30", displayPrice: "$1.99"),
        StoreProductInfo(id: "vacation_60", displayPrice: "$2.99"),
    ]

    static func info(user: String = "iostest", token: UUID = tokenA, subscribedUntil: Date? = nil,
                     hasActive: Bool = false, vacationDaysLeft: Int = 12,
                     products: [String] = StoreProducts.all) -> StoreInfo {
        StoreInfo(username: user, appAccountToken: token, subscribedUntil: subscribedUntil,
                  hasActiveAppleSubscription: hasActive, vacationDaysLeft: vacationDaysLeft, products: products)
    }

    static func transaction(_ id: UInt64, product: String = "1YRNOADSORLIMITS", verified: Bool = true,
                            revoked: Bool = false) -> StoreTransaction {
        StoreTransaction(id: id, productID: product, jws: "jws-\(id)", verified: verified, isRevoked: revoked)
    }
}

@MainActor
final class FakeStoreServer: StoreServerClient {
    /// Consumed in order; when empty, `defaultInfo` answers.
    var infoResults: [StoreInfoResult] = []
    var defaultInfo: StoreInfoResult = .info(StoreFixtures.info())
    /// Consumed in order; when empty, `defaultReply` answers.
    var replies: [StoreReply] = []
    var defaultReply: StoreReply = .success
    /// Runs inside fetchInfo before it answers (to switch accounts mid-GET).
    var onFetch: (() -> Void)?
    var holdPosts = false
    private(set) var fetches: [String] = []
    private(set) var posted: [String] = []
    private(set) var maxConcurrentPosts = 0
    private var concurrentPosts = 0
    private var held: [CheckedContinuation<Void, Never>] = []

    var heldCount: Int { held.count }

    func fetchInfo(username: String) async -> StoreInfoResult {
        fetches.append(username)
        onFetch?()
        return infoResults.isEmpty ? defaultInfo : infoResults.removeFirst()
    }

    func post(signedTransaction: String) async -> StoreReply {
        posted.append(signedTransaction)
        concurrentPosts += 1
        maxConcurrentPosts = max(maxConcurrentPosts, concurrentPosts)
        if holdPosts {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                held.append(continuation)
            }
        }
        concurrentPosts -= 1
        return replies.isEmpty ? defaultReply : replies.removeFirst()
    }

    func releasePosts() {
        holdPosts = false
        let waiting = held
        held = []
        waiting.forEach { $0.resume() }
    }
}

@MainActor
final class FakeTransactionSource: TransactionSource {
    var canMakePayments = true
    var available: [StoreProductInfo] = StoreFixtures.allProducts
    var unfinishedTransactions: [StoreTransaction] = []
    var entitlements: [StoreTransaction] = []
    var purchaseOutcome: PurchaseOutcome = .cancelled
    /// Runs inside purchase before it answers (to lose the session mid-sheet).
    var onPurchase: (() -> Void)?
    var syncError: StoreSyncError?
    var manageResult = true
    private(set) var manageCalls = 0
    private(set) var purchasedProducts: [String] = []
    private(set) var purchaseTokens: [UUID] = []
    private(set) var finished: [UInt64] = []
    private(set) var unfinishedReads = 0
    private(set) var entitlementReads = 0
    private(set) var syncCalls = 0
    private(set) var listener: (@MainActor () -> Void)?

    func products(for ids: [String]) async -> [StoreProductInfo] {
        available.filter { ids.contains($0.id) }
    }

    func purchase(productID: String, token: UUID, scene: UIWindowScene?) async -> PurchaseOutcome {
        purchasedProducts.append(productID)
        purchaseTokens.append(token)
        onPurchase?()
        if case .transaction(let transaction) = purchaseOutcome,
           !unfinishedTransactions.contains(where: { $0.id == transaction.id }) {
            unfinishedTransactions.append(transaction) // StoreKit holds it until finish()
        }
        return purchaseOutcome
    }

    func unfinished() async -> [StoreTransaction] {
        unfinishedReads += 1
        return unfinishedTransactions
    }

    func latestEntitlements() async -> [StoreTransaction] {
        entitlementReads += 1
        return entitlements
    }

    func finish(_ transactionID: UInt64) async {
        finished.append(transactionID)
        unfinishedTransactions.removeAll { $0.id == transactionID }
    }

    func sync() async throws {
        syncCalls += 1
        if let syncError = syncError { throw syncError }
    }

    func startListening(_ onUpdate: @escaping @MainActor () -> Void) {
        listener = onUpdate
    }

    func showManageSubscriptions(in scene: UIWindowScene) async -> Bool {
        manageCalls += 1
        return manageResult
    }
}

@MainActor
final class FakeStoreClock: StoreClock {
    var current = StoreFixtures.fixedNow
    private(set) var scheduled: [TimeInterval] = []
    private var pending: [@MainActor () -> Void] = []

    var pendingCount: Int { pending.count }

    func now() -> Date { current }

    func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        scheduled.append(seconds)
        pending.append(work)
    }

    /// Fires every timer scheduled so far.
    func fireAll() {
        let due = pending
        pending = []
        due.forEach { $0() }
    }
}

@MainActor
final class FakeStoreMessages: StoreMessageSink {
    private(set) var shown: [StoreMessage] = []
    func show(_ message: StoreMessage) { shown.append(message) }
}

@MainActor
final class FakeStoreHost: StoreHost {
    var username: String? = "iostest"
    var isInForeground = true
    private(set) var sessionLostCount = 0
    private(set) var entitlementChanges = 0

    func sessionLost() {
        sessionLostCount += 1
        username = nil
    }

    func entitlementsChanged() { entitlementChanges += 1 }
}

/// A StoreService over fakes, with its own UserDefaults suite.
@MainActor
final class StoreHarness {
    let server = FakeStoreServer()
    let source = FakeTransactionSource()
    let clock = FakeStoreClock()
    let messages = FakeStoreMessages()
    let host = FakeStoreHost()
    let defaults: UserDefaults
    let service: StoreService

    init() {
        let suite = "StoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        service = StoreService(server: server, source: source, clock: clock, messages: messages,
                               host: host, defaults: defaults)
    }

    func loadBoth() async {
        await service.loadInfo()
        await service.loadProducts()
    }
}

/// Polls `condition` on the main actor every 10 ms (milliseconds).
@MainActor
func waitFor(_ timeout: TimeInterval = 5, file: StaticString = #filePath, line: UInt = #line,
             _ condition: () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        if Date() > deadline {
            XCTFail("condition not met within \(timeout) s", file: file, line: line)
            return
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
