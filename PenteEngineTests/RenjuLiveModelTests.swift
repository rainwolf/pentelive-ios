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

extension RenjuLiveModelTests {
    func testRenjuEventDicts() {
        let swapDict = RenjuWire.swap(swap: true, move: -1, player: "alice", table: 5)
        let inner = swapDict["dsgRenjuTaraguchiSwapTableEvent"] as! [String: Any]
        XCTAssertEqual(inner["swap"] as! Bool, true)
        XCTAssertEqual(inner["move"] as! Int, -1)
        XCTAssertEqual(inner["player"] as! String, "alice")
        XCTAssertEqual(inner["table"] as! Int, 5)
        XCTAssertEqual(inner["time"] as! Int, 0)

        let offerDict = RenjuWire.offer10(moves: [1,2,3,4,5,6,7,8,9,10], player: "alice", table: 5)
        XCTAssertNotNil(offerDict["dsgRenjuTaraguchiOffer10TableEvent"])
        XCTAssertEqual((offerDict["dsgRenjuTaraguchiOffer10TableEvent"] as! [String: Any])["moves"] as! [Int], [1,2,3,4,5,6,7,8,9,10])

        let selDict = RenjuWire.select1(move: 130, player: "bob", table: 5)
        XCTAssertEqual((selDict["dsgRenjuTaraguchi10Select1TableEvent"] as! [String: Any])["move"] as! Int, 130)
    }
}
