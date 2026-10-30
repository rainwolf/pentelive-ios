import XCTest
import UIKit
@testable import penteLive

final class DBRatingStyleTests: XCTestCase {
    func testRatingBands() {
        XCTAssertEqual(DBRatingStyle.ratingHex(1900), 0xFF0000)
        XCTAssertEqual(DBRatingStyle.ratingHex(1899), 0xFAF508)
        XCTAssertEqual(DBRatingStyle.ratingHex(1700), 0xFAF508)
        XCTAssertEqual(DBRatingStyle.ratingHex(1699), 0x0000FF)
        XCTAssertEqual(DBRatingStyle.ratingHex(1400), 0x0000FF)
        XCTAssertEqual(DBRatingStyle.ratingHex(1399), 0x1E824C)
        XCTAssertEqual(DBRatingStyle.ratingHex(1000), 0x1E824C)
        XCTAssertEqual(DBRatingStyle.ratingHex(999), 0x888888)
        XCTAssertEqual(DBRatingStyle.ratingHex(0), 0x888888)
    }

    func testCrownCodes() {
        XCTAssertEqual(DBCrown.from(code: 1), .gold)
        XCTAssertEqual(DBCrown.from(code: 2), .silver)
        XCTAssertEqual(DBCrown.from(code: 3), .bronze)
        XCTAssertEqual(DBCrown.from(code: 4), .koth(index: 0))
        XCTAssertEqual(DBCrown.from(code: 39), .koth(index: 35))
        XCTAssertEqual(DBCrown.from(code: 0), .none)
        XCTAssertEqual(DBCrown.from(code: -1), .none)
        XCTAssertEqual(DBCrown.from(code: 40), .none)
        XCTAssertEqual(DBCrown.koth(index: 35).imageName, "kothcrown36")
        XCTAssertEqual(DBCrown.gold.imageName, "crown.gif")
        XCTAssertEqual(DBCrown.silver.imageName, "scrown.gif")
        XCTAssertEqual(DBCrown.bronze.imageName, "bcrown.gif")
        XCTAssertNil(DBCrown.none.imageName)
    }

    func testNameColourGating() {
        XCTAssertNil(DBRatingStyle.nameHex(0))
        XCTAssertEqual(DBRatingStyle.nameHex((255 << 24) + 1), 0x000000)
        XCTAssertEqual(DBRatingStyle.nameHex(0xFF00AA00), 0x00AA00)
    }

    func testNullPlayerIsQuestionMark() {
        let s = DBRatingStyle.nameString(nil, font: .systemFont(ofSize: 14), alignRight: false)
        XCTAssertEqual(s.string, "?")
        XCTAssertEqual(DBRatingStyle.ratingString(nil, font: .systemFont(ofSize: 14)).length, 0)
    }

    func testMissingFieldsRenderPlain() {
        let font = UIFont.systemFont(ofSize: 14)
        let p = DBPlayer(nameColor: 0, crown: 0)
        let s = DBRatingStyle.nameString(p, font: font, alignRight: false)
        var attachments = 0
        s.enumerateAttribute(.attachment, in: NSRange(location: 0, length: s.length)) { v, _, _ in
            if v != nil { attachments += 1 }
        }
        XCTAssertEqual(attachments, 0)
        if s.length > 0 {
            let f = s.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
            XCTAssertFalse(f?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        }
    }

    func testColouredNameIsBoldAndCrowned() {
        let p = DBPlayer(name: "bob", rating: 1712, nameColor: 0xFF00AA00, crown: 1)
        let s = DBRatingStyle.nameString(p, font: .systemFont(ofSize: 14), alignRight: false)
        XCTAssertTrue(s.string.hasPrefix("bob"))
        let f = s.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(f?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
        var attachments = 0
        s.enumerateAttribute(.attachment, in: NSRange(location: 0, length: s.length)) { v, _, _ in
            if v != nil { attachments += 1 }
        }
        XCTAssertEqual(attachments, 1)
    }

    func testRatingStringFormat() {
        let s = DBRatingStyle.ratingString(DBPlayer(rating: 1712), font: .systemFont(ofSize: 14))
        XCTAssertEqual(s.string, "\u{25A0} 1712")
        let c = s.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertEqual(c, UIColor(dbHex: 0xFAF508))
    }
}
