//
//  LiveBoardCaptureAnimationTests.swift
//  PenteEngineTests
//

import XCTest
@testable import penteLive

final class LiveBoardCaptureAnimationTests: XCTestCase {

    func testAnimateCapturesAddsOneTransientStonePerCapturedCell() {
        let table = Table(table: 1)
        table.game = GameEnum.pente.rawValue
        let board = LiveBoard(table: table)
        board.frame = CGRect(x: 0, y: 0, width: 380, height: 380)

        XCTAssertEqual(board.subviews.count, 0)

        board.animateCaptures([
            Capture(position: 9 * 19 + 6, color: 2),
            Capture(position: 9 * 19 + 7, color: 2),
        ])

        // The overlay stones are added synchronously, before the fade completes.
        XCTAssertEqual(board.subviews.count, 2)
    }

    func testAnimateCapturesIgnoresEmptyInput() {
        let table = Table(table: 1)
        table.game = GameEnum.pente.rawValue
        let board = LiveBoard(table: table)
        board.frame = CGRect(x: 0, y: 0, width: 380, height: 380)

        board.animateCaptures([])

        XCTAssertEqual(board.subviews.count, 0)
    }
}
