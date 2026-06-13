//
//  TableEngineRoutingTests.swift
//  PenteEngineTests
//

import XCTest
@testable import penteLive

final class TableEngineRoutingTests: XCTestCase {

    // White plays both flanking stones of a 1-3-1 row; the two black stones between
    // them are captured. Move order alternates white, black, white, black, white.
    //   idx0 white (9,5)=176   idx1 black (9,6)=177   idx2 white (0,0)=0
    //   idx3 black (9,7)=178   idx4 white (9,8)=179  -> captures (9,6),(9,7)
    func testCaptureSequenceDelegatesToEngine() {
        let table = Table(table: 1)
        table.game = GameEnum.pente.rawValue

        var animated: [Capture] = []
        table.onCaptures = { captures in animated = captures }

        for move in [9 * 19 + 5, 9 * 19 + 6, 0, 9 * 19 + 7, 9 * 19 + 8] {
            table.addMove(move: move)
        }

        // Board is the engine's board, read via Table.stone(at:).
        XCTAssertEqual(table.stone(at: 9 * 19 + 5), 1)
        XCTAssertEqual(table.stone(at: 9 * 19 + 8), 1)
        XCTAssertEqual(table.stone(at: 9 * 19 + 6), 0)
        XCTAssertEqual(table.stone(at: 9 * 19 + 7), 0)

        // Counters are the engine's counters (whiteCaptures/blackCaptures count
        // captured stones of that colour: two black stones were captured).
        XCTAssertEqual(table.blackCaptures, 2)
        XCTAssertEqual(table.whiteCaptures, 0)

        // The capture animation seam received exactly the two captured cells.
        XCTAssertEqual(animated.count, 2)
        XCTAssertEqual(Set(animated.map { $0.position }), [9 * 19 + 6, 9 * 19 + 7])
        XCTAssertTrue(animated.allSatisfy { $0.color == 2 })
    }
}
