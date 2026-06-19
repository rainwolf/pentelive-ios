import XCTest
@testable import penteLive

final class RenjuLiveModelTests: XCTestCase {
    private func renjuTable() -> Table {
        let t = Table(table: 5); t.game = 31; t.state.state = .started; return t
    }
    func testRenjuPredicateAndGeometry() {
        let t = renjuTable()
        XCTAssertTrue(t.isRenju())
        XCTAssertEqual(t.gridSize, 15)
        XCTAssertEqual(t.passMove, 225)
    }
    func testRenjuEngineIsBlackFirst15x15() {
        let t = renjuTable()
        t.addMove(move: 112)         // server auto-centre, index (7,7)
        XCTAssertEqual(t.stone(at: 112), 2) // black first
        t.addMove(move: 113)
        XCTAssertEqual(t.stone(at: 113), 1) // white second
    }
    func testRenjuColorIsDustyRose() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        renjuTable().gameColor().getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), 0.851, accuracy: 0.01)
        XCTAssertEqual(Double(g), 0.533, accuracy: 0.01)
        XCTAssertEqual(Double(b), 0.502, accuracy: 0.01)
    }
}
