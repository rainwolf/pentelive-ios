import XCTest
import UIKit
@testable import penteLive

final class BoardVariantMappingTests: XCTestCase {
    func testVariantForGameType() {
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Pente"), .pente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Boat-Pente"), .pente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed Pente"), .pente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed Boat-Pente"), .pente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Keryo-Pente"), .keryoPente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed Keryo-Pente"), .keryoPente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "G-Pente"), .gpente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "D-Pente"), .dPente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "DK-Pente"), .dkPente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed DK-Pente"), .dkPente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Poof-Pente"), .poofPente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "O-Pente"), .oPente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Swap2-Pente"), .swap2Pente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Swap2-Keryo"), .swap2Keryo)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Connect6"), .connect6)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Gomoku"), .gomoku)
    }

    func testVariantForGameTypeFallsBackToPente() {
        // Unknown/legacy game-type strings deliberately fall back to .pente.
        // (Go must be filtered out by callers via isGoGame before reaching here.)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Go"), .pente)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: ""), .pente)
    }
}

extension BoardVariantMappingTests {
    private func rgba(_ c: UIColor) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }
    private func assertColor(_ got: UIColor,
                             _ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat,
                             file: StaticString = #filePath, line: UInt = #line) {
        let c = rgba(got)
        XCTAssertEqual(c.0, r, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(c.1, g, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(c.2, b, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(c.3, a, accuracy: 0.001, file: file, line: line)
    }

    func testBackgroundColors() {
        assertColor(BoardVariantMapping.backgroundColor(for: .pente, boatPente: false),
                    0.984, 0.851, 0.541, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .pente, boatPente: true),
                    0.145, 0.729, 1, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .keryoPente, boatPente: false),
                    0.702, 1, 0.518, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .oPente, boatPente: false),
                    0.32, 0.75, 0.50, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .poofPente, boatPente: false),
                    0.929, 0.639, 0.992, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .dPente, boatPente: false),
                    0.584, 0.753, 0.98, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .dkPente, boatPente: false),
                    1, 165.0 / 255.0, 0, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .gpente, boatPente: false),
                    0.616, 0.545, 0.965, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .swap2Pente, boatPente: false),
                    0.90, 0.67, 0.44, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .swap2Keryo, boatPente: false),
                    0.31, 0.78, 0.47, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .gomoku, boatPente: false),
                    0.612, 1, 0.898, 1)
        assertColor(BoardVariantMapping.backgroundColor(for: .connect6, boatPente: false),
                    0.929, 0.639, 0.992, 1)
    }
}
