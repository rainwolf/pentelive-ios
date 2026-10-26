import XCTest
import UIKit
@testable import penteLive

final class DashboardMappingTests: XCTestCase {
    private func loadDashboard() throws -> Dashboard {
        let url = Bundle(for: type(of: self)).url(forResource: "dashboard_sample", withExtension: "json")
        let wire = try JSONDecoder().decode(WireDashboard.self, from: try Data(contentsOf: XCTUnwrap(url)))
        return DashboardMapping.map(wire)
    }

    func testFlags() throws {
        let f = try loadDashboard().flags
        XCTAssertEqual(f.myColorRGB, 1122867)
        XCTAssertEqual(f.playerName, "alice")
        XCTAssertTrue(f.showAds)
        XCTAssertFalse(f.subscriber)
        XCTAssertTrue(f.dbAccess)
        XCTAssertTrue(f.emailMe)
        XCTAssertEqual(f.livePlayers, "5")
        XCTAssertEqual(f.onlineFollowing, "3")
        XCTAssertEqual(f.tbHills, 1)
        XCTAssertEqual(f.tbRatings, 1)
    }

    func testActiveGameMapping() throws {
        let g = try XCTUnwrap(loadDashboard().activeGames.first)
        XCTAssertEqual(g.gameID, "5001")
        XCTAssertEqual(g.gameType, "Pente")
        XCTAssertEqual(g.opponentName, "dave")
        XCTAssertEqual(g.opponentRating, "1480")
        XCTAssertEqual(g.myColor, "white")
        XCTAssertEqual(g.remainingTime, "2 days")
        XCTAssertEqual(g.ratedNot, "rated")
        XCTAssertEqual(g.crown, 0)
        let ng = try XCTUnwrap(loadDashboard().nonActiveGames.first)
        XCTAssertEqual(ng.gameID, "5002")
        XCTAssertEqual(ng.myColor, "black")
        XCTAssertEqual(ng.opponentName, "erin")
    }

    func testReceivedInvitationUsesRawColorAndDaysPerMove() throws {
        let g = try XCTUnwrap(loadDashboard().invitations.first)
        XCTAssertEqual(g.gameID, "9002")
        XCTAssertEqual(g.myColor, "black")
        XCTAssertEqual(g.remainingTime, "7 days per move")
        XCTAssertEqual(g.crown, 1)
    }

    func testOpenInvitationUsesInviterFields() throws {
        let g = try XCTUnwrap(loadDashboard().publicInvitations.first)
        XCTAssertEqual(g.gameID, "7001")
        XCTAssertEqual(g.opponentName, "frank")
        XCTAssertEqual(g.opponentRating, "1300")
        XCTAssertEqual(g.remainingTime, "2 days per move")
        XCTAssertEqual(g.crown, 2)
    }

