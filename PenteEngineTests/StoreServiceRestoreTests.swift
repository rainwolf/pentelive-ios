import XCTest
@testable import penteLive

/// Spec 5.1 restore(): AppStore.sync(), then unfinished plus current
/// entitlements posted explicitly, one message.
@MainActor
final class StoreServiceRestoreTests: XCTestCase {
    func testNothingToSend() async {
        let h = StoreHarness()
        await h.service.restore()
        XCTAssertEqual(h.source.syncCalls, 1)
        XCTAssertEqual(h.messages.shown, [.noPurchasesToRestore])
    }

    func testPostsUnfinishedAndEntitlementsAndSaysUpToDate() async {
        let h = StoreHarness()
        h.server.defaultReply = .known
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1, product: "vacation_10")]
        h.source.entitlements = [StoreFixtures.transaction(2)]
        await h.service.restore()
        XCTAssertEqual(h.server.posted, ["jws-1", "jws-2"])
        XCTAssertEqual(h.messages.shown, [.upToDate])
        XCTAssertEqual(h.source.finished, [1, 2])
        XCTAssertEqual(h.host.entitlementChanges, 1)
        XCTAssertEqual(h.defaults.stringArray(forKey: StoreService.migratedAccountsKey), ["iostest"])
    }

    func testSharedSaysLinkedToAnotherAccount() async {
        let h = StoreHarness()
        h.server.defaultReply = .shared
        h.source.entitlements = [StoreFixtures.transaction(2)]
        await h.service.restore()
        XCTAssertEqual(h.messages.shown, [.shared])
    }

    func testEverySendFailed() async {
        let h = StoreHarness()
        h.server.replies = [.retryLater, .noReply]
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        h.source.entitlements = [StoreFixtures.transaction(2)]
        await h.service.restore()
        XCTAssertEqual(h.messages.shown, [.restoreFailed])
        XCTAssertEqual(h.source.finished, [])
    }

    func testOnlyInvalidOrInactiveRestoresNothing() async {
        let h = StoreHarness()
        h.server.replies = [.invalidReceipt, .inactive]
        h.source.unfinishedTransactions = [StoreFixtures.transaction(1)]
        h.source.entitlements = [StoreFixtures.transaction(2)]
        await h.service.restore()
        XCTAssertEqual(h.messages.shown, [.noPurchasesToRestore])
        XCTAssertEqual(h.source.finished, [1, 2])
    }

    func testCancelledAppleIdPromptIsSilent() async {
        let h = StoreHarness()
        h.source.syncError = .cancelled
        h.source.entitlements = [StoreFixtures.transaction(2)]
        await h.service.restore()
        XCTAssertEqual(h.messages.shown, [])
        XCTAssertEqual(h.server.posted, [])
    }

    func testAFailedSyncStillPostsWhatIsThere() async {
        let h = StoreHarness()
        h.source.syncError = .failed
        h.source.entitlements = [StoreFixtures.transaction(2)]
        await h.service.restore()
        XCTAssertEqual(h.server.posted, ["jws-2"])
        XCTAssertEqual(h.messages.shown, [.upToDate])
    }

    func testAFailedSyncWithNothingToSendIsAFailure() async {
        let h = StoreHarness()
        h.source.syncError = .failed
        await h.service.restore()
        XCTAssertEqual(h.messages.shown, [.restoreFailed])
    }

    func testNotLoggedInRestoresNothing() async {
        let h = StoreHarness()
        h.host.username = nil
        await h.service.restore()
        XCTAssertEqual(h.source.syncCalls, 0)
        XCTAssertEqual(h.messages.shown, [])
    }
}
