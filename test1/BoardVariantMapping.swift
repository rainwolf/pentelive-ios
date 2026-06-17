import UIKit

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

    /// One source of truth for the per-variant board colour; values copied verbatim
    /// from the former per-replay-method literals in BoardViewController.m.
    @objc(backgroundColorForVariant:boatPente:)
    static func backgroundColor(for variant: PenteVariant, boatPente: Bool) -> UIColor {
        switch variant {
        case .pente:
            return boatPente
                ? UIColor(red: 0.145, green: 0.729, blue: 1, alpha: 1)
                : UIColor(red: 0.984, green: 0.851, blue: 0.541, alpha: 1)
        case .keryoPente:
            return UIColor(red: 0.702, green: 1, blue: 0.518, alpha: 1)
        case .oPente:
            return UIColor(red: 0.32, green: 0.75, blue: 0.50, alpha: 1.0)
        case .poofPente:
            return UIColor(red: 0.929, green: 0.639, blue: 0.992, alpha: 1)
        case .dPente:
            return UIColor(red: 0.584, green: 0.753, blue: 0.98, alpha: 1)
        case .dkPente:
            return UIColor(red: 1, green: 165.0 / 255.0, blue: 0, alpha: 1)
        case .gpente:
            return UIColor(red: 0.616, green: 0.545, blue: 0.965, alpha: 1)
        case .swap2Pente:
            return UIColor(red: 0.90, green: 0.67, blue: 0.44, alpha: 1.00)
        case .swap2Keryo:
            return UIColor(red: 0.31, green: 0.78, blue: 0.47, alpha: 1.00)
        case .gomoku:
            return UIColor(red: 0.612, green: 1, blue: 0.898, alpha: 1)
        case .connect6:
            return UIColor(red: 0.929, green: 0.639, blue: 0.992, alpha: 1)
        case .renju:
            // #D98880 dusty rose — canonical Renju board colour, distinct from gomoku.
            return UIColor(red: 0.851, green: 0.533, blue: 0.502, alpha: 1)
        }
    }

    /// Gomoku/Connect6 never show capture counts; D/DK/Swap2 hide them during the opening.
    /// The four opening-gated variants all keyed off the `dPenteOpening` flag in the
    /// legacy code, so the caller passes `dPenteOpening` for `opening`.
    @objc(hidesCaptureLabelsForVariant:opening:)
    static func hidesCaptureLabels(for variant: PenteVariant, opening: Bool) -> Bool {
        switch variant {
        case .gomoku, .connect6, .renju:
            return true
        case .dPente, .dkPente, .swap2Pente, .swap2Keryo:
            return opening
        default:
            return false
        }
    }
}