    func testMessageReadUnread() throws {
        let msgs = try loadDashboard().messages
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs[0].messageID, "3001")
        XCTAssertEqual(msgs[0].unread, "unread")
        XCTAssertEqual(msgs[0].author, "grace")
        XCTAssertEqual(msgs[1].unread, "read")
    }

    func testHillNamingAndFlags() throws {
        let hills = try loadDashboard().hills
        XCTAssertEqual(hills.count, 3)
        XCTAssertTrue(hills[1].game.hasPrefix("Speed "))
        XCTAssertTrue(hills[2].game.hasPrefix("tb-"))
        XCTAssertTrue(hills[0].member)
        XCTAssertTrue(hills[2].king)
        XCTAssertEqual(hills[0].numPlayers, "4")
    }

    func testRatingStatNaming() throws {
        let rs = try loadDashboard().ratingStats
        XCTAssertEqual(rs.count, 2)
        XCTAssertEqual(rs[0].rating, "1500")
        XCTAssertEqual(rs[0].totalGames, "42")
        XCTAssertEqual(rs[0].crown, 1)
        XCTAssertTrue(rs[1].game.hasPrefix("tb-"))
    }

    func testTournamentMapping() throws {
        let t = try XCTUnwrap(loadDashboard().tournaments.first)
        XCTAssertEqual(t.name, "Spring Open")
        XCTAssertEqual(t.tournamentID, "4001")
        XCTAssertEqual(t.round, "5")
        XCTAssertEqual(t.tournamentState, "2")
        XCTAssertEqual(t.date, "2024-03-01")
    }

    func testSentInvitationMapping() throws {
        let g = try XCTUnwrap(loadDashboard().sentInvitations.first)
        XCTAssertEqual(g.gameID, "9001")
        XCTAssertEqual(g.gameType, "Pente")
        XCTAssertEqual(g.opponentName, "bob")
        XCTAssertEqual(g.opponentRating, "1400")
        XCTAssertEqual(g.myColor, "white")            // raw color, no parseStoneColor
        XCTAssertEqual(g.remainingTime, "3 days per move")
        XCTAssertEqual(g.crown, 0)
    }

    func testOnlinePlayersAndAvatars() throws {
        let d = try loadDashboard()
        XCTAssertEqual(d.onlinePlayers["bob"], "")
        XCTAssertEqual(d.onlinePlayers["carol"], "")
        XCTAssertTrue(d.avatarUsernames.contains("bob"))
        XCTAssertFalse(d.avatarUsernames.contains("carol"))
        XCTAssertTrue(d.avatarUsernames.contains("grace"))   // fromColor != black -> included
        XCTAssertFalse(d.avatarUsernames.contains("heidi"))  // fromColor 0 (black) -> excluded
    }

    func testParseStoneColor() {
        XCTAssertEqual(DashboardMapping.parseStoneColor("white_to_move"), "white")
        XCTAssertEqual(DashboardMapping.parseStoneColor("black (p2)"), "black")
        XCTAssertEqual(DashboardMapping.parseStoneColor("red"), "")
        XCTAssertEqual(DashboardMapping.parseStoneColor(nil), "")
    }

    private func flags(_ playerJSON: String) throws -> DashboardFlags {
        let json = #"{"player":"# + playerJSON + "}"
        return DashboardMapping.map(try JSONDecoder().decode(WireDashboard.self, from: Data(json.utf8))).flags
    }

    func testSampleWithoutParentPidIsNotKid() throws {
        XCTAssertFalse(try loadDashboard().flags.isKid)
    }

    func testParentPidMakesKid() throws {
        XCTAssertTrue(try flags(#"{"name":"kid_one","parentPid":23000000012345}"#).isKid)
    }

    func testNullParentPidIsNotKid() throws {
        XCTAssertFalse(try flags(#"{"name":"bob","parentPid":null}"#).isKid)
    }

    func testParentPidOfAnyShapeNeverBreaksDecoding() throws {
        XCTAssertTrue(try flags(#"{"name":"kid_one","parentPid":"23000000012345"}"#).isKid)
        let f = try flags(#"{"name":"bob","parentPid":{"x":1}}"#)
        XCTAssertFalse(f.isKid)
        XCTAssertEqual(f.playerName, "bob")
    }

    // MARK: Unknown game ids are skipped (experimental games, e.g. live 33/34, tb 83/84)

    private func map(_ json: String) throws -> Dashboard {
        DashboardMapping.map(try JSONDecoder().decode(WireDashboard.self, from: Data(json.utf8)))
    }

    func testKnownGamesIds() {
        for id in [1, 2, 31, 32, 51, 53, 81] { XCTAssertTrue(KnownGames.isKnown(id: id), "\(id)") }
        for id in [0, 33, 34, 50, 83, 84, 200, -1] { XCTAssertFalse(KnownGames.isKnown(id: id), "\(id)") }
    }

    func testKnownGamesNames() {
        for n in ["Pente", "Speed Pente", "Speed-Pente", "tb-Go (9x9)", "Turn-based Pente", "Turn-based Go (9x9)", "Turn-based Renju", "Speed Renju", "Swap2-Keryo"] {
            XCTAssertTrue(KnownGames.isKnown(name: n), n)
        }
        for n in ["NewGame", "Speed NewGame", "tb-NewGame", "Turn-based NewGame", "Turn-based ", "", "Speed "] { XCTAssertFalse(KnownGames.isKnown(name: n), n) }
        XCTAssertFalse(KnownGames.isKnown(name: nil))
    }

    func testUnknownGamesSkippedInGameLists() throws {
        let known = #"{"setId":1,"gid":10,"gameName":"Pente","opponentName":"a","inviterName":"a"}"#
        let unknown = #"{"setId":2,"gid":20,"gameName":"Speed NewGame","opponentName":"b","inviterName":"b"}"#
        let tbKnown = #"{"setId":3,"gid":30,"gameName":"Turn-based Pente","opponentName":"c","inviterName":"c"}"#
        let tbUnknown = #"{"setId":4,"gid":40,"gameName":"Turn-based NewGame","opponentName":"d","inviterName":"d"}"#
        let d = try map("""
        {"invitationsSent":[\(unknown),\(known),\(tbUnknown),\(tbKnown)],"invitationsReceived":[\(known),\(unknown),\(tbKnown),\(tbUnknown)],
         "activeGamesMyTurn":[\(unknown),\(known),\(tbKnown),\(tbUnknown)],"activeGamesOpponentTurn":[\(unknown),\(known),\(tbKnown)],
         "openInvitationGames":[\(unknown),\(known),\(unknown),\(tbKnown),\(tbUnknown)]}
        """)
        XCTAssertEqual(d.sentInvitations.map { $0.gameType }, ["Pente", "Turn-based Pente"])
        XCTAssertEqual(d.invitations.map { $0.gameType }, ["Pente", "Turn-based Pente"])
        XCTAssertEqual(d.activeGames.map { $0.gameType }, ["Pente", "Turn-based Pente"])
        XCTAssertEqual(d.nonActiveGames.map { $0.gameType }, ["Pente", "Turn-based Pente"])
        XCTAssertEqual(d.publicInvitations.map { $0.gameType }, ["Pente", "Turn-based Pente"])
    }

    func testUnknownGamesSkippedInHillsAndRatings() throws {
        let d = try map("""
        {"kingOfTheHill":[{"gameId":33},{"gameId":1},{"gameId":83},{"gameId":51}],
         "ratingStats":[{"gameId":34,"rating":1500},{"gameId":3,"rating":1600},{"gameId":84}]}
        """)
        XCTAssertEqual(d.hills.map { $0.gameId }, [1, 51])
        XCTAssertEqual(d.ratingStats.map { $0.gameId }, [3])
        XCTAssertEqual(d.flags.tbHills, 1, "skipped hills must not be counted")
        XCTAssertEqual(d.flags.tbRatings, 0)
    }
}
