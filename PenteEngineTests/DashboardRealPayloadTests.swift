import XCTest
@testable import penteLive

/// Regression guard against the REAL server contract. `dashboard_real_index.json` is a
/// frozen capture of `Gson().toJson(IndexResponse)` from the live `mobile/json/index.jsp`.
/// The original fabricated fixture used `"read": 0/1` (ints) for messages, but the server
/// emits `read` as a JSON boolean (`MessageEntry.read` is a Java `boolean`), which a strict
/// `Int?` decode rejected with "...isn't in the correct format". Decoding the real payload
/// here catches any future field-type drift in any section against actual server output.
final class DashboardRealPayloadTests: XCTestCase {
    private func realData() throws -> Data {
        let url = Bundle(for: type(of: self)).url(forResource: "dashboard_real_index", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func testRealServerPayloadDecodes() throws {
        // Must not throw — this is the exact decode the app performs on the live response.
        let wire = try JSONDecoder().decode(WireDashboard.self, from: try realData())
        XCTAssertEqual(wire.player?.name, "iostest")
        XCTAssertNotNil(wire.invitationsReceived) // key present -> not the invalid-credentials path
        XCTAssertEqual(wire.activeGamesMyTurn?.count, 2)
        XCTAssertFalse(wire.kingOfTheHill?.isEmpty ?? true)
    }

    func testRealServerPayloadMaps() throws {
        let wire = try JSONDecoder().decode(WireDashboard.self, from: try realData())
        let dash = DashboardMapping.map(wire) // must not crash
        XCTAssertEqual(dash.activeGames.count, 2)
        XCTAssertFalse(dash.hills.isEmpty)
        XCTAssertFalse(dash.ratingStats.isEmpty)
        XCTAssertEqual(dash.flags.playerName, "iostest")
    }

    private func allSectionsData() throws -> Data {
        let url = Bundle(for: type(of: self)).url(forResource: "dashboard_allsections", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    /// Locks decode+map coverage for EVERY section — including the ones that are empty in the
    /// real test account (invitations / sent / open / messages), where the `read` bug hid.
    /// The fixture mirrors the exact IndexResponse.java field types (read as JSON booleans,
    /// large `long` ids), so a future contract-type drift in any section fails here.
    func testAllSectionsContractDecodesAndMaps() throws {
        let wire = try JSONDecoder().decode(WireDashboard.self, from: try allSectionsData())
        XCTAssertEqual(wire.invitationsReceived?.count, 1)
        XCTAssertEqual(wire.invitationsSent?.count, 1)
        XCTAssertEqual(wire.openInvitationGames?.count, 1)
        XCTAssertEqual(wire.messages?.count, 2)

        let dash = DashboardMapping.map(wire)
        XCTAssertEqual(dash.invitations.count, 1)
        XCTAssertEqual(dash.sentInvitations.count, 1)
        XCTAssertEqual(dash.publicInvitations.count, 1)
        XCTAssertEqual(dash.activeGames.count, 1)
        XCTAssertEqual(dash.nonActiveGames.count, 1)
        XCTAssertEqual(dash.messages.count, 2)
        // read=[true,false] in the fixture -> "read"/"unread"
        XCTAssertEqual(Set(dash.messages.map { $0.unread }), Set(["read", "unread"]))
    }
}
