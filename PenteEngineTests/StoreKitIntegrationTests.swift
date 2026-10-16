import StoreKit
import StoreKitTest
import UIKit
import XCTest
@testable import penteLive

private struct NotAJWS: Error {}

/// Spec 7.2: StoreService over the real StoreKit 2 adapter, against StoreKit
/// Testing (`SKTestSession`, `Products.storekit`), with the pente.org server
/// faked. Xcode-signed transactions fail the server's Apple verification by
/// design, so every test stops at the app's POST.
@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    private var session: SKTestSession!
    private var server: FakeStoreServer!
    private var messages: FakeStoreMessages!
    private var host: FakeStoreHost!
    private var source: StoreKitTransactionSource!
    private var service: StoreService!

    /// A stuck purchase fails the test instead of hanging the run (enforced
    /// with `-test-timeouts-enabled YES`).
    override func setUp() async throws {
        try await super.setUp()
        executionTimeAllowance = 60
    }

    /// XCTest keeps every test case instance alive for the whole run: let the
    /// service's POSTs and resyncs end, stop the adapter's `Transaction.updates`
    /// listener, which would otherwise act on the next tests' transactions,
    /// and leave StoreKit Testing empty.
    override func tearDown() async throws {
        await service?.idle()
        source?.stopListening()
        session?.clearTransactions()
        service = nil
        source = nil
        server = nil
        messages = nil
        host = nil
        session = nil
        try await super.tearDown()
    }

    /// What StoreKit itself still holds unfinished (not the adapter's copy),
    /// as `transactionKey`s.
    private func storeKitUnfinishedKeys() async -> [String] {
        var keys: [String] = []
        for await result in Transaction.unfinished {
            keys.append((try? transactionKey(result.jwsRepresentation)) ?? "?")
        }
        return keys
    }

    /// StoreKit updates its unfinished list a moment after a finish():
    /// polls until it equals `expected`, then returns the last read.
    private func storeKitUnfinishedKeys(becoming expected: [String],
                                        within timeout: TimeInterval = 10) async -> [String] {
        let deadline = Date().addingTimeInterval(timeout)
        var keys = await storeKitUnfinishedKeys()
        while keys != expected, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
            keys = await storeKitUnfinishedKeys()
        }
        return keys
    }

    /// The adapter's unfinished list (StoreKit's plus updates it recorded),
    /// polled until it equals `expected`, as `transactionKey`s.
    private func adapterUnfinishedKeys(becoming expected: [String],
                                       within timeout: TimeInterval = 10) async -> [String] {
        let deadline = Date().addingTimeInterval(timeout)
        var keys = await source.unfinished().map { (try? transactionKey($0.jws)) ?? "?" }
        while keys != expected, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
            keys = await source.unfinished().map { (try? transactionKey($0.jws)) ?? "?" }
        }
        return keys
    }

    /// A fresh StoreKit Testing session and a StoreService over the real adapter.
    private func start() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        // clearTransactions() does not empty Transaction.unfinished at once:
        // finish what is left and re-read until a read comes back empty.
        let deadline = Date().addingTimeInterval(10)
        while true {
            var left = 0
            for await result in Transaction.unfinished {
                left += 1
                await result.unsafePayloadValue.finish()
            }
            if left == 0 { break }
            guard Date() < deadline else {
                XCTFail("StoreKit Testing did not clear")
                break
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        server = FakeStoreServer()
        messages = FakeStoreMessages()
        host = FakeStoreHost()
        source = StoreKitTransactionSource()
        let suite = "StoreKitIntegrationTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        service = StoreService(server: server, source: source, clock: FakeStoreClock(),
                               messages: messages, host: host, defaults: defaults)
        // The probe saw a cold simulator return 4 of the 5 products once.
        for _ in 0..<10 {
            await service.loadProducts()
            if Set(service.products.map(\.id)) == Set(StoreProducts.all) { return }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        XCTFail("StoreKit Testing returned only \(service.products.map(\.id))")
    }

    /// The claims of a JWS (its middle part, base64url).
    private func payload(_ jws: String) throws -> [String: Any] {
        let parts = jws.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { throw NotAJWS() }
        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let claims = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw NotAJWS() }
        return claims
    }

    /// Identifies a transaction across JWS copies: StoreKit Testing on the
    /// simulator often gives every transaction id 0, so the product and the
    /// purchase date (ms) stand in for it.
    private func transactionKey(_ jws: String) throws -> String {
        let claims = try payload(jws)
        return "\(claims["productId"] ?? "?")@\(claims["purchaseDate"] ?? "?")"
    }

    /// StoreKit's own id for the transaction: a renewal gets a new one.
    private func transactionID(_ jws: String) throws -> String {
        "\(try payload(jws)["transactionId"] ?? "?")"
    }

    private func skTransaction(for productID: String) throws -> SKTestTransaction {
        try XCTUnwrap(session.allTransactions().last { $0.productIdentifier == productID })
    }

    func testProductsAndPricesComeFromTheConfiguration() async throws {
        try await start()
        let prices = Dictionary(uniqueKeysWithValues: service.products.map { ($0.id, $0.displayPrice) })
        XCTAssertEqual(Set(prices.keys), Set(StoreProducts.all))
        XCTAssertFalse(prices[StoreProducts.yearly]?.isEmpty ?? true)
        XCTAssertTrue(source.canMakePayments)
    }

    func testBuyPostsTheJwsBoundToTheTokenAndFinishesAfterTheReply() async throws {
        try await start()
        server.defaultInfo = .info(StoreFixtures.info(token: StoreFixtures.tokenA))
        server.defaultReply = .success

        await service.buy(productID: StoreProducts.yearly, scene: nil)

        XCTAssertEqual(server.posted.count, 1)
        let claims = try payload(server.posted[0])
        XCTAssertEqual((claims["appAccountToken"] as? String)?.lowercased(),
                       StoreFixtures.tokenA.uuidString.lowercased())
        XCTAssertEqual(claims["productId"] as? String, StoreProducts.yearly)
        XCTAssertEqual(messages.shown, [.thankYou])
        let left = await storeKitUnfinishedKeys(becoming: [])
        XCTAssertEqual(left, [], "finished after the server answered")
    }

    func testRetryLaterKeepsTheTransactionUntilAResyncIsAnswered() async throws {
        try await start()
        server.replies = [.retryLater]
        server.defaultReply = .success

        await service.buy(productID: StoreProducts.monthPass, scene: nil)
        XCTAssertEqual(messages.shown, [.saved])
        XCTAssertEqual(server.posted.count, 1)
        guard server.posted.count == 1 else { return }
        let bought = try transactionKey(server.posted[0])
        XCTAssertTrue(bought.hasPrefix(StoreProducts.monthPass + "@"))
        let kept = await adapterUnfinishedKeys(becoming: [bought])
        XCTAssertEqual(kept, [bought])
        let heldByStoreKit = await storeKitUnfinishedKeys(becoming: [bought])
        XCTAssertEqual(heldByStoreKit, [bought], "StoreKit itself still holds it unfinished")

        await service.performResync(explicit: false)
        XCTAssertEqual(server.posted.count, 2)
        guard server.posted.count == 2 else { return }
        XCTAssertEqual(try transactionKey(server.posted[1]), bought, "the same transaction is posted again")
        let left = await adapterUnfinishedKeys(becoming: [])
        XCTAssertEqual(left, [])
        let leftInStoreKit = await storeKitUnfinishedKeys(becoming: [])
        XCTAssertEqual(leftInStoreKit, [], "finished in StoreKit after the resync was answered")
        XCTAssertEqual(messages.shown, [.saved], "the automatic resync is silent")
    }

    /// StoreKit Testing on the iOS 27 simulator cannot simulate a user
    /// cancel: a simulated `StoreKitError.userCancelled` arrives as
    /// `StoreKitError.unknown` (dry run, 2026-10-16), and the deprecated
    /// `failureError = .paymentCancelled` as ASDServerErrorDomain 537. So this
    /// drives a purchase error; the silent cancel is pinned by
    /// `StoreServiceBuyTests.testCancelledPendingAndFailedPurchases` and M1.
    func testAFailedPurchasePostsNothingAndSaysSo() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("setSimulatedError is iOS 17+") }
        try await start()
        try await session.setSimulatedError(.generic(.unknown), forAPI: .purchase)

        await service.buy(productID: "vacation_10", scene: nil)
        try await session.setSimulatedError(nil, forAPI: .purchase)

        XCTAssertEqual(server.posted, [])
        XCTAssertEqual(messages.shown, [.purchaseFailed])
    }

    func testAskToBuyIsPendingAndTheApprovalIsPostedSilently() async throws {
        try await start()
        service.start()
        session.askToBuyEnabled = true

        await service.buy(productID: "vacation_10", scene: nil)
        XCTAssertEqual(messages.shown, [.pending])
        XCTAssertEqual(server.posted, [])

        // StoreKit Testing loses an approval made right after the purchase.
        try await Task.sleep(nanoseconds: 2_000_000_000)
        try session.approveAskToBuyTransaction(identifier: try skTransaction(for: "vacation_10").identifier)
        await waitFor(20) { self.server.posted.count == 1 }
        guard server.posted.count == 1 else { return }
        XCTAssertEqual(try payload(server.posted[0])["productId"] as? String, "vacation_10")
        XCTAssertEqual(messages.shown, [.pending])
    }

    func testRefundIsPostedFinishedAndRefreshesTheDashboard() async throws {
        try await start()
        service.start()
        await service.buy(productID: StoreProducts.yearly, scene: nil)
        XCTAssertEqual(server.posted.count, 1)
        let changesAfterBuy = host.entitlementChanges
        server.replies = [.invalidReceipt]

        // StoreKit Testing sometimes drops a refund made right after the purchase.
        try await Task.sleep(nanoseconds: 2_000_000_000)
        try session.refundTransaction(identifier: try skTransaction(for: StoreProducts.yearly).identifier)

        await waitFor(20) { self.server.posted.count == 2 }
        guard server.posted.count == 2 else { return }
        XCTAssertNotNil(try payload(server.posted[1])["revocationDate"], "the revoked transaction is posted")
        await waitFor(20) { self.host.entitlementChanges > changesAfterBuy }
        let left = await adapterUnfinishedKeys(becoming: [])
        XCTAssertEqual(left, [], "finished after the server's answer")
        XCTAssertEqual(messages.shown, [.thankYou])
    }

    /// StoreKit Testing does not deliver a forced renewal on
    /// `Transaction.updates` (dry run, 2026-10-16: nothing within 8 s), but it
    /// is in `Transaction.unfinished` at once; the automatic resync on the
    /// return to the foreground posts it, as it would a renewal the app missed.
    /// StoreKit drops a finished transaction from `Transaction.unfinished` a
    /// moment late, so an early resync may post the purchase again (harmless:
    /// the server is idempotent); the test waits for the renewal itself.
    func testRenewalIsPostedSilently() async throws {
        try await start()
        service.start()
        await service.buy(productID: StoreProducts.yearly, scene: nil)
        XCTAssertEqual(server.posted.count, 1)
        guard let bought = server.posted.first else { return }
        let boughtID = try transactionID(bought)

        try session.forceRenewalOfSubscription(productIdentifier: StoreProducts.yearly)

        func renewals() -> [String] {
            server.posted.filter { (try? self.transactionID($0)) != boughtID }
        }
        for _ in 0..<20 where renewals().isEmpty {
            await service.performResync(explicit: false) // the foreground trigger
            if renewals().isEmpty { try await Task.sleep(nanoseconds: 1_000_000_000) }
        }
        let renewal = try XCTUnwrap(renewals().first, "the renewal is posted")
        XCTAssertEqual(try payload(renewal)["productId"] as? String, StoreProducts.yearly)
        XCTAssertEqual(try payload(renewal)["originalTransactionId"] as? String,
                       try payload(bought)["originalTransactionId"] as? String)
        XCTAssertEqual(messages.shown, [.thankYou])
        let left = await storeKitUnfinishedKeys(becoming: [])
        XCTAssertEqual(left, [], "the renewal is finished after the server's answer")
    }

    func testRestorePostsTheEntitlementAndSaysUpToDate() async throws {
        try await start()
        await service.buy(productID: StoreProducts.yearly, scene: nil)
        server.replies = [.known]

        await service.restore()

        XCTAssertEqual(server.posted.count, 2)
        XCTAssertEqual(messages.shown, [.thankYou, .upToDate])
    }

    /// StoreKit Testing hands the expired transaction back as unfinished
    /// (dry run, 2026-10-16), so restore posts it again; pente.org answers
    /// `inactive` for it, which restores nothing.
    func testRestoreAfterExpiryHasNothingToRestore() async throws {
        try await start()
        await service.buy(productID: StoreProducts.yearly, scene: nil)

        try session.expireSubscription(productIdentifier: StoreProducts.yearly)
        var entitled = await source.latestEntitlements()
        for _ in 0..<20 where !entitled.isEmpty {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            entitled = await source.latestEntitlements()
        }
        XCTAssertTrue(entitled.isEmpty, "the expired subscription is no current entitlement")
        server.defaultReply = .inactive

        await service.restore()

        XCTAssertEqual(server.posted.count, 2)
        guard server.posted.count == 2 else { return }
        XCTAssertEqual(try transactionKey(server.posted[1]), try transactionKey(server.posted[0]),
                       "only the expired transaction itself is posted again")
        XCTAssertEqual(messages.shown, [.thankYou, .noPurchasesToRestore])
        let left = await storeKitUnfinishedKeys(becoming: [])
        XCTAssertEqual(left, [], "finished after the inactive reply")
    }

    func testMigrationSweepPostsTheEntitlementOncePerAccount() async throws {
        try await start()
        // Finished, but no success*: this account has not been swept yet.
        server.replies = [.invalidReceipt]
        await service.buy(productID: StoreProducts.yearly, scene: nil)
        XCTAssertEqual(messages.shown, [.purchaseFailed])
        server.defaultReply = .known

        service.sessionDidChange(loggedIn: true)
        await waitFor(20) { self.server.posted.count == 2 }
        // The POST count rises before the reply is handled and remembered.
        await waitFor(10) { self.host.entitlementChanges > 0 }

        service.sessionDidChange(loggedIn: true)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        XCTAssertEqual(server.posted.count, 2, "remembered after the success* reply")
        XCTAssertEqual(messages.shown, [.purchaseFailed])
    }

    func testPurchaseConfirmsInTheWindowSceneOnIOS17() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("purchase(confirmIn:) is iOS 17+") }
        try await start()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)

        await service.buy(productID: "vacation_30", scene: scene)

        XCTAssertEqual(server.posted.count, 1)
        XCTAssertEqual(try payload(server.posted[0])["productId"] as? String, "vacation_30")
        XCTAssertEqual(messages.shown, [.thankYou])
    }
}
