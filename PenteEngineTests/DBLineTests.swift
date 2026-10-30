import XCTest
@testable import penteLive

final class DBLineTests: XCTestCase {
    override func tearDown() {
        DBStepPolicy.connect6StepsPerTurn = false
        super.tearDown()
    }

    func testRedoVector() {
        let line = DBLine(game: 7, moves: [])
        line.play(10)
        line.play(20)
        XCTAssertTrue(line.back())
        XCTAssertTrue(line.back())
        XCTAssertTrue(line.forward())
        XCTAssertEqual(line.cells, [10])
        XCTAssertEqual(line.redoCount, 1)
        line.play(30)
        XCTAssertEqual(line.cells, [10, 30])
        XCTAssertEqual(line.redoCount, 0)
    }

    func testBackStopsAtCentreStone() {
        let line = DBLine(game: 1, moves: [180])
        XCTAssertFalse(line.back())
        XCTAssertEqual(line.cells, [180])
        XCTAssertEqual(line.redoCount, 0)
    }

    func testForwardAtEndIsNoop() {
        let line = DBLine(game: 1, moves: [180, 5])
        XCTAssertFalse(line.forward())
        XCTAssertEqual(line.cells, [180, 5])
    }

    func testResetClearsRedo() {
        let line = DBLine(game: 1, moves: [180, 5])
        XCTAssertTrue(line.back())
        XCTAssertEqual(line.redoCount, 1)
        line.reset(moves: [180, 9])
        XCTAssertEqual(line.cells, [180, 9])
        XCTAssertEqual(line.redoCount, 0)
    }

    func testMinimumCount() {
        XCTAssertEqual(DBStepPolicy.minimumCount(game: 7), 0)
        XCTAssertEqual(DBStepPolicy.minimumCount(game: 17), 0)
        XCTAssertEqual(DBStepPolicy.minimumCount(game: 27), 0)
        XCTAssertEqual(DBStepPolicy.minimumCount(game: 29), 0)
        XCTAssertEqual(DBStepPolicy.minimumCount(game: 1), 1)
        XCTAssertEqual(DBStepPolicy.minimumCount(game: 13), 1)
    }

    func testConnect6DefaultsToSingleStones() {
        XCTAssertFalse(DBStepPolicy.connect6StepsPerTurn)
        let line = DBLine(game: 13, moves: [180, 1, 2])
        XCTAssertTrue(line.back())
        XCTAssertEqual(line.cells, [180, 1])
        XCTAssertTrue(line.forward())
        XCTAssertEqual(line.cells, [180, 1, 2])
    }

    func testConnect6TurnSteps() {
        DBStepPolicy.connect6StepsPerTurn = true
        let line = DBLine(game: 13, moves: [180, 1, 2])
        XCTAssertTrue(line.back())
        XCTAssertEqual(line.cells, [180])
        XCTAssertTrue(line.forward())
        XCTAssertEqual(line.cells, [180, 1, 2])
    }

    func testConnect6BackFromMidTurnLandsOnBoundary() {
        DBStepPolicy.connect6StepsPerTurn = true
        let line = DBLine(game: 13, moves: [180, 1, 2, 3])
        XCTAssertTrue(line.back())
        XCTAssertEqual(line.cells, [180, 1, 2])
        XCTAssertTrue(line.forward())
        XCTAssertEqual(line.cells, [180, 1, 2, 3])
    }
}
