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
        XCTAssertEqual(p(.settings(kidPid: 5, copyMessages: nil, copyLiveChat: nil, copyTbMessages: true)),
                       ["action=settings", "kidPid=5", "copyTbMessages=Y"])
        XCTAssertEqual(p(.settings(kidPid: 5, copyMessages: true, copyLiveChat: false, copyTbMessages: false)),
                       ["action=settings", "kidPid=5", "copyMessages=Y", "copyLiveChat=N", "copyTbMessages=N"])
        XCTAssertEqual(p(.release(kidPid: 5)), ["action=release", "kidPid=5"])
    }

    func testParseCopyTbMessages() {
        func tb(_ field: String) -> Bool?? {
            let s = parse(#"{"success":true,"isKid":false,"emailVerified":true,"kids":[{"kidPid":1,"name":"k"\#(field)}]}"#)
            return s?.kids.first.map { $0.copyTbMessages }
        }
        XCTAssertEqual(tb(#","copyTbMessages":true"#), .some(true))
        XCTAssertEqual(tb(#","copyTbMessages":false"#), .some(false))
        XCTAssertEqual(tb(""), .some(nil))
    }

    private let gamesExample = #"{"success":true,"kidPid":1,"games":[{"gid":50000000001234,"game":51,"gameName":"Pente","opponentPid":23000000000777,"opponentName":"graviton","kidsTurn":true,"lastMoveDate":1760882580000,"privateGame":true}]}"#

    func testParseActiveGames() {
        XCTAssertEqual(KidAccounts.parseActiveGames(Data(gamesExample.utf8)),
                       [KidActiveGame(gid: 50_000_000_001_234, game: 51, gameName: "Pente", opponentPid: 23_000_000_000_777,
                                      opponentName: "graviton", kidsTurn: true, lastMoveDate: 1_760_882_580_000, privateGame: true)])
        XCTAssertEqual(KidAccounts.parseActiveGames(Data(#"{"success":true,"kidPid":1,"games":[]}"#.utf8)), [])
    }

    func testParseActiveGamesSkipsMalformedAndDefaultsOptionals() {
        let json = #"{"success":true,"games":[{"gid":1,"gameName":"Pente","opponentName":"a"},{"gameName":"no gid"},{"gid":2,"gameName":"Gomoku","opponentName":"b","kidsTurn":true}]}"#
        let games = KidAccounts.parseActiveGames(Data(json.utf8))
        XCTAssertEqual(games?.map { $0.gid }, [1, 2])
        XCTAssertEqual(games?.first, KidActiveGame(gid: 1, game: 0, gameName: "Pente", opponentPid: 0, opponentName: "a",
                                                   kidsTurn: false, lastMoveDate: 0, privateGame: false))
    }

    func testParseActiveGamesSkipsUnknownGame() {
        let json = #"{"success":true,"games":[{"gid":1,"game":83,"gameName":"NewGame","opponentName":"a"},{"gid":2,"game":51,"gameName":"Pente","opponentName":"b"}]}"#
        XCTAssertEqual(KidAccounts.parseActiveGames(Data(json.utf8))?.map { $0.gid }, [2])
    }

    func testParseActiveGamesKeepsTurnBasedNames() {
        let json = #"{"success":true,"games":[{"gid":1,"game":51,"gameName":"Turn-based Pente","opponentName":"a"},{"gid":2,"game":83,"gameName":"Turn-based NewGame","opponentName":"b"},{"gid":3,"gameName":"Turn-based Go (9x9)","opponentName":"c"}]}"#
        XCTAssertEqual(KidAccounts.parseActiveGames(Data(json.utf8))?.map { $0.gid }, [1, 3])
    }

    func testParseActiveGamesFailures() {
        XCTAssertNil(KidAccounts.parseActiveGames(nil))
        XCTAssertNil(KidAccounts.parseActiveGames(Data("<html>login</html>".utf8)))
        let notFound = Data(#"{"success":false,"error":"Kid not found"}"#.utf8)
        XCTAssertNil(KidAccounts.parseActiveGames(notFound))
        XCTAssertNil(KidAccounts.parseActiveGames(Data(#"{"success":false}"#.utf8)))
        XCTAssertEqual(KidAccounts.parseError(notFound), "Kid not found")
        // An old server ignores `action` and returns the plain GET view.
        XCTAssertEqual(KidAccounts.parseActiveGames(Data(#"{"success":true,"isKid":false,"emailVerified":true,"kids":[]}"#.utf8)), [])
    }

    private func game(kidsTurn: Bool, lastMoveDate: Int64 = 1_760_882_580_000) -> KidActiveGame {
        KidActiveGame(gid: 1, game: 51, gameName: "Pente", opponentPid: 7, opponentName: "graviton",
                      kidsTurn: kidsTurn, lastMoveDate: lastMoveDate, privateGame: false)
    }

    func testRowTexts() {
        XCTAssertEqual(game(kidsTurn: true).title, "Pente vs graviton")
        XCTAssertEqual(game(kidsTurn: true).subtitle(kidName: "tim", formatDate: { _ in "D" }), "tim's turn, last move D")
        XCTAssertEqual(game(kidsTurn: false).subtitle(kidName: "tim", formatDate: { _ in "D" }), "graviton's turn, last move D")
    }

    func testSubtitleOmitsUnknownLastMove() {
        var called = false
        let s = game(kidsTurn: true, lastMoveDate: 0).subtitle(kidName: "tim", formatDate: { _ in called = true; return "D" })
        XCTAssertEqual(s, "tim's turn")
        XCTAssertFalse(called)
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
