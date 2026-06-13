import XCTest

final class GoGameTests: XCTestCase {

    // A single white stone at centre 40, surrounded by black on all four sides, is captured.
    func testCaptureSingleStoneByNoLiberties() {
        let go = GoGame(gridSize: 9)
        go.play(39)   // m0 black, 40-left   (player 1 = black, moves first)
        go.play(40)   // m1 white, target
        go.play(41)   // m2 black, 40-right
        go.play(0)    // m3 white filler (corner, has liberties)
        go.play(31)   // m4 black, 40-up
        go.play(80)   // m5 white filler (corner, has liberties)
        go.play(49)   // m6 black, 40-down -> white 40 has no liberties

        XCTAssertEqual(go.stone(at: 40), 0, "captured stone must be removed")
        XCTAssertEqual(go.whiteCaptures, 1, "one white stone captured")
        XCTAssertEqual(go.blackCaptures, 0)
        XCTAssertEqual(go.koMove, -1, "this capture is not a ko")
    }

    // A connected white group {40,41} (merged via flood-fill / settleGroups) is captured as one unit.
    func testCaptureConnectedGroupByNoLiberties() {
        let go = GoGame(gridSize: 9)
        go.play(39)   // m0 black, 40-left
        go.play(40)   // m1 white
        go.play(31)   // m2 black, 40-up
        go.play(41)   // m3 white -> merges with 40 into one group
        go.play(49)   // m4 black, 40-down
        go.play(0)    // m5 white filler
        go.play(42)   // m6 black, 41-right
        go.play(80)   // m7 white filler
        go.play(32)   // m8 black, 41-up
        go.play(8)    // m9 white filler
        go.play(50)   // m10 black, 41-down -> group {40,41} has no liberties

        XCTAssertEqual(go.stone(at: 40), 0)
        XCTAssertEqual(go.stone(at: 41), 0)
        XCTAssertEqual(go.whiteCaptures, 2, "both stones captured together")
    }

    // Two passes flip the game into markStones; a subsequent play marks a stone dead.
    func testDoublePassMarksDeadStone() {
        let go = GoGame(gridSize: 9)
        go.play(40)   // m0 black stone at centre
        go.play(81)   // m1 white pass (passMove == 81)
        go.play(81)   // m2 black pass -> double pass -> markStones
        XCTAssertEqual(go.phase, .markStones)
        go.play(40)   // m3 mark the black stone at 40 as dead
        XCTAssertEqual(go.stone(at: 40), 0, "dead stone removed from board")
        XCTAssertEqual(go.blackDeadStones, [40], "black stone recorded as dead")
    }
}
