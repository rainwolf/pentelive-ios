import XCTest
@testable import penteLive

final class MessageAuthorLabelTests: XCTestCase {
    func testMySeatIsMe() {
        XCTAssertEqual(MessageAuthorLabel.display(forSeat: "1", iAmP1: true, opponentName: "bob", text: "hi"), " me: hi")
        XCTAssertTrue(MessageAuthorLabel.isMine(forSeat: "1", iAmP1: true))
    }

    func testOpponentSeatIsOpponentName() {
        XCTAssertEqual(MessageAuthorLabel.display(forSeat: "1", iAmP1: false, opponentName: "alice", text: "hi"), " alice: hi")
        XCTAssertFalse(MessageAuthorLabel.isMine(forSeat: "1", iAmP1: false))
    }

    func testNamedTextHasNoLabel() {
        XCTAssertEqual(MessageAuthorLabel.display(forSeat: "0", iAmP1: true, opponentName: "bob", text: "alice: a\nbob: b"), " alice: a\nbob: b")
        XCTAssertFalse(MessageAuthorLabel.isMine(forSeat: "0", iAmP1: true))
    }

    func testUnknownSeatReturnsNil() {
        XCTAssertNil(MessageAuthorLabel.display(forSeat: nil, iAmP1: true, opponentName: "bob", text: "hi"))
        XCTAssertNil(MessageAuthorLabel.display(forSeat: "", iAmP1: true, opponentName: "bob", text: "hi"))
        XCTAssertNil(MessageAuthorLabel.display(forSeat: "x", iAmP1: true, opponentName: "bob", text: "hi"))
    }

    func testSeatTwoIsMeForPlayerTwo() {
        XCTAssertEqual(MessageAuthorLabel.display(forSeat: "2", iAmP1: false, opponentName: "alice", text: "hi"), " me: hi")
        XCTAssertTrue(MessageAuthorLabel.isMine(forSeat: "2", iAmP1: false))
        XCTAssertEqual(MessageAuthorLabel.display(forSeat: "2", iAmP1: true, opponentName: "bob", text: "hi"), " bob: hi")
        XCTAssertFalse(MessageAuthorLabel.isMine(forSeat: "2", iAmP1: true))
    }
}
