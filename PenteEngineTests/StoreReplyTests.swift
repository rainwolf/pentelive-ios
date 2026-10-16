import XCTest
@testable import penteLive

/// Spec 5.3: reply parsing, finish rules and the message table.
final class StoreReplyTests: XCTestCase {
    private func reply(_ body: String, status: Int? = 200) -> StoreReply {
        StoreReply.parse(statusCode: status, body: body.data(using: .utf8))
    }

    func testEveryServerStringWithTheServletsNewline() {
        XCTAssertEqual(reply("success\n"), .success)
        XCTAssertEqual(reply("success:renewal\n"), .renewal)
        XCTAssertEqual(reply("success:known\n"), .known)
        XCTAssertEqual(reply("success:shared\n"), .shared)
        XCTAssertEqual(reply("invalid receipt\n"), .invalidReceipt)
        XCTAssertEqual(reply("inactive\n"), .inactive)
        XCTAssertEqual(reply("retry later\n"), .retryLater)
        XCTAssertEqual(reply("  success \r\n"), .success)
    }

    func testOnlyAnExactMatchCounts() {
        XCTAssertEqual(reply("success:refunded"), .noReply)
        XCTAssertEqual(reply("success:future"), .noReply)
        XCTAssertEqual(reply("Success"), .noReply)
        XCTAssertEqual(reply("<html><body>success</body></html>"), .noReply)
        XCTAssertEqual(reply("<html><form action=\"login.jsp\">success</form></html>"), .noReply)
        XCTAssertEqual(reply("success success"), .noReply)
        XCTAssertEqual(reply(""), .noReply)
    }

    func testOnlyHttp200IsAReply() {
        XCTAssertEqual(reply("success", status: 500), .noReply)
        XCTAssertEqual(reply("success", status: 302), .noReply)
        XCTAssertEqual(reply("success", status: 204), .noReply)
        XCTAssertEqual(reply("success", status: 403), .noReply)
        XCTAssertEqual(StoreReply.parse(statusCode: nil, body: nil), .noReply)
        XCTAssertEqual(StoreReply.parse(statusCode: 200, body: nil), .noReply)
        XCTAssertEqual(StoreReply.parse(statusCode: 200, body: Data([0xff, 0xfe, 0x00])), .noReply)
    }

    func test401IsALostSessionWhateverTheBody() {
        XCTAssertEqual(reply("success", status: 401), .sessionLost)
        XCTAssertEqual(StoreReply.parse(statusCode: 401, body: nil), .sessionLost)
    }

    func testFinishRules() {
        for finished in [StoreReply.success, .renewal, .known, .shared, .invalidReceipt, .inactive] {
            XCTAssertTrue(finished.finishesTransaction, "\(finished)")
        }
        for kept in [StoreReply.retryLater, .noReply, .sessionLost] {
            XCTAssertFalse(kept.finishesTransaction, "\(kept)")
        }
    }

    func testSuccessAndRetryableReplies() {
        XCTAssertEqual([StoreReply.success, .renewal, .known, .shared, .invalidReceipt, .inactive, .retryLater, .noReply, .sessionLost].filter(\.isSuccess),
                       [.success, .renewal, .known, .shared])
        XCTAssertEqual([StoreReply.success, .renewal, .known, .shared, .invalidReceipt, .inactive, .retryLater, .noReply, .sessionLost].filter(\.isRetryable),
                       [.retryLater, .noReply])
    }

    func testMessagesOnTheExplicitBuy() {
        let thanks = "Thank you for your purchase!"
        let saved = "Your purchase is saved and will be registered with pente.org shortly."
        XCTAssertEqual(StoreReply.success.buyMessage.text, thanks)
        XCTAssertEqual(StoreReply.renewal.buyMessage.text, thanks)
        XCTAssertEqual(StoreReply.known.buyMessage.text, thanks)
        XCTAssertEqual(StoreReply.shared.buyMessage.text, "This purchase is linked to another pente.org account.")
        XCTAssertEqual(StoreReply.invalidReceipt.buyMessage.text, "The purchase could not be completed. Please try again later.")
        XCTAssertEqual(StoreReply.inactive.buyMessage.text, "This subscription is no longer active.")
        XCTAssertEqual(StoreReply.retryLater.buyMessage.text, saved)
        XCTAssertEqual(StoreReply.noReply.buyMessage.text, saved)
        XCTAssertEqual(StoreReply.sessionLost.buyMessage.text, saved)
    }

    func testRestoreMessageSelection() {
        func restore(_ replies: [StoreReply], syncFailed: Bool = false) -> String {
            StoreReply.restoreMessage(for: replies, syncFailed: syncFailed).text
        }
        let upToDate = "Your purchases are up to date."
        let shared = "This purchase is linked to another pente.org account."
        let failed = "Restore failed, please try again later."
        let nothing = "No purchases to restore."
        XCTAssertEqual(restore([]), nothing)
        XCTAssertEqual(restore([], syncFailed: true), failed)
        XCTAssertEqual(restore([.known]), upToDate)
        XCTAssertEqual(restore([.success, .invalidReceipt]), upToDate)
        XCTAssertEqual(restore([.renewal, .retryLater]), upToDate)
        XCTAssertEqual(restore([.shared]), shared)
        XCTAssertEqual(restore([.known, .shared]), shared)
        XCTAssertEqual(restore([.retryLater, .noReply]), failed)
        XCTAssertEqual(restore([.invalidReceipt, .retryLater]), failed)
        XCTAssertEqual(restore([.sessionLost]), failed)
        XCTAssertEqual(restore([.invalidReceipt, .inactive]), nothing)
    }

    func testOtherMessageTexts() {
        XCTAssertEqual(StoreMessage.pending.text, "Your purchase is waiting for approval")
        XCTAssertEqual(StoreMessage.couldNotReach.text, "Could not reach pente.org. Check your connection and try again.")
        XCTAssertEqual(StoreMessage.purchaseFailed.text, "The purchase could not be completed. Please try again later.")
    }
}
