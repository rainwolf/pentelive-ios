import XCTest
@testable import penteLive

final class GameKindTests: XCTestCase {
    func testBareVariants() {
        XCTAssertTrue(GameKind(gameType: "Pente").isPente)
        XCTAssertTrue(GameKind(gameType: "Boat-Pente").isPente)
        XCTAssertTrue(GameKind(gameType: "Speed Pente").isPente)
        XCTAssertTrue(GameKind(gameType: "Keryo-Pente").isKeryoPente)
        XCTAssertTrue(GameKind(gameType: "G-Pente").isGPente)
        XCTAssertTrue(GameKind(gameType: "O-Pente").isOPente)
        XCTAssertTrue(GameKind(gameType: "Poof-Pente").isPoofPente)
        XCTAssertTrue(GameKind(gameType: "Connect6").isConnect6)
        XCTAssertTrue(GameKind(gameType: "Gomoku").isGomoku)
        XCTAssertTrue(GameKind(gameType: "Renju").isRenju)
    }

    func testBoatPenteFlagIsIndependentOfVariant() {
        XCTAssertTrue(GameKind(gameType: "Boat-Pente").isBoatPente)
        XCTAssertTrue(GameKind(gameType: "Speed Boat-Pente").isBoatPente)
        XCTAssertFalse(GameKind(gameType: "Pente").isBoatPente)
    }

    func testSwap2Family() {
        XCTAssertTrue(GameKind(gameType: "Swap2-Pente").isSwap2)
        XCTAssertTrue(GameKind(gameType: "Swap2-Keryo").isSwap2)
        XCTAssertFalse(GameKind(gameType: "Pente").isSwap2)
    }

    func testDOpeningFamily() {
        XCTAssertTrue(GameKind(gameType: "D-Pente").isDOpening)
        XCTAssertTrue(GameKind(gameType: "DK-Pente").isDOpening)
        XCTAssertFalse(GameKind(gameType: "Pente").isDOpening)
    }

    func testPoofFamily() {
        XCTAssertTrue(GameKind(gameType: "Poof-Pente").hasPoof)
        XCTAssertTrue(GameKind(gameType: "O-Pente").hasPoof)
        XCTAssertFalse(GameKind(gameType: "Pente").hasPoof)
    }

    func testKeryoCaptureFamily() {
        XCTAssertTrue(GameKind(gameType: "Keryo-Pente").isKeryoCaptureFamily)
        XCTAssertTrue(GameKind(gameType: "DK-Pente").isKeryoCaptureFamily)
        XCTAssertTrue(GameKind(gameType: "O-Pente").isKeryoCaptureFamily)
        XCTAssertFalse(GameKind(gameType: "Pente").isKeryoCaptureFamily)
    }

    func testGoIsDetectedAndSizedCorrectly() {
        let go19 = GameKind(gameType: "Go")
        XCTAssertTrue(go19.isGo)
        XCTAssertEqual(go19.goBoardSize, 19)

        let go9 = GameKind(gameType: "Go (9x9)")
        XCTAssertTrue(go9.isGo)
        XCTAssertEqual(go9.goBoardSize, 9)

        let go13 = GameKind(gameType: "Go (13x13)")
        XCTAssertTrue(go13.isGo)
        XCTAssertEqual(go13.goBoardSize, 13)

        let speedGo = GameKind(gameType: "Speed Go (9x9)")
        XCTAssertTrue(speedGo.isGo)
        XCTAssertEqual(speedGo.goBoardSize, 9)
    }

    /// Regression guard: "Gomoku"/"Speed Gomoku" share the "Go" prefix with
    /// "Go"/"Speed Go" and must NOT be misclassified as Go.
    func testGomokuIsNotMisclassifiedAsGo() {
        XCTAssertFalse(GameKind(gameType: "Gomoku").isGo)
        XCTAssertFalse(GameKind(gameType: "Speed Gomoku").isGo)
        XCTAssertTrue(GameKind(gameType: "Gomoku").isGomoku)
    }

    /// Family/variant booleans must all read false for Go — every property is
    /// keyed off the optional `variant`, which is nil for Go, not the
    /// `.pente`-defaulting `variantValue` fallback.
    func testGoDoesNotFalsePositiveOnPenteFamilies() {
        let go = GameKind(gameType: "Go")
        XCTAssertFalse(go.isPente)
        XCTAssertFalse(go.isConnect6)
        XCTAssertFalse(go.isSwap2)
        XCTAssertFalse(go.isDOpening)
        XCTAssertFalse(go.hasPoof)
        XCTAssertFalse(go.isKeryoCaptureFamily)
    }
}
