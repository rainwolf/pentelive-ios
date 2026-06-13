import Foundation

@objc final class BoardVariantMapping: NSObject {

    /// Mirrors the dispatch in BoardViewController `replayGame:` (lines 2478-2519).
    /// Callers must test `isGoGame` first; Go is not a PenteVariant.
    @objc(variantForGameType:)
    static func variant(forGameType gameType: String) -> PenteVariant {
        if gameType == "Pente" || gameType == "Boat-Pente" ||
           gameType == "Speed Pente" || gameType == "Speed Boat-Pente" {
            return .pente
        }
        if gameType.contains("Keryo-Pente") { return .keryoPente }
        if gameType.contains("G-Pente") { return .gpente }
        if gameType.contains("D-Pente") { return .dPente }
        if gameType.contains("DK-Pente") { return .dkPente }
        if gameType.contains("Poof-Pente") { return .poofPente }
        if gameType.contains("O-Pente") { return .oPente }
        if gameType.contains("Swap2-Pente") { return .swap2Pente }
        if gameType.contains("Swap2-Keryo") { return .swap2Keryo }
        if gameType.contains("Connect6") { return .connect6 }
        if gameType.contains("Gomoku") { return .gomoku }
        // Deliberate fallback for unknown/legacy game-type strings, matching the
        // legacy behavior in BoardViewController. This is NOT a crash path: an
        // unexpected server game type must degrade gracefully in the live app.
        // Callers MUST filter Go (`isGoGame`) BEFORE calling this — Go is not a
        // Pente variant and would otherwise be silently mapped to `.pente`.
        return .pente
    }
}
