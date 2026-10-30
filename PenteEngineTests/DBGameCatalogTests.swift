import XCTest
@testable import penteLive

final class DBGameCatalogTests: XCTestCase {
    func testBaseGames() {
        XCTAssertEqual(DBGameCatalog.baseGames, [1, 3, 5, 7, 9, 11, 13, 15, 17, 25, 27, 29])
    }

    func testGameIdForName() {
        let names = ["Pente": 1, "Keryo-Pente": 3, "Gomoku": 5, "D-Pente": 7, "G-Pente": 9,
                     "Poof-Pente": 11, "Connect6": 13, "Boat-Pente": 15, "DK-Pente": 17,
                     "O-Pente": 25, "Swap2-Pente": 27, "Swap2-Keryo": 29]
        for (n, id) in names {
            XCTAssertEqual(DBGameCatalog.gameId(forName: n), id, n)
            XCTAssertEqual(DBGameCatalog.name(forGame: id), n)
        }
    }

    func testSpeedPrefix() {
        XCTAssertEqual(DBGameCatalog.gameId(forName: "Speed Pente"), 2)
        XCTAssertEqual(DBGameCatalog.gameId(forName: "Speed DK-Pente"), 18)
        XCTAssertEqual(DBGameCatalog.name(forGame: 2), "Speed Pente")
        XCTAssertTrue(DBGameCatalog.isSpeed(2))
        XCTAssertFalse(DBGameCatalog.isSpeed(1))
    }

    func testUnknownNamesGiveZero() {
        for n in [nil, "", "Go", "Go (9x9)", "Renju", "nonsense"] as [String?] {
            XCTAssertEqual(DBGameCatalog.gameId(forName: n), 0, String(describing: n))
        }
    }

    func testBaseGameStripsSpeedAndTurnBased() {
        XCTAssertEqual(DBGameCatalog.baseGame(2), 1)
        XCTAssertEqual(DBGameCatalog.baseGame(51), 1)
        XCTAssertEqual(DBGameCatalog.baseGame(52), 1)
        XCTAssertEqual(DBGameCatalog.baseGame(15), 15)
    }

    func testIsSupported() {
        XCTAssertTrue(DBGameCatalog.isSupported(1))
        XCTAssertTrue(DBGameCatalog.isSupported(2))
        XCTAssertFalse(DBGameCatalog.isSupported(0))
        XCTAssertFalse(DBGameCatalog.isSupported(31))
    }

    func testSpeedVariantAndSupportsSpeed() {
        XCTAssertEqual(DBGameCatalog.speedVariant(ofBase: 1), 2)
        XCTAssertTrue(DBGameCatalog.supportsSpeed(base: 1))
        XCTAssertFalse(DBGameCatalog.supportsSpeed(base: 27))
        XCTAssertFalse(DBGameCatalog.supportsSpeed(base: 29))
    }

    func testGridSize() {
        for id in DBGameCatalog.baseGames { XCTAssertEqual(DBGameCatalog.gridSize(forGame: id), 19) }
    }

    func testHasCaptures() {
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 5))
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 13))
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 31))
        // Unsupported ids (Go, Renju, unknown names map to 0) never show captures.
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 0))
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 99))
        XCTAssertTrue(DBGameCatalog.hasCaptures(game: 1))
        XCTAssertTrue(DBGameCatalog.hasCaptures(game: 2))
    }

    func testVariant() {
        XCTAssertEqual(DBGameCatalog.variant(forGame: 15), .pente)
        XCTAssertEqual(DBGameCatalog.variant(forGame: 3), .keryoPente)
        XCTAssertEqual(DBGameCatalog.variant(forGame: 13), .connect6)
    }

    func testVariantEveryBaseGameIncludingDK() {
        let expected: [Int: PenteVariant] = [
            1: .pente, 3: .keryoPente, 5: .gomoku, 7: .dPente, 9: .gpente,
            11: .poofPente, 13: .connect6, 15: .pente, 17: .dkPente,
            25: .oPente, 27: .swap2Pente, 29: .swap2Keryo,
        ]
        XCTAssertEqual(Set(expected.keys), Set(DBGameCatalog.baseGames))
        for (id, v) in expected {
            XCTAssertEqual(DBGameCatalog.variant(forGame: id), v, "base \(id)")
            XCTAssertEqual(DBGameCatalog.variant(forGame: id + 50), v, "tb \(id)")
            if DBGameCatalog.supportsSpeed(base: id) {
                XCTAssertEqual(DBGameCatalog.variant(forGame: id + 1), v, "speed \(id)")
            }
        }
        XCTAssertEqual(DBGameCatalog.variant(forGame: 18), .dkPente)
    }
}
