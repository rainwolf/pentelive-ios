import XCTest
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
