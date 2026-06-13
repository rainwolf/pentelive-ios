import XCTest
@testable import penteLive

final class PenteGameEngineTests: XCTestCase {

    // MARK: Pente — 2-stone capture (white brackets a black pair)
    func testPenteCaptureRemovesBlackPair() {
        // W(9,5) … W(9,8) brackets B(9,6),B(9,7) → blackCaptures += 2
        let g = PenteGame(variant: .pente)
        let moves = [9*19+5, 9*19+6, 0, 9*19+7, 9*19+8]  // W B W B W
        let r = g.replay(moves, until: moves.count)
        XCTAssertEqual(r.placed, 1)
        XCTAssertEqual(r.captured.count, 2)
        XCTAssertEqual(Set(r.captured.map { $0.position }), [9*19+6, 9*19+7])
        XCTAssertTrue(r.captured.allSatisfy { $0.color == 2 })
        XCTAssertEqual(g.blackCaptures, 2)
        XCTAssertEqual(g.whiteCaptures, 0)
        XCTAssertEqual(g.stone(at: 9*19+6), 0)
        XCTAssertEqual(g.stone(at: 9*19+7), 0)
        XCTAssertEqual(g.stone(at: 9*19+5), 1)
        XCTAssertEqual(g.stone(at: 9*19+8), 1)
        XCTAssertFalse(r.poofed)
        XCTAssertEqual(r.winner, 0)
    }

    // MARK: Pente — win by 5 in a row (interior cells)
    func testPenteWinByFiveInARow() {
        let g = PenteGame(variant: .pente)
        // White at row 3 cols 2..6; black harmless at row 15.
        let moves = [3*19+2, 15*19+2, 3*19+3, 15*19+3, 3*19+4, 15*19+4,
                     3*19+5, 15*19+5, 3*19+6]
        let beforeWin = g.replay(moves, until: 7)   // after 4th white (cols 2..5)
        XCTAssertEqual(beforeWin.winner, 0)
        let r = g.replay(moves, until: moves.count)  // 5th white completes the line
        XCTAssertEqual(r.placed, 1)
        XCTAssertEqual(r.winner, 1)
    }

    // MARK: Keryo — 3-stone capture, threshold 15 (no win at 3)
    func testKeryoCaptureRemovesBlackTriple() {
        // W(9,5) … W(9,9) brackets B(9,6),B(9,7),B(9,8) at distance 4 → keryo capture
        let g = PenteGame(variant: .keryoPente)
        let moves = [9*19+5, 9*19+6, 0, 9*19+7, 1, 9*19+8, 9*19+9]  // W B W B W B W
        let r = g.replay(moves, until: moves.count)
        XCTAssertEqual(r.captured.count, 3)
        XCTAssertEqual(Set(r.captured.map { $0.position }), [9*19+6, 9*19+7, 9*19+8])
        XCTAssertEqual(g.blackCaptures, 3)
        XCTAssertEqual(g.stone(at: 9*19+6), 0)
        XCTAssertEqual(g.stone(at: 9*19+7), 0)
        XCTAssertEqual(g.stone(at: 9*19+8), 0)
        XCTAssertEqual(r.winner, 0)            // 3 < 15
    }

    // MARK: PoofPente — placing into a bracketed pair self-captures (run 2)
    func testPoofPenteSelfCapture() {
        // B(9,5) opp, W(9,6) my, W places (9,7), B(9,8) opp → W pair (9,6),(9,7) poofs
        let g = PenteGame(variant: .poofPente)
        let moves = [9*19+6, 9*19+5, 0, 9*19+8, 9*19+7]  // W B W B W
        let r = g.replay(moves, until: moves.count)
        XCTAssertTrue(r.poofed)
        XCTAssertEqual(r.captured.count, 2)
        XCTAssertEqual(Set(r.captured.map { $0.position }), [9*19+6, 9*19+7])
        XCTAssertTrue(r.captured.allSatisfy { $0.color == 1 })
        XCTAssertEqual(g.whiteCaptures, 2)
        XCTAssertEqual(g.blackCaptures, 0)
        XCTAssertEqual(g.stone(at: 9*19+6), 0)
        XCTAssertEqual(g.stone(at: 9*19+7), 0)
        XCTAssertEqual(r.placed, 1)
        XCTAssertEqual(r.winner, 0)
    }

    // MARK: OPente — 3-stone keryo poof (placed in the middle of 3), threshold 10
    func testOPenteKeryoPoof() {
        // Column j=2 (off-centre): B(1,2), W(2,2), W places (3,2), W(4,2), B(5,2)
        // → W triple (2,2),(3,2),(4,2) keryo-poofs (run 3). Run-2 poof does not fire.
        let g = PenteGame(variant: .oPente)
        let moves = [2*19+2, 1*19+2, 4*19+2, 5*19+2, 3*19+2]  // W B W B W
        let r = g.replay(moves, until: moves.count)
        XCTAssertTrue(r.poofed)
        XCTAssertEqual(r.captured.count, 3)
        XCTAssertEqual(Set(r.captured.map { $0.position }), [2*19+2, 3*19+2, 4*19+2])
        XCTAssertTrue(r.captured.allSatisfy { $0.color == 1 })
        XCTAssertEqual(g.whiteCaptures, 3)
        XCTAssertEqual(g.blackCaptures, 0)
        XCTAssertEqual(g.stone(at: 2*19+2), 0)
        XCTAssertEqual(g.stone(at: 3*19+2), 0)
        XCTAssertEqual(g.stone(at: 4*19+2), 0)
        XCTAssertEqual(g.stone(at: 1*19+2), 2)
        XCTAssertEqual(g.stone(at: 5*19+2), 2)
        XCTAssertEqual(r.winner, 0)            // 3 < 10
    }

