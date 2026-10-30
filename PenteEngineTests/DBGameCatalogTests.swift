import XCTest
@testable import penteLive

final class DBGameCatalogTests: XCTestCase {
    func testBaseGames() {
        XCTAssertEqual(DBGameCatalog.baseGames, [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31])
    }

    func testGameIdForName() {
        let names = ["Pente": 1, "Keryo-Pente": 3, "Gomoku": 5, "D-Pente": 7, "G-Pente": 9,
                     "Poof-Pente": 11, "Connect6": 13, "Boat-Pente": 15, "DK-Pente": 17,
                     "Go": 19, "Go (9x9)": 21, "Go (13x13)": 23,
                     "O-Pente": 25, "Swap2-Pente": 27, "Swap2-Keryo": 29, "Renju": 31]
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
        for n in [nil, "", "Tombstone", "nonsense", "Turn-based Go", "go", "Go (19x19)"] as [String?] {
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
        for id in [19, 20, 69, 21, 22, 71, 23, 24, 73, 31, 32, 81] {
            XCTAssertTrue(DBGameCatalog.isSupported(id), "\(id)")
        }
        XCTAssertFalse(DBGameCatalog.isSupported(DBGameCatalog.gameId(forName: "Tombstone")))
    }

    func testGoAndRenjuNamesRoundTrip() {
        let names = ["Go": 19, "Go (9x9)": 21, "Speed Go (13x13)": 24, "Speed Go": 20,
                     "Renju": 31, "Speed Renju": 32]
        for (n, id) in names {
            XCTAssertEqual(DBGameCatalog.gameId(forName: n), id, n)
            XCTAssertEqual(DBGameCatalog.name(forGame: id), n)
        }
        XCTAssertEqual(DBGameCatalog.gameId(forName: "Gomoku"), 5, "Go never matches Gomoku")
        XCTAssertTrue(DBGameCatalog.supportsSpeed(base: 21))
        XCTAssertTrue(DBGameCatalog.supportsSpeed(base: 31))
    }

    func testSpeedVariantAndSupportsSpeed() {
        XCTAssertEqual(DBGameCatalog.speedVariant(ofBase: 1), 2)
        XCTAssertTrue(DBGameCatalog.supportsSpeed(base: 1))
        XCTAssertFalse(DBGameCatalog.supportsSpeed(base: 27))
        XCTAssertFalse(DBGameCatalog.supportsSpeed(base: 29))
    }

    func testGridSize() {
        let expected: [Int: Int] = [
            19: 19, 20: 19, 69: 19, 21: 9, 22: 9, 71: 9, 23: 13, 24: 13, 73: 13,
            31: 15, 32: 15, 81: 15, 0: 19,
        ]
        for (id, g) in expected { XCTAssertEqual(DBGameCatalog.gridSize(forGame: id), g, "\(id)") }
        for id in DBGameCatalog.baseGames where !DBGameCatalog.blackMovesFirst(game: id) {
            XCTAssertEqual(DBGameCatalog.gridSize(forGame: id), 19, "Pente family \(id)")
            XCTAssertEqual(DBGameCatalog.gridSize(forGame: id + 50), 19, "tb \(id)")
        }
    }

    func testIsGoBlackFirstAndInitialMoves() {
        for id in [19, 20, 69, 21, 22, 71, 23, 24, 73] { XCTAssertTrue(DBGameCatalog.isGo(id), "\(id)") }
        for id in [1, 5, 31, 32, 0] { XCTAssertFalse(DBGameCatalog.isGo(id), "\(id)") }
        XCTAssertTrue(DBGameCatalog.isRenju(81))
        XCTAssertTrue(DBGameCatalog.blackMovesFirst(game: 19))
        XCTAssertTrue(DBGameCatalog.blackMovesFirst(game: 22))
        XCTAssertTrue(DBGameCatalog.blackMovesFirst(game: 31))
        XCTAssertFalse(DBGameCatalog.blackMovesFirst(game: 1))
        XCTAssertFalse(DBGameCatalog.blackMovesFirst(game: 13))
        XCTAssertEqual(DBGameCatalog.initialMoves(forGame: 21), [])
        XCTAssertEqual(DBGameCatalog.initialMoves(forGame: 19), [])
        XCTAssertEqual(DBGameCatalog.initialMoves(forGame: 31), [112])
        XCTAssertEqual(DBGameCatalog.initialMoves(forGame: 1), [180])
        XCTAssertEqual(DBGameCatalog.initialMoves(forGame: 7), [180], "D-Pente unchanged")
    }

    func testMoveLabelPerGrid() {
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 0, game: 21), "A9")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 80, game: 21), "J1")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 40, game: 21), "E5")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 81, game: 21), "PASS")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 169, game: 24), "PASS")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 112, game: 31), "H8")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 224, game: 31), "P1")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 225, game: 31), "PASS")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 180, game: 1), "K10")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: -3, game: 21), "")
        XCTAssertEqual(DBGameCatalog.moveLabel(cell: 90, game: 21), "")
    }

    func testHasCaptures() {
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 5))
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 13))
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 31))
        XCTAssertFalse(DBGameCatalog.hasCaptures(game: 32))
        XCTAssertTrue(DBGameCatalog.hasCaptures(game: 19))
        XCTAssertTrue(DBGameCatalog.hasCaptures(game: 21))
        XCTAssertTrue(DBGameCatalog.hasCaptures(game: 24))
        // Unsupported ids (unknown names map to 0) never show captures.
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
        XCTAssertEqual(Set(expected.keys),
                       Set(DBGameCatalog.baseGames.filter { !DBGameCatalog.blackMovesFirst(game: $0) }))
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
