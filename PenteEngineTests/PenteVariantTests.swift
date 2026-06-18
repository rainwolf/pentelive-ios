import XCTest
@testable import penteLive

final class PenteVariantTests: XCTestCase {
    func testRawValuesMatchLegacyPenteGameVariantOrder() {
        // Raw values are FROZEN to the legacy PenteGameVariant NS_ENUM (PenteGame.h):
        // Pente=0, KeryoPente=1, GPente=2, DPente=3, DKPente=4, OPente=5,
        // PoofPente=6, Swap2Pente=7, Swap2Keryo=8, Gomoku=9, Connect6=10.
        XCTAssertEqual(PenteVariant.pente.rawValue, 0)
        XCTAssertEqual(PenteVariant.keryoPente.rawValue, 1)
        XCTAssertEqual(PenteVariant.gpente.rawValue, 2)
        XCTAssertEqual(PenteVariant.dPente.rawValue, 3)
        XCTAssertEqual(PenteVariant.dkPente.rawValue, 4)
        XCTAssertEqual(PenteVariant.oPente.rawValue, 5)
        XCTAssertEqual(PenteVariant.poofPente.rawValue, 6)
        XCTAssertEqual(PenteVariant.swap2Pente.rawValue, 7)
        XCTAssertEqual(PenteVariant.swap2Keryo.rawValue, 8)
        XCTAssertEqual(PenteVariant.gomoku.rawValue, 9)
        XCTAssertEqual(PenteVariant.connect6.rawValue, 10)
    }

    func testRenjuRawValueIsEleven() {
        XCTAssertEqual(PenteVariant.renju.rawValue, 11)
    }
}
