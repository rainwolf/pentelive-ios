@testable import penteLive
import XCTest

final class KidAccountsTests: XCTestCase {
    private func parse(_ json: String) -> KidAccountsState? {
        KidAccounts.parse(Data(json.utf8))
    }

    func testParseParentView() {
        let s = parse(#"{"success":true,"isKid":false,"emailVerified":true,"kids":[{"kidPid":23000000012345,"name":"kid_one","copyMessages":true,"copyLiveChat":false,"whitelist":[{"pid":777,"name":"graviton","nameColor":16711680,"tourneyWinner":2}]}]}"#)
        XCTAssertEqual(s?.isKid, false)
        XCTAssertEqual(s?.emailVerified, true)
        XCTAssertEqual(s?.kids, [KidAccount(kidPid: 23_000_000_012_345, name: "kid_one", copyMessages: true, copyLiveChat: false,
                                            whitelist: [KidPlayer(pid: 777, name: "graviton", nameColor: 16_711_680, tourneyWinner: 2)])])
        XCTAssertNil(s?.parentName)
        XCTAssertNil(s?.message)
    }

    func testParseKidView() {
        let s = parse(#"{"success":true,"isKid":true,"emailVerified":true,"parentName":"iostest","whitelist":[{"pid":777,"name":"graviton","nameColor":0,"tourneyWinner":0}],"kids":[]}"#)
        XCTAssertEqual(s?.isKid, true)
        XCTAssertEqual(s?.parentName, "iostest")
        XCTAssertEqual(s?.whitelist, [KidPlayer(pid: 777, name: "graviton")])
        XCTAssertEqual(s?.kids, [])
    }

    func testParseConvertMessage() {
        XCTAssertEqual(parse(#"{"success":true,"isKid":false,"emailVerified":true,"kids":[],"message":"Confirmation email sent to bob"}"#)?.message,
                       "Confirmation email sent to bob")
    }

    func testParseHtmlLoginPageIsNil() {
        XCTAssertNil(KidAccounts.parse(Data("<html>login</html>".utf8)))
        XCTAssertNil(KidAccounts.parse(nil))
        XCTAssertNil(KidAccounts.parseError(Data("<html>login</html>".utf8)))
    }

    func testParseFailureIsNilAndErrorIsRead() {
        let data = Data(#"{"success":false,"error":"Kid not found"}"#.utf8)
        XCTAssertNil(KidAccounts.parse(data))
        XCTAssertEqual(KidAccounts.parseError(data), "Kid not found")
        // 401 body when no credentials reached the server.
        XCTAssertEqual(KidAccounts.parseError(Data(#"{"success":false,"error":"Login required"}"#.utf8)), "Login required")
    }

    func testParseSkipsMalformedEntries() {
        let s = parse(#"{"success":true,"isKid":false,"emailVerified":true,"kids":[{"name":"no_pid"},{"kidPid":5,"name":"ok","whitelist":[{"name":"no_pid"},{"pid":9,"name":"amy"}]}]}"#)
        XCTAssertEqual(s?.kids, [KidAccount(kidPid: 5, name: "ok", copyMessages: false, copyLiveChat: false,
                                            whitelist: [KidPlayer(pid: 9, name: "amy")])])
    }

    func testParseMissingListsAreEmpty() {
        let s = parse(#"{"success":true}"#)
        XCTAssertEqual(s, KidAccountsState(isKid: false, emailVerified: false, parentName: nil, whitelist: [], kids: [], message: nil))
    }

    func testActionParams() {
        func p(_ a: KidAction) -> [String] {
            a.params.map { "\($0.0)=\($0.1)" }
        }
        XCTAssertEqual(p(.create(name: "kid", password: "pw123")), ["action=create", "kidName=kid", "kidPassword=pw123"])
        XCTAssertEqual(p(.convert(name: "bob")), ["action=convert", "kidName=bob"])
        XCTAssertEqual(p(.password(kidPid: 5, password: "pw123")), ["action=password", "kidPid=5", "kidPassword=pw123"])
        XCTAssertEqual(p(.whitelistAdd(kidPid: 5, playerName: "graviton")), ["action=whitelistAdd", "kidPid=5", "playerName=graviton"])
        XCTAssertEqual(p(.whitelistRemove(kidPid: 5, playerPid: 777)), ["action=whitelistRemove", "kidPid=5", "playerPid=777"])
        XCTAssertEqual(p(.settings(kidPid: 5, copyMessages: true, copyLiveChat: nil)), ["action=settings", "kidPid=5", "copyMessages=Y"])
        XCTAssertEqual(p(.settings(kidPid: 5, copyMessages: nil, copyLiveChat: false)), ["action=settings", "kidPid=5", "copyLiveChat=N"])
        XCTAssertEqual(p(.release(kidPid: 5)), ["action=release", "kidPid=5"])
    }

    func testKidLookup() {
        let k = KidAccount(kidPid: 5, name: "ok", copyMessages: false, copyLiveChat: false, whitelist: [])
        let s = KidAccountsState(isKid: false, emailVerified: true, parentName: nil, whitelist: [], kids: [k], message: nil)
        XCTAssertEqual(KidAccounts.kid(5, in: s), k)
        XCTAssertNil(KidAccounts.kid(6, in: s))
    }

    func testAllowedRecipientsIncludesParentAndDedupes() {
        let s = KidAccountsState(isKid: true, emailVerified: true, parentName: "iostest",
                                 whitelist: [KidPlayer(pid: 1, name: "Zed"), KidPlayer(pid: 2, name: "amy"), KidPlayer(pid: 3, name: "IOSTEST")],
                                 kids: [], message: nil)
        XCTAssertEqual(KidAccounts.allowedRecipients(s), ["amy", "IOSTEST", "Zed"])
    }

    func testAllowedRecipientsEmptyForNonKid() {
        let s = KidAccountsState(isKid: false, emailVerified: true, parentName: nil, whitelist: [], kids: [], message: nil)
        XCTAssertEqual(KidAccounts.allowedRecipients(s), [])
    }
}
