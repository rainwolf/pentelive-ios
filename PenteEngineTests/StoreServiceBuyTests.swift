import XCTest
@testable import penteLive

/// Spec 5.1 session gating, per-username StoreInfo, fresh GET in buy,
/// unverified still posted, serial queue and in-flight set; 5.3 messages on
/// the explicit buy.
@MainActor
final class StoreServiceBuyTests: XCTestCase {
    private let yearly = StoreProducts.yearly

    func testBuyFetchesAFreshTokenAndPurchasesWithIt() async {
        let h = StoreHarness()
        await h.service.loadInfo()
        XCTAssertEqual(h.service.info?.appAccountToken, StoreFixtures.tokenA)
        h.server.infoResults = [.info(StoreFixtures.info(token: StoreFixtures.tokenB))]
        h.source.purchaseOutcome = .transaction(StoreFixtures.transaction(1))
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.source.purchaseTokens, [StoreFixtures.tokenB])
        XCTAssertEqual(h.source.purchasedProducts, [yearly])
        XCTAssertEqual(h.server.fetches.first, "iostest")
    }

    func testFailedGetStartsNoPurchase() async {
        let h = StoreHarness()
        h.server.defaultInfo = .failed
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.source.purchasedProducts, [])
        XCTAssertEqual(h.server.posted, [])
        XCTAssertEqual(h.messages.shown, [.couldNotReach])
    }

    func testLostSessionOnTheGetStartsNoPurchaseAndLogsInAgain() async {
        let h = StoreHarness()
        h.server.defaultInfo = .sessionLost
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.source.purchasedProducts, [])
        XCTAssertEqual(h.host.sessionLostCount, 1)
        XCTAssertEqual(h.messages.shown, [.couldNotReach])
    }

    func testNotLoggedInBuysAndFetchesNothing() async {
        let h = StoreHarness()
        h.host.username = nil
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.server.fetches, [])
        XCTAssertEqual(h.source.purchasedProducts, [])
        XCTAssertEqual(h.messages.shown, [])
    }

    func testSuccessThanksFinishesRefreshesTheDashboardAndReloadsInfo() async {
        let h = StoreHarness()
        h.source.purchaseOutcome = .transaction(StoreFixtures.transaction(1))
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.server.posted, ["jws-1"])
        XCTAssertEqual(h.source.finished, [1])
        XCTAssertEqual(h.messages.shown, [.thankYou])
        XCTAssertEqual(h.host.entitlementChanges, 1)
        XCTAssertEqual(h.server.fetches.count, 2, "the buy's fresh GET, then the reload after success")
        XCTAssertFalse(h.service.isBusy)
    }

    func testRenewalAndKnownOnTheBuyAlsoThank() async {
        for reply in [StoreReply.renewal, .known] {
            let h = StoreHarness()
            h.server.defaultReply = reply
            h.source.purchaseOutcome = .transaction(StoreFixtures.transaction(1))
            await h.service.buy(productID: yearly, scene: nil)
            XCTAssertEqual(h.messages.shown, [.thankYou], "\(reply)")
        }
    }

    func testEveryOtherReplyOnTheBuy() async {
        let cases: [(StoreReply, StoreMessage, Bool)] = [
            (.shared, .shared, true),
            (.invalidReceipt, .purchaseFailed, true),
            (.inactive, .inactive, true),
            (.retryLater, .saved, false),
            (.noReply, .saved, false),
        ]
        for (reply, message, finishes) in cases {
            let h = StoreHarness()
            h.server.defaultReply = reply
            h.source.purchaseOutcome = .transaction(StoreFixtures.transaction(1))
            await h.service.buy(productID: yearly, scene: nil)
            XCTAssertEqual(h.messages.shown, [message], "\(reply)")
            XCTAssertEqual(h.source.finished, finishes ? [1] : [], "\(reply)")
            XCTAssertEqual(h.source.unfinishedTransactions.map(\.id), finishes ? [] : [1], "\(reply)")
        }
    }

    func testUnverifiedTransactionIsStillPosted() async {
        let h = StoreHarness()
        h.source.purchaseOutcome = .transaction(StoreFixtures.transaction(1, verified: false))
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.server.posted, ["jws-1"])
        XCTAssertEqual(h.source.finished, [1])
    }

    func testCancelledPendingAndFailedPurchases() async {
        let cases: [(PurchaseOutcome, [StoreMessage])] = [
            (.cancelled, []),
            (.pending, [.pending]),
            (.failed, [.purchaseFailed]),
        ]
        for (outcome, messages) in cases {
            let h = StoreHarness()
            h.source.purchaseOutcome = outcome
            await h.service.buy(productID: "vacation_10", scene: nil)
            XCTAssertEqual(h.messages.shown, messages, "\(outcome)")
            XCTAssertEqual(h.server.posted, [], "\(outcome)")
        }
    }

    func testSessionLostBeforeThePostLeavesTheTransactionUnfinished() async {
        let h = StoreHarness()
        h.source.purchaseOutcome = .transaction(StoreFixtures.transaction(1))
        h.source.onPurchase = { h.host.username = nil }
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.server.posted, [])
        XCTAssertEqual(h.source.finished, [])
        XCTAssertEqual(h.source.unfinishedTransactions.map(\.id), [1])
        XCTAssertEqual(h.messages.shown, [.saved])
    }

    func test401OnThePostKeepsItUnfinishedAndLogsInAgain() async {
        let h = StoreHarness()
        h.server.defaultReply = .sessionLost
        h.source.purchaseOutcome = .transaction(StoreFixtures.transaction(1))
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.source.finished, [])
        XCTAssertEqual(h.host.sessionLostCount, 1)
        XCTAssertEqual(h.messages.shown, [.saved])
        XCTAssertEqual(h.clock.scheduled, [], "a lost session waits for the post-login resync, not the timer")
    }

    func testInfoIsKeyedToTheUsername() async {
        let h = StoreHarness()
        await h.service.loadInfo()
        XCTAssertEqual(h.service.info?.username, "iostest")
        h.host.username = "graviton"
        XCTAssertNil(h.service.info)
        h.host.username = "iostest"
        XCTAssertNotNil(h.service.info)
    }

    func testInfoIsClearedOnLogoutAndOnLogin() async {
        let h = StoreHarness()
        await h.service.loadInfo()
        h.service.sessionDidChange(loggedIn: false)
        XCTAssertNil(h.service.info)
        await h.service.loadInfo()
        XCTAssertNotNil(h.service.info)
        h.service.sessionDidChange(loggedIn: true)
        XCTAssertNil(h.service.info)
    }

    func testAnswerForAPreviousUserIsDropped() async {
        let h = StoreHarness()
        h.server.onFetch = { h.host.username = "graviton" }
        await h.service.loadInfo()
        XCTAssertNil(h.service.info)
        XCTAssertFalse(h.service.infoFailed)
        h.host.username = "iostest"
        XCTAssertNil(h.service.info, "the answer fetched for iostest was dropped, not stored")
    }

    func testBuyDropsAGetAnsweredAfterAnAccountSwitch() async {
        let h = StoreHarness()
        h.source.purchaseOutcome = .transaction(StoreFixtures.transaction(1))
        h.server.onFetch = { h.host.username = "graviton" }
        await h.service.buy(productID: yearly, scene: nil)
        XCTAssertEqual(h.source.purchasedProducts, [])
        XCTAssertEqual(h.server.posted, [])
    }

    func testFailedGetKeepsEarlierInfoOfTheSameUser() async {
        let h = StoreHarness()
        await h.loadBoth()
        h.server.defaultInfo = .failed
        await h.service.loadInfo()
        XCTAssertNotNil(h.service.info)
        XCTAssertTrue(h.service.infoFailed)
        XCTAssertEqual(h.service.screenModel().status, .ready)
    }

    func testFailedGetWithoutInfoIsCouldNotLoad() async {
        let h = StoreHarness()
        h.server.defaultInfo = .failed
        await h.loadBoth()
        XCTAssertEqual(h.service.screenModel().status, .failed)
    }

    func testOnePostAtATime() async {
        let h = StoreHarness()
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1), StoreFixtures.transaction(2)]
        h.server.holdPosts = true
        let resync = Task { await h.service.performResync(explicit: false) }
        await waitFor { h.server.heldCount == 1 }
        XCTAssertEqual(h.server.posted, ["jws-1"])
        h.server.releasePosts()
        await resync.value
        XCTAssertEqual(h.server.posted, ["jws-1", "jws-2"])
        XCTAssertEqual(h.server.maxConcurrentPosts, 1)
    }

    func testABuyJoinsTheResyncPostingTheSameTransaction() async {
        let h = StoreHarness()
        let transaction = StoreFixtures.transaction(1)
        h.source.unfinishedTransactions = [transaction]
        h.server.holdPosts = true
        let resync = Task { await h.service.performResync(explicit: false) }
        await waitFor { h.server.heldCount == 1 }
        h.source.purchaseOutcome = .transaction(transaction)
        let buy = Task { await h.service.buy(productID: self.yearly, scene: nil) }
        await waitFor { h.source.purchasedProducts.count == 1 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        h.server.releasePosts()
        await resync.value
        await buy.value
        XCTAssertEqual(h.server.posted, ["jws-1"])
        XCTAssertEqual(h.source.finished, [1])
        XCTAssertEqual(h.messages.shown, [.thankYou])
    }

    func testManageSubscriptionsUsesStoreKitThenTheURL() async throws {
        let h = StoreHarness()
        var opened: [URL] = []
        h.service.openURL = { opened.append($0) }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        await h.service.manageSubscriptions(in: scene)
        XCTAssertEqual(h.source.manageCalls, 1)
        XCTAssertEqual(opened, [], "StoreKit showed the sheet")
        h.source.manageResult = false
        await h.service.manageSubscriptions(in: scene)
        XCTAssertEqual(h.source.manageCalls, 2)
        XCTAssertEqual(opened, [StoreService.manageSubscriptionsURL], "fallback after StoreKit failed")
        await h.service.manageSubscriptions(in: nil)
        XCTAssertEqual(h.source.manageCalls, 2, "no scene: straight to the URL")
        XCTAssertEqual(opened.count, 2)
        XCTAssertEqual(StoreService.manageSubscriptionsURL.absoluteString,
                       "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions")
    }
}
