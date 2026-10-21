@testable import penteLive
import XCTest

final class TbViewerRoleTests: XCTestCase {
    func testPlayerOne() {
        let r = TbViewerRole.role(username: "alice", player1: "alice", player2: "bob")
        XCTAssertTrue(r.isPlayer)
        XCTAssertTrue(r.seesAsPlayer1)
        XCTAssertEqual(r.myLabel, "me")
    }

    func testPlayerTwo() {
        let r = TbViewerRole.role(username: "bob", player1: "alice", player2: "bob")
        XCTAssertTrue(r.isPlayer)
        XCTAssertFalse(r.seesAsPlayer1)
        XCTAssertEqual(r.myLabel, "me")
    }

    func testNonPlayerSeesAsPlayerOneWithNames() {
        let r = TbViewerRole.role(username: "parent", player1: "kid", player2: "graviton")
        XCTAssertFalse(r.isPlayer)
        XCTAssertTrue(r.seesAsPlayer1)
        XCTAssertEqual(r.myLabel, "kid")
    }

    func testPlayerMatchIgnoresCase() {
        let r = TbViewerRole.role(username: "bob", player1: "alice", player2: "Bob")
        XCTAssertTrue(r.isPlayer)
        XCTAssertFalse(r.seesAsPlayer1)
    }

    func testBothNamesMatchIsPlayerOne() {
        let r = TbViewerRole.role(username: "x", player1: "X", player2: "x")
        XCTAssertTrue(r.isPlayer)
        XCTAssertTrue(r.seesAsPlayer1)
        XCTAssertEqual(r.myLabel, "me")
    }

    func testNonPlayerLabelKeepsPlayerOneCase() {
        XCTAssertEqual(TbViewerRole.role(username: "parent", player1: "KidTim", player2: "graviton").myLabel, "KidTim")
    }

    func testMissingNamesAreNonPlayer() {
        XCTAssertFalse(TbViewerRole.role(username: nil, player1: "a", player2: "b").isPlayer)
        XCTAssertFalse(TbViewerRole.role(username: "", player1: "a", player2: "b").isPlayer)
        let r = TbViewerRole.role(username: "x", player1: nil, player2: nil)
        XCTAssertFalse(r.isPlayer)
        XCTAssertEqual(r.myLabel, "")
    }

    func testCancelPromptOnlyForTheOtherPlayer() {
        let bob = TbViewerRole.role(username: "bob", player1: "alice", player2: "bob")
        XCTAssertTrue(bob.promptsCancelReply(requester: "alice"))
        XCTAssertFalse(bob.promptsCancelReply(requester: "Bob"))
        XCTAssertTrue(bob.promptsCancelReply(requester: nil))
        let parent = TbViewerRole.role(username: "parent", player1: "alice", player2: "bob")
        XCTAssertFalse(parent.promptsCancelReply(requester: "alice"))
        XCTAssertFalse(parent.promptsCancelReply(requester: nil))
    }
}
