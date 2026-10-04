import XCTest
@testable import penteLive

final class ReceiptReplyTests: XCTestCase {
    func testPlainSuccessIsNewPurchase() {
        XCTAssertEqual(ReceiptReply.kind(forReply: "success"), .newPurchase)
        XCTAssertEqual(ReceiptReply.kind(forReply: "success\n"), .newPurchase)
    }

    func testSuccessVariants() {
        XCTAssertEqual(ReceiptReply.kind(forReply: "success:renewal"), .renewal)
        XCTAssertEqual(ReceiptReply.kind(forReply: "success:known"), .known)
        XCTAssertEqual(ReceiptReply.kind(forReply: "success:shared\n"), .shared)
    }

    func testUnknownSuccessVariantIsNotANewPurchase() {
        XCTAssertEqual(ReceiptReply.kind(forReply: "success:future"), .known)
    }

    func testInvalidReceipt() {
        XCTAssertEqual(ReceiptReply.kind(forReply: "invalid receipt"), .invalid)
    }

    func testMissingOrUnknownReplyFails() {
        XCTAssertEqual(ReceiptReply.kind(forReply: nil), .failed)
        XCTAssertEqual(ReceiptReply.kind(forReply: ""), .failed)
        XCTAssertEqual(ReceiptReply.kind(forReply: "<html>502 Bad Gateway</html>"), .failed)
    }
}
