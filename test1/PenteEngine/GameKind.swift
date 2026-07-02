import Foundation

/// Resolved identity for one `gameType` string, computed once and cached on `Game`
/// (see `Game.gameKind` in PentePlayer.h/.m) instead of being re-derived from the
/// raw string on every `boardTap`/`replayGame` call.
///
/// Go is not a `PenteVariant` (its rules shape doesn't fit `ruleSet(for:)`'s
/// exhaustive switch), so it's tracked separately via `isGo`/`goBoardSize`.
@objc final class GameKind: NSObject {
    @objc let rawGameType: String
    @objc let isGo: Bool
    /// 9/13/19, only meaningful when `isGo` is true.
    @objc let goBoardSize: Int32

    let variant: PenteVariant?

    @objc init(gameType: String) {
        rawGameType = gameType
        if (gameType.hasPrefix("Go") || gameType.hasPrefix("Speed Go"))
            && !gameType.hasPrefix("Gomoku") && !gameType.hasPrefix("Speed Gomoku") {
            isGo = true
            if gameType.contains("(9x9)") {
                goBoardSize = 9
            } else if gameType.contains("(13x13)") {
                goBoardSize = 13
            } else {
                goBoardSize = 19
            }
            variant = nil
        } else {
            isGo = false
            goBoardSize = 0
            variant = BoardVariantMapping.variant(forGameType: gameType)
        }
        super.init()
    }

    /// `variant`, defaulting to `.pente` for Go. Callers MUST test `isGo` first,
    /// mirroring the existing `BoardVariantMapping.variant(forGameType:)` convention.
    @objc var variantValue: PenteVariant { variant ?? .pente }

    @objc var isPente: Bool { variant == .pente }
    @objc var isKeryoPente: Bool { variant == .keryoPente }
    @objc var isGPente: Bool { variant == .gpente }
    @objc var isPoofPente: Bool { variant == .poofPente }
    @objc var isConnect6: Bool { variant == .connect6 }
    @objc var isGomoku: Bool { variant == .gomoku }
    @objc var isRenju: Bool { variant == .renju }
    @objc var isOPente: Bool { variant == .oPente }
    @objc var isBoatPente: Bool { rawGameType.contains("Boat-Pente") }

    // Families
    @objc var isSwap2: Bool { variant == .swap2Pente || variant == .swap2Keryo }
    @objc var isDOpening: Bool { variant == .dPente || variant == .dkPente }
    @objc var hasPoof: Bool { variant == .poofPente || variant == .oPente }
    @objc var isKeryoCaptureFamily: Bool {
        variant == .keryoPente || variant == .dkPente || variant == .oPente
    }
}
