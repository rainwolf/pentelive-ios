import XCTest
@testable import penteLive

final class RuleSetTests: XCTestCase {
    private func assertCapture(_ r: RuleSet, run: Int, threshold: Int,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(r.capture?.run, run, file: file, line: line)
        XCTAssertEqual(r.capture?.threshold, threshold, file: file, line: line)
    }

    func testPente() {
        let r = ruleSet(for: .pente)
        assertCapture(r, run: 2, threshold: 10)
        XCTAssertEqual(r.poof, .none)
        XCTAssertEqual(r.winLength, 5)
        XCTAssertEqual(r.opening, .tournament)
        XCTAssertEqual(r.cadence, .alternating)
    }

    func testKeryoPente() {
        let r = ruleSet(for: .keryoPente)
        assertCapture(r, run: 3, threshold: 15)
        XCTAssertEqual(r.poof, .none)
        XCTAssertEqual(r.opening, .tournament)
    }

    func testGPente() {
        let r = ruleSet(for: .gpente)
        assertCapture(r, run: 2, threshold: 10)
        XCTAssertEqual(r.opening, .gpente)
    }

    func testBoatPente() {
        // Boat-Pente is Pente-flavoured (2-stone capture, threshold 10, tournament
        // opening, alternating) but carries the unbreakable-five `boat` flag.
        let r = ruleSet(for: .boatPente)
        assertCapture(r, run: 2, threshold: 10)
        XCTAssertEqual(r.poof, .none)
        XCTAssertEqual(r.winLength, 5)
        XCTAssertEqual(r.opening, .tournament)
        XCTAssertEqual(r.cadence, .alternating)
        XCTAssertTrue(r.boat)
        // Every other variant leaves boat off.
        XCTAssertFalse(ruleSet(for: .pente).boat)
        XCTAssertFalse(ruleSet(for: .keryoPente).boat)
    }

    func testDPente() {
        let r = ruleSet(for: .dPente)
        assertCapture(r, run: 2, threshold: 10)
        XCTAssertEqual(r.opening, .none)
    }

    func testDKPente() {
        let r = ruleSet(for: .dkPente)
        assertCapture(r, run: 3, threshold: 15)
        XCTAssertEqual(r.opening, .none)
    }

    func testOPente() {
        let r = ruleSet(for: .oPente)
        assertCapture(r, run: 3, threshold: 10)   // threshold 10, NOT keryo family
        XCTAssertEqual(r.poof, .keryo)
        XCTAssertEqual(r.opening, .tournament)
    }

    func testPoofPente() {
        let r = ruleSet(for: .poofPente)
        assertCapture(r, run: 2, threshold: 10)
        XCTAssertEqual(r.poof, .poof)
        XCTAssertEqual(r.opening, .tournament)
    }

    func testSwap2Pente() {
        let r = ruleSet(for: .swap2Pente)
        assertCapture(r, run: 2, threshold: 10)
        XCTAssertEqual(r.opening, .swap2)
    }

    func testSwap2Keryo() {
        let r = ruleSet(for: .swap2Keryo)
        assertCapture(r, run: 3, threshold: 15)
        XCTAssertEqual(r.opening, .swap2)
    }

    func testGomoku() {
        let r = ruleSet(for: .gomoku)
        XCTAssertNil(r.capture)
        XCTAssertEqual(r.poof, .none)
        XCTAssertEqual(r.winLength, 5)
        XCTAssertEqual(r.cadence, .alternating)
    }

    func testConnect6() {
        let r = ruleSet(for: .connect6)
        XCTAssertNil(r.capture)
        XCTAssertEqual(r.winLength, 6)
        XCTAssertEqual(r.cadence, .connect6)
    }

    func testRenju() {
        let r = ruleSet(for: .renju)
        XCTAssertNil(r.capture)          // Gomoku-like: no captures
        XCTAssertEqual(r.poof, .none)
        XCTAssertEqual(r.winLength, 5)
        XCTAssertEqual(r.opening, .none)
        XCTAssertEqual(r.cadence, .blackFirst)
        XCTAssertEqual(r.boardSize, 15)
    }

    func testNonRenjuBoardSizeDefaultsTo19() {
        XCTAssertEqual(ruleSet(for: .pente).boardSize, 19)
        XCTAssertEqual(ruleSet(for: .gomoku).boardSize, 19)
    }
}
