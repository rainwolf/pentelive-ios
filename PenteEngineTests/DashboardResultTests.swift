import XCTest
@testable import penteLive

final class DashboardResultTests: XCTestCase {
    func testFlagsAndDashboardHoldValues() {
        let flags = DashboardFlags(myColorRGB: 0x112233, playerName: "alice",
                                   showAds: true, subscriber: false, dbAccess: true,
                                   emailMe: true, tbHills: 2, tbRatings: 1,
                                   livePlayers: "5", onlineFollowing: "3")
        let g = Game(); g.gameID = "42"
        let dash = Dashboard(sentInvitations: [], invitations: [g], activeGames: [],
                             nonActiveGames: [], publicInvitations: [], messages: [],
                             tournaments: [], hills: [], ratingStats: [],
                             onlinePlayers: ["bob": ""], avatarUsernames: ["bob"], flags: flags)
        XCTAssertEqual(dash.invitations.first?.gameID, "42")
        XCTAssertEqual(dash.flags.tbHills, 2)
        XCTAssertEqual(dash.flags.playerName, "alice")
        XCTAssertEqual(dash.onlinePlayers["bob"], "")
        XCTAssertTrue(flags.showAds)
    }

    func testErrorCodes() {
        let e = DashboardError.make(.http, message: "HTTP 503") as NSError
        XCTAssertEqual(e.code, DashboardErrorCode.http.rawValue)
        XCTAssertEqual(e.domain, DashboardError.domain)
        XCTAssertEqual(e.localizedDescription, "HTTP 503")
    }
}
