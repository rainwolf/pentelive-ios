import XCTest
@testable import penteLive

final class DashboardDecodingTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = Bundle(for: type(of: self)).url(forResource: "dashboard_sample", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func testDecodesTopLevelSections() throws {
        let wire = try JSONDecoder().decode(WireDashboard.self, from: fixtureData())
        XCTAssertEqual(wire.player?.name, "alice")
        XCTAssertEqual(wire.player?.color, 1122867)
        XCTAssertEqual(wire.kingOfTheHill?.count, 3)
        XCTAssertEqual(wire.ratingStats?.count, 2)
        XCTAssertEqual(wire.invitationsReceived?.count, 1)
        XCTAssertEqual(wire.messages?.count, 2)
        XCTAssertEqual(wire.onlinePlayers, ["bob", "carol"])
    }

    func testFlexibleStringCoercesNumberAndString() throws {
        let wire = try JSONDecoder().decode(WireDashboard.self, from: fixtureData())
        XCTAssertEqual(wire.invitationsSent?.first?.setId?.value, "9001")
        XCTAssertEqual(wire.invitationsReceived?.first?.opponentRating?.value, "1450")
        XCTAssertEqual(wire.player?.livePlayers?.value, "5")
        // String passes through unchanged
        XCTAssertEqual(wire.invitationsSent?.first?.rated?.value, "rated")
        // Bool coerces to "1"/"0"
        struct BoolHolder: Decodable { let v: FlexibleString }
        let t = try JSONDecoder().decode(BoolHolder.self, from: Data("{\"v\":true}".utf8))
        let f = try JSONDecoder().decode(BoolHolder.self, from: Data("{\"v\":false}".utf8))
        XCTAssertEqual(t.v.value, "1")
        XCTAssertEqual(f.v.value, "0")
    }

    func testMissingInvitationsReceivedIsNil() throws {
        let json = Data("{\"player\":{\"name\":\"x\"}}".utf8)
        let wire = try JSONDecoder().decode(WireDashboard.self, from: json)
        XCTAssertNil(wire.invitationsReceived)
    }
}
