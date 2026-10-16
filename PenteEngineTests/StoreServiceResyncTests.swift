import XCTest
@testable import penteLive

/// Spec 5.1 automatic resync (unfinished only, silent), coalescing, the
/// once-per-account migration sweep, revocations, Transaction.updates, the
/// foreground retry backoff, and the legacy flags cleared once.
@MainActor
final class StoreServiceResyncTests: XCTestCase {
    func testAutomaticResyncPostsOnlyUnfinishedAndIsSilent() async {
        let h = StoreHarness()
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        h.source.entitlements = [StoreFixtures.transaction(9)]
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.server.posted, ["jws-1"])
        XCTAssertEqual(h.source.entitlementReads, 0)
        XCTAssertEqual(h.source.finished, [1])
        XCTAssertEqual(h.messages.shown, [], "the thank-you is only for the explicit buy")
        XCTAssertEqual(h.host.entitlementChanges, 1)
    }

    func testResyncWithoutLoginPostsNothing() async {
        let h = StoreHarness()
        h.host.username = nil
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.source.unfinishedReads, 0)
        XCTAssertEqual(h.server.posted, [])
    }

    func testRequestsDuringARunCoalesceIntoOneFollowUp() async {
        let h = StoreHarness()
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        h.server.holdPosts = true
        let first = Task { await h.service.performResync(explicit: false) }
        await waitFor { h.server.heldCount == 1 }
        await h.service.performResync(explicit: false)
        await h.service.performResync(explicit: false)
        await h.service.performResync(explicit: false)
        h.server.releasePosts()
        await first.value
        XCTAssertEqual(h.source.unfinishedReads, 2, "one run, then exactly one follow-up run")
        XCTAssertEqual(h.server.posted, ["jws-1"])
    }

    func testMigrationSweepRunsOncePerAccountAfterLogin() async {
        let h = StoreHarness()
        h.source.entitlements = [StoreFixtures.transaction(9)]
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.server.posted.count == 1 }
        await waitFor { h.defaults.stringArray(forKey: StoreService.migratedAccountsKey) == ["iostest"] }
        XCTAssertEqual(h.server.posted, ["jws-9"])
        h.service.sessionDidChange(loggedIn: false)
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.source.unfinishedReads == 2 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(h.source.entitlementReads, 1)
        XCTAssertEqual(h.server.posted, ["jws-9"])
    }

    func testSweepIsNotRememberedWithoutASuccess() async {
        let h = StoreHarness()
        h.server.defaultReply = .invalidReceipt
        h.source.entitlements = [StoreFixtures.transaction(9)]
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.server.posted.count == 1 }
        await waitFor { h.source.finished == [9] }
        h.service.sessionDidChange(loggedIn: false)
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.server.posted.count == 2 }
        XCTAssertEqual(h.source.entitlementReads, 2)
    }

    func testSweepIsPerAccount() async {
        let h = StoreHarness()
        h.source.entitlements = [StoreFixtures.transaction(9)]
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.defaults.stringArray(forKey: StoreService.migratedAccountsKey) == ["iostest"] }
        h.service.sessionDidChange(loggedIn: false)
        h.host.username = "graviton"
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.source.entitlementReads == 2 }
        await waitFor { h.server.posted.count == 2 }
    }

    func testSweepIsRetriedAfterAnOutage() async {
        let h = StoreHarness()
        h.server.defaultReply = .noReply
        h.source.entitlements = [StoreFixtures.transaction(9)]
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.clock.scheduled == [30] }
        h.clock.fireAll()
        await waitFor { h.server.posted.count == 2 }
        XCTAssertEqual(h.server.posted, ["jws-9", "jws-9"])
        XCTAssertEqual(h.source.entitlementReads, 2)
    }

    func testOnlyThePostLoginResyncSweeps() async {
        let h = StoreHarness()
        h.server.defaultReply = .invalidReceipt
        h.source.entitlements = [StoreFixtures.transaction(9)]
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.source.finished == [9] }
        try? await Task.sleep(nanoseconds: 50_000_000)
        await h.service.performResync(explicit: false)
        await waitFor { h.source.unfinishedReads == 2 }
        XCTAssertEqual(h.source.entitlementReads, 1)
        XCTAssertEqual(h.server.posted, ["jws-9"])
    }

    func testAnEntitlementThatIsAlsoUnfinishedIsPostedOnce() async {
        let h = StoreHarness()
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        h.source.entitlements = [StoreFixtures.transaction(1)]
        h.service.sessionDidChange(loggedIn: true)
        await waitFor { h.source.finished == [1] }
        XCTAssertEqual(h.server.posted, ["jws-1"])
    }

    func testRevocationIsPostedFinishedAndRefreshesTheDashboard() async {
        let h = StoreHarness()
        h.server.defaultReply = .invalidReceipt
        h.source.unfinishedTransactions = [StoreFixtures.transaction(5, revoked: true)]
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.server.posted, ["jws-5"])
        XCTAssertEqual(h.source.finished, [5])
        XCTAssertEqual(h.host.entitlementChanges, 1)
        XCTAssertEqual(h.messages.shown, [])
    }

    func testTransactionUpdatesTriggerAResync() async {
        let h = StoreHarness()
        h.service.start()
        h.source.unfinishedTransactions = [StoreFixtures.transaction(3, product: "month_pass")]
        h.source.listener?()
        await waitFor { h.server.posted == ["jws-3"] }
    }

    func testStartClearsTheLegacyReceiptFlagsOnce() {
        let h = StoreHarness()
        h.defaults.set(true, forKey: "shouldSendReceipt")
        h.defaults.set(true, forKey: "shouldRefreshReceipt")
        h.service.start()
        XCTAssertNil(h.defaults.object(forKey: "shouldSendReceipt"))
        XCTAssertNil(h.defaults.object(forKey: "shouldRefreshReceipt"))
        XCTAssertTrue(h.defaults.bool(forKey: StoreService.legacyFlagsClearedKey))
        h.defaults.set(true, forKey: "shouldSendReceipt")
        StoreService.clearLegacyReceiptFlags(in: h.defaults)
        XCTAssertTrue(h.defaults.bool(forKey: "shouldSendReceipt"), "cleared once, on the first launch only")
    }

    func testForegroundRetryBackoff() async {
        let h = StoreHarness()
        h.server.defaultReply = .retryLater
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.clock.scheduled, [30])
        h.clock.fireAll()
        await waitFor { h.clock.scheduled == [30, 120] }
        h.clock.fireAll()
        await waitFor { h.clock.scheduled == [30, 120, 600] }
        h.clock.fireAll()
        await waitFor { h.server.posted.count == 4 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(h.clock.scheduled, [30, 120, 600], "later triggers take over after 10 min")
        XCTAssertEqual(h.source.finished, [])
    }

    func testNetworkErrorsAndUnknownRepliesAreRetriedToo() async {
        let h = StoreHarness()
        h.server.defaultReply = .noReply
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.clock.scheduled, [30])
    }

    func testARetryDueInTheBackgroundWaitsForTheForeground() async {
        let h = StoreHarness()
        h.server.defaultReply = .noReply
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        await h.service.performResync(explicit: false)
        h.host.isInForeground = false
        h.clock.fireAll()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(h.server.posted.count, 1)
        h.host.isInForeground = true
        await h.service.performResync(explicit: false) // the foreground trigger
        XCTAssertEqual(h.server.posted.count, 2)
        XCTAssertEqual(h.clock.scheduled, [30, 120])
    }

    func testASuccessfulRunResetsTheBackoff() async {
        let h = StoreHarness()
        h.server.replies = [.noReply]
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        await h.service.performResync(explicit: false)
        h.clock.fireAll()
        await waitFor { h.source.finished == [1] }
        try? await Task.sleep(nanoseconds: 50_000_000)
        h.server.defaultReply = .noReply
        h.source.unfinishedTransactions = [StoreFixtures.transaction(2)]
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.clock.scheduled, [30, 30])
    }

    func testRepeated401sReLogInOnceThenBackOff() async {
        let h = StoreHarness()
        h.server.defaultReply = .sessionLost
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.host.sessionLostCount, 1)
        XCTAssertEqual(h.clock.scheduled, [])
        h.host.username = "iostest" // the app logged in again; the server still answers 401
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.host.sessionLostCount, 1, "no second re-login within 5 min")
        XCTAssertEqual(h.clock.scheduled, [30], "backed off as for no reply")
        XCTAssertEqual(h.source.finished, [])
        h.clock.current = h.clock.current.addingTimeInterval(StoreService.sessionLostQuietPeriod)
        await h.service.performResync(explicit: false)
        XCTAssertEqual(h.host.sessionLostCount, 2, "after 5 min a 401 logs in again")
    }
}
