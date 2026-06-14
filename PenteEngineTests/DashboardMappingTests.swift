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

    func testOnlinePlayersAndAvatars() throws {
        let d = try loadDashboard()
        XCTAssertEqual(d.onlinePlayers["bob"], "")
        XCTAssertEqual(d.onlinePlayers["carol"], "")
        XCTAssertTrue(d.avatarUsernames.contains("bob"))
        XCTAssertFalse(d.avatarUsernames.contains("carol"))
    }
}
