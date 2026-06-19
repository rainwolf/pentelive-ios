import XCTest
@testable import penteLive

final class RenjuOpeningPhaseTests: XCTestCase {
    private func rs(_ f: (inout RenjuTracking) -> Void) -> RenjuTracking { var t = RenjuTracking(); f(&t); return t }

    func testWindows1to4OpenAreSwap() {
        for n in [1,2,3,4] { XCTAssertEqual(renjuPhase(n, rs { $0.awaitingSwap = true }), .swap) }
    }
    func testMove4ResolvedNoBranchIsBranch() {
        XCTAssertEqual(renjuPhase(4, rs { $0.awaitingSwap = false; $0.branchChosen = false }), .branch)
    }
    func testTenOffersNoneSelectedIsSelection() {
        XCTAssertEqual(renjuPhase(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = Array(repeating: 0, count: 10); $0.selected = nil }), .selection)
    }
    func testBranchAMove5WindowOpenIsSwap() {
        XCTAssertEqual(renjuPhase(5, rs { $0.branchChosen = true; $0.tenOffer = false; $0.awaitingSwap = true }), .swap)
    }
    func testBranchAMove5ResolvedIsMove() {
        XCTAssertEqual(renjuPhase(5, rs { $0.branchChosen = true; $0.tenOffer = false; $0.awaitingSwap = false }), .move)
    }
    func testBranchBCompleteIsComplete() {
        XCTAssertEqual(renjuPhase(5, rs { $0.branchChosen = true; $0.tenOffer = true; $0.complete = true }), .complete)
    }
    func testPostTakeoverWindows1to3AreMove() {
        for n in [1,2,3] { XCTAssertEqual(renjuPhase(n, rs { $0.awaitingSwap = false }), .move) }
    }
    func testCompleteIsComplete() { XCTAssertEqual(renjuPhase(6, rs { $0.complete = true }), .complete) }

    // renjuOpeningPlayer (seat 1/2/nil)
    func testAwaitingSwapNotLastColorToMove() {
        XCTAssertEqual(renjuOpeningPlayer(1, rs { $0.awaitingSwap = true }), 2)
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.awaitingSwap = true }), 1)
    }
    func testBranchChoiceIsBlack() {
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.awaitingSwap = false; $0.branchChosen = false }), 1)
    }
    func testBranchBOfferingBlackSelectingWhite() {
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = [1,2] }), 1)
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = Array(repeating: 0, count: 10); $0.selected = nil }), 2)
    }
    func testCompleteIsNil() { XCTAssertNil(renjuOpeningPlayer(6, rs { $0.complete = true })) }
    func testBranchAWindow5AndMove6White() {
        XCTAssertEqual(renjuOpeningPlayer(5, rs { $0.branchChosen = true; $0.awaitingSwap = true }), 2)
        XCTAssertEqual(renjuOpeningPlayer(5, rs { $0.branchChosen = true; $0.awaitingSwap = false }), 2)
    }
    func testBranchBSelectedFallsThroughToParity() {
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = Array(repeating: 0, count: 10); $0.selected = 57 }), 1)
    }

    func testBoxRadius() {
        XCTAssertEqual(renjuBoxRadius(0), 0)
        XCTAssertEqual([1,2,3,4].map(renjuBoxRadius), [1,2,3,4])
        XCTAssertEqual(renjuBoxRadius(5), 0)
    }

    func testPredicatesGateOnStarted() {
        XCTAssertFalse(isRenjuSwapChoice(2, rs { $0.awaitingSwap = true }, false))
        XCTAssertTrue(isRenjuSwapChoice(2, rs { $0.awaitingSwap = true }, true))
        XCTAssertTrue(isRenjuBranchChoice(4, rs { $0.awaitingSwap = false; $0.branchChosen = false }, true))
        XCTAssertTrue(isRenjuSelection(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = Array(repeating: 0, count: 10) }, true))
    }
    func testModalButtonsByPhase() {
        func eq(_ b: RenjuModalButtons, _ s: Bool, _ d: Bool, _ o: Bool) { XCTAssertEqual([b.swap,b.declinePlace,b.offer10], [s,d,o]) }
        eq(renjuModalButtons(2, rs { $0.awaitingSwap = true }, true), true, true, false)
        eq(renjuModalButtons(4, rs { $0.awaitingSwap = true }, true), true, true, true)
        eq(renjuModalButtons(4, rs { $0.awaitingSwap = false; $0.branchChosen = false }, true), false, true, true)
        eq(renjuModalButtons(5, rs { $0.branchChosen = true; $0.awaitingSwap = true }, true), true, true, false)
    }
}
