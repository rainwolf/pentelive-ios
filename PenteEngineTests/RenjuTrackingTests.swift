import XCTest
@testable import penteLive

final class RenjuTrackingTests: XCTestCase {
    // Mirrors react gameState.test.js: freshRenjuTracking defaults.
    func testDefaults() {
        let t = RenjuTracking()
        XCTAssertFalse(t.complete)
        XCTAssertFalse(t.awaitingSwap)
        XCTAssertFalse(t.branchChosen)
        XCTAssertFalse(t.tenOffer)
        XCTAssertEqual(t.offered, [])
        XCTAssertNil(t.selected)
        XCTAssertFalse(t.swapTaken)
    }
    func testValueSemantics() {
        var a = RenjuTracking()
        a.offered.append(1)
        XCTAssertEqual(RenjuTracking().offered, []) // a fresh value is unaffected
    }
    func testGameStateHasFreshTracking() {
        XCTAssertEqual(GameState().renju.offered, [])
        XCTAssertFalse(GameState().renju.complete)
    }
}
