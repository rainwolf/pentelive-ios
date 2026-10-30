import XCTest
@testable import penteLive

final class DBPreferencesTests: XCTestCase {
    private let suite = "DBPreferencesTests.suite"

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testHeatDefaultsOnAndPersists() {
        let defaults = UserDefaults(suiteName: suite)!
        let prefs = DBPreferences(defaults: defaults)
        XCTAssertTrue(prefs.heatOnBoard)
        XCTAssertEqual(prefs.movesShown, 20)

        prefs.heatOnBoard = false
        prefs.movesShown = 0
        let again = DBPreferences(defaults: defaults)
        XCTAssertFalse(again.heatOnBoard)
        XCTAssertEqual(again.movesShown, 0)
        XCTAssertEqual(defaults.object(forKey: "DBHeatOnBoard") as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: "DBMovesShown") as? Int, 0)
    }

    func testMoveSortDefaultsToWinRateAndPersists() {
        let defaults = UserDefaults(suiteName: suite)!
        let prefs = DBPreferences(defaults: defaults)
        XCTAssertEqual(prefs.moveSort, .winRate)

        prefs.moveSort = .games
        XCTAssertEqual(DBPreferences(defaults: defaults).moveSort, .games)
        XCTAssertEqual(defaults.string(forKey: "DBMoveSort"), "games")

        defaults.set("nonsense", forKey: "DBMoveSort")
        XCTAssertEqual(DBPreferences(defaults: defaults).moveSort, .winRate)
    }
}
