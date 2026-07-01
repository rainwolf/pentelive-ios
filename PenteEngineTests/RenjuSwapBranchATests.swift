import XCTest
@testable import penteLive

/// Regression for the Taraguchi-10 move-4 **take-over** and its rejoin reconstruction.
///
/// The live server delivers a move-4 take-over as a SEAT-SWAP event (`dsgSwapSeatsTableEvent`),
/// applied by `Table.swapSeats(swap:silent:)` — NOT as a renju decision echo
/// (`dsgRenjuTaraguchiSwapTableEvent` -> `applyRenjuSwap`). A take-over must auto-commit Branch A
/// so the swapped-in player just plays move 5; leaving `branchChosen == false` lets `renjuPhase`
/// re-classify the position as `.branch` and re-present the Offer-10 / Branch-B choice — an
/// impossible state for a player who already took over.
///
/// A prior fix wrongly widened the guard in `applyRenjuSwap` (the decision-echo handler), which is
/// dead code on the live path. The commit belongs in the seat-swap handler; the decline path
/// through `applyRenjuSwap` is left byte-identical (`swap == false && n == 4`).
final class RenjuSwapBranchATests: XCTestCase {
    private func startedRenju(table: Int = 5) -> Table {
        let t = Table(table: table); t.game = 31; t.state.state = .started // 31 == GameEnum.renju
        // A live seat swap flips the two seats, so both must be occupied for the non-silent path.
        t.seats[1] = LivePlayer(name: "black"); t.seats[2] = LivePlayer(name: "white")
        return t
    }
    private func startedAtMove4() -> Table {
        let t = startedRenju()
        [112, 113, 97, 98].forEach { t.addMove(move: $0) } // n == 4, swap window open
        return t
    }

    // THE FIX (red -> green): a move-4 take-over arrives as the REAL seat-swap event and must
    // commit Branch A. On the pre-fix seat-swap handler branchChosen stays false and the phase is
    // .branch (Offer-10 re-presented) -> this assertion FAILS; after the fix it is .move.
    func testTakeOverAtMove4ChoosesBranchA() {
        let t = startedAtMove4()
        XCTAssertTrue(t.state.renju.awaitingSwap)            // open decision before the take-over
        t.swapSeats(swap: true, silent: false)               // dsgSwapSeatsTableEvent, the take-over
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertTrue(t.state.renju.swapTaken)
        XCTAssertTrue(t.state.renju.branchChosen)            // pre-fix: false -> BRANCH re-presented
        XCTAssertFalse(t.state.renju.tenOffer)
        XCTAssertEqual(renjuPhase(t.moves.count, t.state.renju), .move)
    }

    // After the take-over the swapped-in player must NOT see swap / decline / Offer-10 again.
    func testTakeOverAtMove4DoesNotRepresentOffer10() {
        let t = startedAtMove4()
        t.swapSeats(swap: true, silent: false)
        let b = renjuModalButtons(t.moves.count, t.state.renju, true)
        XCTAssertFalse(b.swap)
        XCTAssertFalse(b.declinePlace)
        XCTAssertFalse(b.offer10)
    }

    // REJOIN (swap-before-moves ordering): a bulk state-sync applies the silent seat swap while the
    // board is still empty, then replays the four moves. advanceRenjuTracking(isRejoin:) must still
    // resolve the take-over to Branch A / phase .move (matching backend RenjuRejoin.decode).
    func testRejoinTakeOverSwapBeforeMovesChoosesBranchA() {
        let t = startedRenju()
        t.swapSeats(swap: true, silent: true)                // silent swap applied at n == 0
        XCTAssertTrue(t.state.renju.swapTaken)
        XCTAssertFalse(t.state.renju.branchChosen)           // not yet — no moves loaded
        t.addMoves(moves: [112, 113, 97, 98])                // bulk replay -> advanceRenjuTracking(isRejoin:true)
        XCTAssertTrue(t.state.renju.branchChosen)
        XCTAssertFalse(t.state.renju.tenOffer)
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertEqual(renjuPhase(t.moves.count, t.state.renju), .move)
    }

    // REJOIN (moves-before-swap ordering): the four moves replay first (window reopens), then the
    // silent seat swap lands at n == 4 and the seat-swap handler commits Branch A.
    func testRejoinTakeOverMovesBeforeSwapChoosesBranchA() {
        let t = startedRenju()
        t.addMoves(moves: [112, 113, 97, 98])                // isRejoin replay -> awaitingSwap reopens
        XCTAssertTrue(t.state.renju.awaitingSwap)
        t.swapSeats(swap: true, silent: true)                // silent seat swap at n == 4
        XCTAssertTrue(t.state.renju.branchChosen)
        XCTAssertEqual(renjuPhase(t.moves.count, t.state.renju), .move)
    }

    // GUARD (decline path byte-identical): swap == false at move 4 through applyRenjuSwap still
    // commits Branch A exactly as before the fix.
    func testDeclineContinueAtN4Unchanged() {
        let t = startedAtMove4()
        t.applyRenjuSwap(swap: false, move: 129)
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertTrue(t.state.renju.branchChosen)
        XCTAssertFalse(t.state.renju.tenOffer)
        XCTAssertEqual(renjuPhase(t.moves.count, t.state.renju), .move)
    }

    // GUARD (Branch B reachable): at the OPEN move-4 decision point (before any choice) the modal
    // still offers swap / decline / Offer-10, so Branch B stays reachable via the offer-10 action.
    func testDecisionPointStillOffersBranchB() {
        let t = startedAtMove4()
        XCTAssertTrue(t.state.renju.awaitingSwap)
        let b = renjuModalButtons(t.moves.count, t.state.renju, true)
        XCTAssertTrue(b.swap)
        XCTAssertTrue(b.declinePlace)
        XCTAssertTrue(b.offer10)
        XCTAssertEqual(renjuPhase(t.moves.count, t.state.renju), .swap)
    }

    // GUARD (Offer-10 -> Branch B): the separate Offer-10 handler still reaches Branch B unchanged.
    func testOffer10StillReachesBranchB() {
        let t = startedAtMove4()
        let offers = [40, 41, 42, 55, 57, 70, 71, 72, 160, 176]
        t.applyRenjuOffer10(moves: offers)
        XCTAssertTrue(t.state.renju.branchChosen)
        XCTAssertTrue(t.state.renju.tenOffer)
        XCTAssertEqual(t.state.renju.offered, offers)
        XCTAssertEqual(renjuPhase(t.moves.count, t.state.renju), .selection)
    }

    // GUARD (early window): an actual DECLINE (swap == false) at an early window (n == 2) commits
    // no branch. Was previously mislabeled — it called applyRenjuSwap(swap: true) (a take-over),
    // not a decline, so it never guarded what its name claims.
    func testEarlyWindowDeclineDoesNotChooseBranch() {
        let t = startedRenju()
        [112, 113].forEach { t.addMove(move: $0) } // n == 2
        t.applyRenjuSwap(swap: false, move: 97)    // a real decline at the early window
        XCTAssertFalse(t.state.renju.branchChosen)
        XCTAssertFalse(t.state.renju.awaitingSwap)
    }
}
