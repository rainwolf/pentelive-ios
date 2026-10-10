@testable import penteLive
import XCTest

final class ArenaWireTests: XCTestCase {
    /// Decodes a frame the way PenteLiveSocket.convertJSONStringToDictionary does.
    private func frame(_ json: String) -> [String: Any] {
        let object = try! JSONSerialization.jsonObject(with: Data(json.utf8), options: [])
        return object as! [String: Any]
    }

    private func ended(_ reason: ArenaRequestEnded.Reason, table: Int = 7) -> ArenaRequestEnded {
        return ArenaRequestEnded(table: table, player: "bob", owner: "alice", reason: reason)
    }

    // MARK: dsgArenaJoinRequestsEvent

    func testJoinRequestsSnapshotIsSortedBySeq() {
        let event = frame(#"{"dsgArenaJoinRequestsEvent":{"table":4,"requests":[{"player":"carol","seq":9},{"player":"bob","seq":3}]}}"#)
        XCTAssertEqual(ArenaInbound(event: event),
                       .joinRequests(table: 4, requests: [ArenaJoinRequest(player: "bob", seq: 3),
                                                          ArenaJoinRequest(player: "carol", seq: 9)]))
    }

    func testJoinRequestsKeepsOneRowPerPlayer() {
        let event = frame(#"{"dsgArenaJoinRequestsEvent":{"table":4,"requests":[{"player":"bob","seq":5},{"player":"amy","seq":4},{"player":"bob","seq":2}]}}"#)
        XCTAssertEqual(ArenaInbound(event: event),
                       .joinRequests(table: 4, requests: [ArenaJoinRequest(player: "bob", seq: 2),
                                                          ArenaJoinRequest(player: "amy", seq: 4)]))
    }

    func testJoinRequestsSkipsMalformedEntries() {
        let event = frame(#"{"dsgArenaJoinRequestsEvent":{"table":4,"requests":[{"player":"bob"},{"seq":4},{"player":null,"seq":5},{"player":"dan","seq":"6"},3,{"player":"eve","seq":8}]}}"#)
        XCTAssertEqual(ArenaInbound(event: event),
                       .joinRequests(table: 4, requests: [ArenaJoinRequest(player: "eve", seq: 8)]))
    }

    func testMissingRequestsIsEmptySnapshot() {
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaJoinRequestsEvent":{"table":4,"requests":[]}}"#)),
                       .joinRequests(table: 4, requests: []))
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaJoinRequestsEvent":{"table":4}}"#)),
                       .joinRequests(table: 4, requests: []))
    }

    func testJoinRequestsWithoutIntegerTableIsIgnored() {
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaJoinRequestsEvent":{"requests":[]}}"#)))
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaJoinRequestsEvent":{"table":"4","requests":[]}}"#)))
    }

    // MARK: dsgArenaMyRequestsEvent

    func testMyRequests() {
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaMyRequestsEvent":{"tables":[2,5]}}"#)),
                       .myRequests(tables: [2, 5]))
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaMyRequestsEvent":{}}"#)),
                       .myRequests(tables: []))
    }

    func testMyRequestsSkipsNonIntegers() {
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaMyRequestsEvent":{"tables":[2,"x",null,5]}}"#)),
                       .myRequests(tables: [2, 5]))
    }

    // MARK: dsgArenaRequestEndedEvent

    func testRequestEndedDecodesEveryReason() {
        for reason in ArenaRequestEnded.Reason.allCases {
            let event = frame("{\"dsgArenaRequestEndedEvent\":{\"table\":7,\"player\":\"bob\",\"owner\":\"alice\",\"reason\":\"\(reason.rawValue)\"}}")
            XCTAssertEqual(ArenaInbound(event: event), .requestEnded(ended(reason)), reason.rawValue)
        }
    }

    func testRequestEndedWithUnknownReasonOrNoTableIsIgnored() {
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaRequestEndedEvent":{"table":7,"player":"bob","owner":"alice","reason":"EXPIRED"}}"#)))
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaRequestEndedEvent":{"player":"bob","owner":"alice","reason":"DECLINED"}}"#)))
    }

    func testRequestEndedToleratesMissingNames() {
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaRequestEndedEvent":{"table":7,"reason":"TABLE_CLOSED"}}"#)),
                       .requestEnded(ArenaRequestEnded(table: 7, player: "", owner: "", reason: .tableClosed)))
    }

    // MARK: not arena events

    func testOtherEventsAreNotArenaEvents() {
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgJoinTableEvent":{"table":4,"player":"bob"}}"#)))
        // No longer sent by the server, so no longer handled.
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaRequestJoinTableEvent":{"table":4,"player":"bob"}}"#)))
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaRejectTableJoinEvent":{"table":4,"playerToReject":"bob"}}"#)))
    }

    // MARK: notices (spec C4)

    func testNoticeTexts() {
        XCTAssertEqual(ended(.declined).noticeText, "alice declined your request")
        XCTAssertEqual(ended(.tableFull).noticeText, "Table 7 is no longer available")
        XCTAssertEqual(ended(.tableClosed).noticeText, "Table 7 was closed")
        XCTAssertEqual(ended(.duplicate).noticeText, "You already sent a request to alice")
        XCTAssertEqual(ended(.booted).noticeText, "alice removed you from table 7, try again in a few minutes")
        XCTAssertEqual(ended(.blocked).noticeText, "You can't request table 7 again until its next game")
        XCTAssertEqual(ended(.notAvailable).noticeText, "You can't join table 7 right now")
        XCTAssertEqual(ended(.guestRated).noticeText, "Guests can't join rated tables")
        XCTAssertEqual(ended(.noLongerAvailable).noticeText, "bob is no longer available")
    }

    func testOwnerNamedInNoticesComesFromTheEvent() {
        let notice = { (reason: String) -> String? in
            guard case let .requestEnded(ended)? = ArenaInbound(event: self.frame("{\"dsgArenaRequestEndedEvent\":{\"table\":7,\"player\":\"bob\",\"owner\":\"olga\",\"reason\":\"\(reason)\"}}")) else { return nil }
            return ended.noticeText
        }
        XCTAssertEqual(notice("DUPLICATE"), "You already sent a request to olga")
        XCTAssertEqual(notice("BOOTED"), "olga removed you from table 7, try again in a few minutes")
    }

    func testWithdrawConfirmText() {
        XCTAssertEqual(ArenaText.withdrawConfirm(table: 12),
                       "Withdraw your request to table 12? You won't be able to request it again until its next game.")
    }

    // MARK: outbound (spec Wire protocol, C→S)

    func testOutboundEvents() {
        XCTAssertEqual(ArenaOutbound.requestJoin(table: 3) as NSDictionary,
                       ["dsgArenaRequestJoinTableEvent": ["table": 3, "time": 0]] as NSDictionary)
        XCTAssertEqual(ArenaOutbound.withdraw(table: 3) as NSDictionary,
                       ["dsgArenaWithdrawJoinRequestEvent": ["table": 3, "time": 0]] as NSDictionary)
        XCTAssertEqual(ArenaOutbound.accept(table: 3, player: "bob") as NSDictionary,
                       ["dsgArenaAcceptTableJoinEvent": ["table": 3, "playerToAccept": "bob", "time": 0] as [String: Any]] as NSDictionary)
        XCTAssertEqual(ArenaOutbound.reject(table: 3, player: "bob") as NSDictionary,
                       ["dsgArenaRejectTableJoinEvent": ["table": 3, "playerToReject": "bob", "time": 0] as [String: Any]] as NSDictionary)
        for event in [ArenaOutbound.requestJoin(table: 3), ArenaOutbound.withdraw(table: 3),
                      ArenaOutbound.accept(table: 3, player: "bob"), ArenaOutbound.reject(table: 3, player: "bob")]
        {
            XCTAssertTrue(JSONSerialization.isValidJSONObject(event))
        }
    }

    func testDeclineUsesLowercaseKey() {
        // The capital "DSGArenaRejectTableJoinEvent" key decoded to null on the server and disconnected the owner.
        XCTAssertEqual(Array(ArenaOutbound.reject(table: 3, player: "bob").keys), ["dsgArenaRejectTableJoinEvent"])
    }
}
