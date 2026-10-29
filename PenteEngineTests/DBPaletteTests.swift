import XCTest
import UIKit
@testable import penteLive

final class DBPaletteTests: XCTestCase {
    func testBoardHexPerGame() {
        let expected: [(Int, UInt32)] = [
            (1, 0xFDDEA3), (3, 0xBAFDA3), (5, 0xA3FDEB), (7, 0xA3CDFD),
            (9, 0xAEA3FD), (11, 0xEDA3FD), (13, 0xEDA3FD), (15, 0x25BAFF),
            (17, 0xFFA500), (25, 0x52BE80), (27, 0xE5AA70), (29, 0x50C878),
        ]
        for (id, hex) in expected {
            XCTAssertEqual(DBPalette.boardHex(forGame: id), hex, "game \(id)")
        }
    }

    func testSpeedUsesBase() {
        XCTAssertEqual(DBPalette.boardHex(forGame: 2), DBPalette.boardHex(forGame: 1))
        XCTAssertEqual(DBPalette.boardHex(forGame: 18), DBPalette.boardHex(forGame: 17))
    }

    func testUnsupportedUsesPenteHex() {
        XCTAssertEqual(DBPalette.boardHex(forGame: 0), 0xFDDEA3)
    }

    func testHexRoundTrip() {
        XCTAssertEqual(UIColor(dbHex: 0x1F5FD6).dbHexString, "#1F5FD6")
    }

    func testBoardColorMatchesHex() {
        XCTAssertEqual(DBPalette.boardColor(forGame: 15).dbHexString, "#25BAFF")
    }

    func testChromeConstants() {
        XCTAssertEqual(DBPalette.ink.dbHexString, "#16181D")
        XCTAssertEqual(DBPalette.secondaryText.dbHexString, "#4A4F5A")
        XCTAssertEqual(DBPalette.secondaryText2.dbHexString, "#5C616B")
        XCTAssertEqual(DBPalette.accent.dbHexString, "#1F5FD6")
        XCTAssertEqual(DBPalette.divider.dbHexString, "#E2E4E9")
        XCTAssertEqual(DBPalette.chipOutline.dbHexString, "#C8CCD4")
        XCTAssertEqual(DBPalette.chipSelectedFill.dbHexString, "#E3ECFC")
        XCTAssertEqual(DBPalette.futureMove.dbHexString, "#8A8F99")
    }
}
