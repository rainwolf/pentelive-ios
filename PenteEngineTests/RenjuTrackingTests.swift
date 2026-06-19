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

extension RenjuTrackingTests {
    private func started() -> Table { let t = Table(table: 5); t.game = 31; t.state.state = .started; return t }
    private func phase(_ t: Table) -> RenjuPhase { renjuPhase(t.moves.count, t.state.renju) }

    func testAddMoveOpensSwapWindow1to4() {
        let t = started(); t.addMove(move: 112)
        XCTAssertTrue(t.state.renju.awaitingSwap)
        XCTAssertFalse(t.state.renju.complete)
    }
    func testSwapFalseAtN4ChoosesBranchA() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.applyRenjuSwap(swap: false, move: 129)
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertTrue(t.state.renju.branchChosen)
        XCTAssertFalse(t.state.renju.tenOffer)
    }
    func testOffer10RecordsBranchB() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        let offers = [40,41,42,55,57,70,71,72,160,176]
        t.applyRenjuOffer10(moves: offers)
        XCTAssertTrue(t.state.renju.branchChosen)
        XCTAssertTrue(t.state.renju.tenOffer)
        XCTAssertEqual(t.state.renju.offered, offers)
        XCTAssertFalse(t.state.renju.awaitingSwap)
    }
    func testSelect1ThenMove5CompletesBranchB() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.applyRenjuOffer10(moves: [40,41,42,55,57,70,71,72,160,176])
        t.applyRenjuSelect1(move: 57)
        XCTAssertEqual(t.state.renju.selected, 57)
        t.addMove(move: 57)
        XCTAssertTrue(t.state.renju.complete)
    }
    func testBranchAMove5ThenWindow5ThenMove6Completes() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.applyRenjuSwap(swap: false, move: 129) // branch A
        t.addMove(move: 129)                     // move 5 -> window 5 opens
        XCTAssertTrue(t.state.renju.awaitingSwap)
        t.applyRenjuSwap(swap: false, move: -1)  // bare window-5 decline
        t.addMove(move: 200)                      // move 6
        XCTAssertTrue(t.state.renju.complete)
    }
    func testWindow1to3DeclineDoesNotChooseBranch() {
        let t = started(); [112,113].forEach { t.addMove(move: $0) }
        t.applyRenjuSwap(swap: false, move: 97)
        XCTAssertFalse(t.state.renju.branchChosen)
        XCTAssertFalse(t.state.renju.awaitingSwap)
    }
    func testLiveTakeoverAtN4GoesToBranch() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.seats[1] = LivePlayer(name: "graviton"); t.seats[2] = LivePlayer(name: "iostest")
        t.swapSeats(swap: true, silent: false)
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertFalse(t.state.renju.branchChosen) // -> BRANCH
        t.addMove(move: 129)
        XCTAssertTrue(t.state.renju.awaitingSwap)   // window 5 opens
    }
    // rejoin: echo BEFORE the bulk move list must NOT reopen a resolved window
    func testRejoinOffer10ThenBulkIsSelection() {
        let t = started()
        t.applyRenjuOffer10(moves: [113,114,115,116,128,129,130,131,144,145])
        t.addMoves(moves: [112,113,97,98]) // bulk replay
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertEqual(phase(t), .selection)
    }
    func testRejoinSilentSwapThenBulkIsBranch() {
        let t = started()
        t.swapSeats(swap: false, silent: true) // rejoin take-over marker
        t.addMoves(moves: [112,113,97,98])
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertFalse(t.state.renju.branchChosen)
        XCTAssertEqual(phase(t), .branch)
    }
    func testRejoinNoEchoBulkIsSwap() {
        let t = started(); t.addMoves(moves: [112,113,97,98])
        XCTAssertTrue(t.state.renju.awaitingSwap)
        XCTAssertEqual(phase(t), .swap)
    }
    func testResetClearsTracking() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.applyRenjuOffer10(moves: [40,41,42,55,57,70,71,72,160,176])
        t.reset()
        XCTAssertEqual(t.state.renju.offered, [])
        XCTAssertFalse(t.state.renju.tenOffer)
    }
    func testCurrentPlayerAfterOpeningIsSeatAlternationNotColour() {
        let t = started()
        [112, 113, 97, 98].forEach { t.addMove(move: $0) } // n=4
        t.applyRenjuSwap(swap: false, move: 129)            // Branch A
        t.addMove(move: 129)                                // move 5 -> window 5
        t.applyRenjuSwap(swap: false, move: -1)             // bare decline
        t.addMove(move: 200)                                // move 6 -> complete
        XCTAssertTrue(t.state.renju.complete)
        // opening complete -> renjuOpeningPlayer == nil -> seat fallback 1 + count%2 (NOT 2 - count%2)
        XCTAssertEqual(t.moves.count, 6)
        XCTAssertEqual(t.currentPlayer(), 1) // 1 + 6%2 = 1; the buggy 2 - 6%2 would give 2
    }

    // Regression (review #3): no swap window exists before the auto-placed centre. A bulk replay
    // of an empty move list must leave awaitingSwap=false so renjuOpeningPlayer(0) doesn't compute
    // the out-of-range seat 3 (Swift -1 % 2 == -1).
    func testNoSwapWindowAtZeroMoves() {
        let t = started()
        t.addMoves(moves: [])
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertNotEqual(t.currentPlayer(), 3)
        XCTAssertEqual(t.currentPlayer(), 1)
    }
}