    // MARK: Tournament opening mask (Pente) applied at exactly 2 moves, cleared after
    func testTournamentOpeningMask() {
        let g = PenteGame(variant: .pente)
        let moves = [0, 18*19+18, 5*19+5]      // W(0,0), B(18,18), W(5,5)
        _ = g.replay(moves, until: 2)
        XCTAssertEqual(g.stone(at: 9*19+9), -1)   // centre masked
        XCTAssertEqual(g.stone(at: 7*19+7), -1)   // corner of 5x5 masked
        XCTAssertEqual(g.stone(at: 0), 1)         // occupied cell unchanged
        XCTAssertEqual(g.stone(at: 6*19+6), 0)    // outside 5x5 not masked
        _ = g.replay(moves, until: 3)
        XCTAssertEqual(g.stone(at: 9*19+9), 0)    // mask cleared at move 3
    }

    // MARK: G-Pente opening mask adds the 4 arms to the tournament 5x5
    func testGPenteOpeningMask() {
        let g = PenteGame(variant: .gpente)
        let moves = [0, 18*19+18]              // both outside the restricted shape
        _ = g.replay(moves, until: 2)
        XCTAssertEqual(g.stone(at: 9*19+9), -1)   // centre
        XCTAssertEqual(g.stone(at: 9*19+12), -1)  // arm (9,12)
        XCTAssertEqual(g.stone(at: 9*19+13), -1)  // arm (9,13)
        XCTAssertEqual(g.stone(at: 9*19+6), -1)   // arm (9,6)
        XCTAssertEqual(g.stone(at: 9*19+5), -1)   // arm (9,5)
        XCTAssertEqual(g.stone(at: 12*19+9), -1)  // arm (12,9)
        XCTAssertEqual(g.stone(at: 5*19+9), -1)   // arm (5,9)
        XCTAssertEqual(g.stone(at: 9*19+14), 0)   // beyond the arm, not masked
    }

    // MARK: Connect6 cadence W,B,B,W,W,B,B,W
    func testConnect6Cadence() {
        let g = PenteGame(variant: .connect6)
        let expected = [1, 2, 2, 1, 1, 2, 2, 1]
        var placed: [Int] = []
        for i in 0..<8 { placed.append(g.play(i).placed) }
        XCTAssertEqual(placed, expected)
    }

    // MARK: Connect6 needs 6 in a row (5 is NOT a win)
    func testConnect6WinNeedsSix() {
        let g = PenteGame(variant: .connect6)
        // White indices 0,3,4,7,8,11 place (9,2)..(9,7); blacks harmless at row 15.
        let moves = [9*19+2, 15*19+2, 15*19+3, 9*19+3, 9*19+4, 15*19+4,
                     15*19+5, 9*19+5, 9*19+6, 15*19+6, 15*19+7, 9*19+7]
        let five = g.replay(moves, until: 9)     // white has cols 2..6 = 5 in a row
        XCTAssertEqual(five.winner, 0)
        let six = g.replay(moves, until: moves.count)
        XCTAssertEqual(six.placed, 1)
        XCTAssertEqual(six.winner, 1)
    }

    // MARK: Gomoku — 5 in a row wins, and capture geometry does NOT capture
    func testGomokuWinAndNoCapture() {
        let win = PenteGame(variant: .gomoku)
        let winMoves = [3*19+2, 15*19+2, 3*19+3, 15*19+3, 3*19+4, 15*19+4,
                        3*19+5, 15*19+5, 3*19+6]
        XCTAssertEqual(win.replay(winMoves, until: winMoves.count).winner, 1)

        let noCap = PenteGame(variant: .gomoku)
        let capMoves = [9*19+5, 9*19+6, 0, 9*19+7, 9*19+8]  // would capture in Pente
        let r = noCap.replay(capMoves, until: capMoves.count)
        XCTAssertEqual(r.captured.count, 0)
        XCTAssertEqual(noCap.blackCaptures, 0)
        XCTAssertEqual(noCap.stone(at: 9*19+6), 2)   // black pair NOT removed
        XCTAssertEqual(noCap.stone(at: 9*19+7), 2)
    }

    // MARK: reset clears board + counters
    func testReset() {
        let g = PenteGame(variant: .pente)
        _ = g.replay([9*19+5, 9*19+6, 0, 9*19+7, 9*19+8], until: 5)
        XCTAssertEqual(g.blackCaptures, 2)
        g.reset()
        XCTAssertEqual(g.blackCaptures, 0)
        XCTAssertEqual(g.whiteCaptures, 0)
        XCTAssertEqual(g.stone(at: 9*19+5), 0)
    }
}
