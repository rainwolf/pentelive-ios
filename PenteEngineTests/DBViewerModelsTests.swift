import XCTest
import UIKit
@testable import penteLive

final class DBViewerModelsTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-30T00:00:00Z")!

    private func header(_ json: String) -> DBGameHeader {
        try! JSONDecoder().decode(DBGameHeader.self, from: Data(json.utf8))
    }

    func testHeaderNullPlayer() {
        let h = header(#"{"gid":1,"game":1,"player1":null,"player2":{"name":"bob","rating":1500},"winner":1,"moveCount":0}"#)
        let v = DBViewerHeader.make(header: h, moves: [], cursor: DBViewerCursor(moves: [], game: 1), now: now)
        XCTAssertEqual(v.p1Name.string, "?")
        XCTAssertEqual(v.p1Rating.string, "")
        XCTAssertTrue(v.p2Name.string.hasPrefix("bob"))
        XCTAssertTrue(v.p2Rating.string.contains("1500"))
    }

    func testHeaderScore() {
        let moves = [180, 181]
        let h = header(#"{"gid":1,"game":1,"winner":2,"playDate":"2026-05-01T12:00:00Z","moveCount":2}"#)
        let v = DBViewerHeader.make(header: h, moves: moves, cursor: DBViewerCursor(moves: moves, game: 1), now: now)
        XCTAssertEqual(v.score, "0 \u{2013} 1")
        XCTAssertFalse(v.date.isEmpty)
    }

    func testCapturesAtCursor() {
        let moves = [180, 181, 200, 182, 183]
        let h = header(#"{"gid":1,"game":1,"winner":1,"moveCount":5}"#)
        var c = DBViewerCursor(moves: moves, game: 1)
        c.jump(to: 4)
        let before = DBViewerHeader.make(header: h, moves: moves, cursor: c, now: now).captures.string
        c.jump(to: 5)
        let after = DBViewerHeader.make(header: h, moves: moves, cursor: c, now: now).captures.string
        XCTAssertNotEqual(before, after)
        XCTAssertTrue(after.hasSuffix("\u{00D7} 2"))
        XCTAssertFalse(after.contains("Pente"))
    }

    func testGridStates() {
        let cells = DBMoveCell.grid(moves: [180, 181, 200, 182, 183], game: 1, cursorIndex: 3)
        XCTAssertEqual(cells.map { $0.state }, [.past, .past, .current, .future, .future])
    }

    func testGridLabels() {
        let cells = DBMoveCell.grid(moves: [180, 181], game: 1, cursorIndex: 2)
        XCTAssertEqual(cells[0].label, "K10")
    }

    func testGridNumbersPente() {
        let cells = DBMoveCell.grid(moves: [180, 181, 200, 182], game: 1, cursorIndex: 4)
        XCTAssertEqual(cells.map { $0.number }, ["1", nil, "2", nil])
    }

    func testGridNumbersConnect6() {
        let cells = DBMoveCell.grid(moves: [180, 1, 2, 3, 4, 5, 6, 7], game: 13, cursorIndex: 8)
        XCTAssertEqual(cells.map { $0.number }, ["1", nil, nil, "2", nil, nil, nil, "3"])
    }

    func testGridCursorZeroAllFuture() {
        let cells = DBMoveCell.grid(moves: [180, 181], game: 1, cursorIndex: 0)
        XCTAssertEqual(cells.map { $0.state }, [.future, .future])
    }
}
