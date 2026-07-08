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

    // MARK: Pente — win by reaching the 10-capture threshold (5 custodial captures)
    func testPenteWinByTenCaptures() {
        // Five independent horizontal brackets on well-separated rows. Each closes a
        // W·B·B·W custodial capture (2 black stones), so white reaches 10 captures.
        // Each block is 6 moves (anchor, B, throwaway W, B, closer, filler B) to keep
        // parity so every closer lands on a white turn; the final block omits the
        // trailing filler (5 moves). Total = 29 moves; the last move is the 5th closer.
        let g = PenteGame(variant: .pente)
        let rows = [1, 4, 7, 10, 13]
        var moves: [Int] = []
        for (k, r) in rows.enumerated() {
            moves.append(r * 19 + 5)        // W anchor
            moves.append(r * 19 + 6)        // B   (captured)
            moves.append(18 * 19 + 2 * k)   // W throwaway (isolated, non-colinear)
            moves.append(r * 19 + 7)        // B   (captured)
            moves.append(r * 19 + 8)        // W closer → captures the black pair
            if k < rows.count - 1 {
                moves.append(17 * 19 + 2 * k)   // B filler (parity, harmless)
            }
        }
        XCTAssertEqual(moves.count, 29)
        let r = g.replay(moves, until: moves.count)
        XCTAssertEqual(r.placed, 1)             // closing move was white
        XCTAssertEqual(g.blackCaptures, 10)     // 5 captures × 2 black stones
        XCTAssertEqual(g.whiteCaptures, 0)
        XCTAssertEqual(r.winner, 1)             // white wins by reaching 10 captures
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

    // MARK: play() ignores an out-of-range move (no crash, no state mutation)
    func testPlayOutOfRangeMoveIsNoOp() {
        let g = PenteGame(variant: .pente)
        _ = g.replay([9*19+5, 9*19+6, 0, 9*19+7, 9*19+8], until: 5)  // black pair captured
        let whiteBefore = g.whiteCaptures
        let blackBefore = g.blackCaptures

        let low = g.play(-1)
        XCTAssertEqual(low.captured.count, 0)
        XCTAssertFalse(low.poofed)
        XCTAssertEqual(low.winner, 0)
        XCTAssertEqual(low.placed, 0)

        let high = g.play(361)
        XCTAssertEqual(high.captured.count, 0)
        XCTAssertFalse(high.poofed)
        XCTAssertEqual(high.winner, 0)
        XCTAssertEqual(high.placed, 0)

        // Counters and existing stones are untouched.
        XCTAssertEqual(g.whiteCaptures, whiteBefore)
        XCTAssertEqual(g.blackCaptures, blackBefore)
        XCTAssertEqual(g.blackCaptures, 2)
        XCTAssertEqual(g.stone(at: 9*19+5), 1)
        XCTAssertEqual(g.stone(at: 9*19+8), 1)
        XCTAssertEqual(g.stone(at: 9*19+6), 0)

        // moveCount is untouched: the next valid move still alternates (index 5 -> black).
        let next = g.play(1)   // (0,1), empty
        XCTAssertEqual(next.placed, 2)
    }

    // MARK: OPente — capture count crosses 10 via a multi-removal poof (jumps 9 -> 12)
    func testOPenteWinWhenCaptureCountJumpsPastTen() {
        // Each keryo-poof removes 3 white stones at once, so whiteCaptures steps
        // 3, 6, 9, 12 and never equals exactly 10. With an `== threshold` test the win
        // was skipped; `>= threshold` catches the jump past 10. Four independent
        // vertical poof setups in well-separated columns; each block is 6 moves
        // (parity filler) except the last (5 moves). Total = 23 moves.
        let g = PenteGame(variant: .oPente)
        let cols = [2, 6, 10, 14]
        var moves: [Int] = []
        for (k, c) in cols.enumerated() {
            moves.append(2 * 19 + c)        // W partner
            moves.append(1 * 19 + c)        // B top flanker
            moves.append(4 * 19 + c)        // W partner
            moves.append(5 * 19 + c)        // B bottom flanker
            moves.append(3 * 19 + c)        // W placed -> keryo-poof of (2,c),(3,c),(4,c)
            if k < cols.count - 1 {
                moves.append(18 * 19 + c)   // B filler (parity, isolated)
            }
        }
        XCTAssertEqual(moves.count, 23)
        let r = g.replay(moves, until: moves.count)
        XCTAssertEqual(r.placed, 1)             // final move was white
        XCTAssertEqual(g.whiteCaptures, 12)     // 4 poofs × 3 white stones, jumps past 10
        XCTAssertEqual(g.blackCaptures, 0)
        XCTAssertEqual(r.winner, 2)             // black wins: white lost >= 10 stones
    }

    // MARK: Renju — black-first cadence + 15×15 board
    func testRenjuFirstStoneIsBlack() {
        let g = PenteGame(variant: .renju)
        _ = g.play(112)                       // server auto-centre
        XCTAssertEqual(g.stone(at: 112), 2)   // black-first: move 0 -> value 2
    }

    func testRenjuSecondStoneIsWhite() {
        let g = PenteGame(variant: .renju)
        _ = g.play(112)
        _ = g.play(113)
        XCTAssertEqual(g.stone(at: 113), 1)   // move 1 -> value 1 (white)
    }

    func testRenjuUses15x15Indexing() {
        let g = PenteGame(variant: .renju)
        _ = g.play(224)                       // last cell (col14,row14) on 15×15
        XCTAssertEqual(g.stone(at: 224), 2)
        XCTAssertEqual(g.stone(at: 225), 0)   // out of range on 15×15 -> treated empty
    }

    func testRenjuHasNoCaptures() {
        // Layout that WOULD capture in Pente: B(112) W(113) W(114) B(115) collinear (row 7).
        let g = PenteGame(variant: .renju)
        _ = g.play(112)   // B  (m0)
        _ = g.play(113)   // W  (m1)
        _ = g.play(200)   // B  (m2, off to the side)
        _ = g.play(114)   // W  (m3)
        _ = g.play(115)   // B  (m4) flanks the W pair
        XCTAssertEqual(g.stone(at: 113), 1)   // NOT captured
        XCTAssertEqual(g.stone(at: 114), 1)   // NOT captured
    }

    func testNonRenjuEngineUnchangedFirstStoneWhite() {
        let g = PenteGame(variant: .pente)
        _ = g.play(180)
        XCTAssertEqual(g.stone(at: 180), 1)   // legacy white-first preserved (19×19)
    }

    // MARK: PoofPente ADVANTAGE rule (authority: SimplePoofPenteState.isGameOver/
    // getWinner). A capture win requires the threshold AND strictly MORE lost
    // stones than the opponent; at a tie (10-10) the game continues. This builds
    // an exact 10-10 board and asserts NO winner -- a plain `>=` referee (either
    // side reaching 10 wins) would wrongly report black winning here.
    //
    // 10 independent, mutually isolated capture gadgets on even rows (spaced 2 so
    // no spurious cross-row line/capture); "junk" fillers live far away (cols
    // 10-18) at king-distance >= 2 from everything, so they never capture or form
    // a line -- they only keep the alternating cadence landing each closer on the
    // intended colour.
    private func poofAdvantageMoves() -> [Int] {
        func rc(_ r: Int, _ c: Int) -> Int { r * 19 + c }
        var junkPool: [Int] = []
        for c in [10, 12, 14, 16, 18] {
            for r in [1, 3, 5, 7, 9, 11, 13, 15, 17] { junkPool.append(rc(r, c)) }
        }
        var ji = 0
        func junk() -> Int { defer { ji += 1 }; return junkPool[ji] }

        var m: [Int] = []
        // White-captures-black x5: W(3) B(4) Wjunk B(5) W(6)=closer Bjunk.
        // Each closer custodially captures the black pair -> blackCaptures += 2.
        for k in 0..<5 {
            let r = 2 * k
            m += [rc(r, 3), rc(r, 4), junk(), rc(r, 5), rc(r, 6), junk()]
        }
        // Black-captures-white x5: Wjunk B(3) W(4) Bjunk W(5) B(6)=closer.
        // Each closer captures the white pair -> whiteCaptures += 2.
        for k in 0..<5 {
            let r = 10 + 2 * k
            m += [junk(), rc(r, 3), rc(r, 4), junk(), rc(r, 5), rc(r, 6)]
        }
        return m
    }

    func testPoofPenteAdvantageRuleTieContinuesAndStrictLeadWins() {
        let g = PenteGame(variant: .poofPente)
        let m = poofAdvantageMoves()
        XCTAssertEqual(m.count, 60)

        // After only the white-capturing gadgets: black has lost 10, white 0.
        // Strictly ahead at the threshold -> white wins (advantage branch).
        let mid = g.replay(m, until: 30)
        XCTAssertEqual(g.blackCaptures, 10)
        XCTAssertEqual(g.whiteCaptures, 0)
        XCTAssertEqual(mid.winner, 1)

        // After the mirror gadgets: an exact 10-10 tie -> game continues, NO win.
        // (A plain `>=` referee would report winner == 2 here.)
        let end = g.replay(m, until: 60)
        XCTAssertEqual(g.whiteCaptures, 10)
        XCTAssertEqual(g.blackCaptures, 10)
        XCTAssertEqual(end.winner, 0)
    }

    // MARK: @objc cadence accessor (colorForMoveAt:) exposes the variant cadence
    // the turn-driven UI needs (esp. Connect6's 1,2,2,1 two-stone rotation).
    func testColorForMoveAtExposesCadence() {
        let pente = PenteGame(variant: .pente)
        XCTAssertEqual((0..<4).map { pente.colorForMove(at: $0) }, [1, 2, 1, 2])
        let c6 = PenteGame(variant: .connect6)
        XCTAssertEqual((0..<8).map { c6.colorForMove(at: $0) }, [1, 2, 2, 1, 1, 2, 2, 1])
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

    // MARK: Boat-Pente — a clean (unbreakable) five wins, just like Pente.
    func testBoatWinByUnbreakableFive() {
        let g = PenteGame(variant: .boatPente)
        // White (9,5)..(9,9); black fillers isolated on row 0 (no captures, no line).
        let moves = [9*19+5, 0*19+0, 9*19+6, 0*19+2, 9*19+7, 0*19+4,
                     9*19+8, 0*19+6, 9*19+9]
        let beforeWin = g.replay(moves, until: 7)  // after 4th white (cols 5..8)
        XCTAssertEqual(beforeWin.winner, 0)
        let r = g.replay(moves, until: moves.count) // 5th white completes the line
        XCTAssertEqual(r.placed, 1)
        XCTAssertEqual(r.winner, 1)                 // unbreakable five -> white wins
    }

    // MARK: Boat-Pente — a five with a capturable stone is provisional, NOT a win.
    // The same position under plain Pente would win immediately (see companion test).
    func testBoatCapturableFiveIsNotAWin() {
        // White five (9,5)..(9,9) plus off-line white (8,5). Black at (7,5) is the far
        // flank of the (8,5),(9,5) pair; (10,5) stays empty, so black could capture the
        // pair and break the five -> Boat withholds the win.
        let g = PenteGame(variant: .boatPente)
        // idx: 0 W(9,5) 1 B(7,5) 2 W(9,6) 3 B(0,0) 4 W(9,7) 5 B(0,2)
        //      6 W(8,5) 7 B(0,4) 8 W(9,8) 9 B(0,6) 10 W(9,9) completes the five
        let seq = [9*19+5, 7*19+5, 9*19+6, 0*19+0, 9*19+7, 0*19+2,
                   8*19+5, 0*19+4, 9*19+8, 0*19+6, 9*19+9]
        let r = g.replay(seq, until: seq.count)
        XCTAssertEqual(r.placed, 1)
        XCTAssertEqual(r.winner, 0)                 // provisional five -> no win yet

        // Sanity: identical sequence under plain Pente DOES win on the five.
        let p = PenteGame(variant: .pente)
        XCTAssertEqual(p.replay(seq, until: seq.count).winner, 1)
    }

    // MARK: Boat-Pente — capture-threshold win still applies (10 captures).
    func testBoatWinByTenCaptures() {
        let g = PenteGame(variant: .boatPente)
        let rows = [1, 4, 7, 10, 13]
        var moves: [Int] = []
        for (k, r) in rows.enumerated() {
            moves.append(r * 19 + 5)        // W anchor
            moves.append(r * 19 + 6)        // B (captured)
            moves.append(18 * 19 + 2 * k)   // W throwaway
            moves.append(r * 19 + 7)        // B (captured)
            moves.append(r * 19 + 8)        // W closer -> captures the black pair
            if k < rows.count - 1 {
                moves.append(17 * 19 + 2 * k)   // B filler (parity)
            }
        }
        let r = g.replay(moves, until: moves.count)
        XCTAssertEqual(g.blackCaptures, 10)
        XCTAssertEqual(r.winner, 1)                 // white wins by reaching 10 captures
    }

    // MARK: Boat-Pente — a provisional (breakable) five is PROMOTED to a win once the
    // opponent has had a turn and failed to break it (server BoatPenteState.isGameOver
    // awards the current player's standing five with no capture check).
    func testBoatBreakableFivePromotedWhenOpponentFailsToBreak() {
        // idx 10 = W(9,9) forms the five (9,5)..(9,9); it is breakable via the off-line
        // white pair (8,5),(9,5) — black sits at (7,5), (10,5) is empty. idx 11 = black
        // plays elsewhere (0,8) instead of the capturing (10,5), so on that move white's
        // five stands and is promoted.
        let seq = [9*19+5, 7*19+5, 9*19+6, 0*19+0, 9*19+7, 0*19+2,
                   8*19+5, 0*19+4, 9*19+8, 0*19+6, 9*19+9, 0*19+8]
        let g = PenteGame(variant: .boatPente)
        XCTAssertEqual(g.replay(seq, until: 11).winner, 0)   // white's formation move: provisional
        let r = g.replay(seq, until: seq.count)              // black failed to break it
        XCTAssertEqual(r.winner, 1)                          // -> white promoted to the win
    }

    // MARK: Boat-Pente — if the opponent DOES break the five, no promotion.
    func testBoatBreakableFiveNotPromotedIfBroken() {
        // Same as above but idx 11 = black plays (10,5), custodially capturing the
        // (8,5),(9,5) pair (black flankers at (7,5) and (10,5)) -> the five drops to
        // four and no win stands.
        let seq = [9*19+5, 7*19+5, 9*19+6, 0*19+0, 9*19+7, 0*19+2,
                   8*19+5, 0*19+4, 9*19+8, 0*19+6, 9*19+9, 10*19+5]
        let g = PenteGame(variant: .boatPente)
        let r = g.replay(seq, until: seq.count)
        XCTAssertEqual(g.whiteCaptures, 2)   // two white stones (8,5),(9,5) captured
        XCTAssertEqual(g.stone(at: 9*19+5), 0)
        XCTAssertEqual(r.winner, 0)          // broken five -> game continues
    }
}
