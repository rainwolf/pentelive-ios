import Foundation

/// Self-capture flavour. `.poof` = 2-stone poof only; `.keryo` = 2-stone and 3-stone poof.
enum PoofKind { case none, poof, keryo }

/// Restricted-opening overlay applied at exactly 2 played moves.
enum OpeningMask { case none, tournament, gpente, swap2 }

/// Move-colour cadence.
enum Cadence { case alternating, connect6, blackFirst }

/// A thin recipe: PARAMETERS ONLY. Recipes contain no scan code; the engine reads
/// these parameters and drives `Scan`.
protocol RuleSet {
    /// nil = no captures (Gomoku/Connect6). `run` is the maximum capture run length;
    /// the engine runs captures for every run 2...run. `threshold` is the legacy
    /// capture-loss limit (10 Pente family, 15 Keryo family).
    var capture: (run: Int, threshold: Int)? { get }
    var poof: PoofKind { get }
    var winLength: Int { get }
    var opening: OpeningMask { get }
    var cadence: Cadence { get }
    /// Board edge length. 19 for the Pente/Go family; 15 for Renju.
    var boardSize: Int { get }
}

/// Default board size: every legacy variant is 19×19. Only Renju overrides.
extension RuleSet { var boardSize: Int { 19 } }

struct PenteRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (2, 10)
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .tournament
    let cadence: Cadence = .alternating
}

struct KeryoPenteRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (3, 15)
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .tournament
    let cadence: Cadence = .alternating
}

struct GPenteRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (2, 10)
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .gpente
    let cadence: Cadence = .alternating
}

struct DPenteRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (2, 10)
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .none
    let cadence: Cadence = .alternating
}

struct DKPenteRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (3, 15)
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .none
    let cadence: Cadence = .alternating
}

struct OPenteRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (3, 10)
    let poof: PoofKind = .keryo
    let winLength: Int = 5
    let opening: OpeningMask = .tournament
    let cadence: Cadence = .alternating
}

struct PoofPenteRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (2, 10)
    let poof: PoofKind = .poof
    let winLength: Int = 5
    let opening: OpeningMask = .tournament
    let cadence: Cadence = .alternating
}

struct Swap2PenteRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (2, 10)
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .swap2
    let cadence: Cadence = .alternating
}

struct Swap2KeryoRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = (3, 15)
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .swap2
    let cadence: Cadence = .alternating
}

struct GomokuRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = nil
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .none
    let cadence: Cadence = .alternating
}

struct Connect6Rules: RuleSet {
    let capture: (run: Int, threshold: Int)? = nil
    let poof: PoofKind = .none
    let winLength: Int = 6
    let opening: OpeningMask = .none
    let cadence: Cadence = .connect6
}

struct RenjuRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = nil   // Gomoku-like, no captures
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .none   // central squares enforced server-side + in TB UI gate
    let cadence: Cadence = .blackFirst
    let boardSize: Int = 15
}

/// Factory: maps a variant to its recipe.
func ruleSet(for variant: PenteVariant) -> RuleSet {
    switch variant {
    case .pente:      return PenteRules()
    case .keryoPente: return KeryoPenteRules()
    case .gpente:     return GPenteRules()
    case .dPente:     return DPenteRules()
    case .dkPente:    return DKPenteRules()
    case .oPente:     return OPenteRules()
    case .poofPente:  return PoofPenteRules()
    case .swap2Pente: return Swap2PenteRules()
    case .swap2Keryo: return Swap2KeryoRules()
    case .gomoku:     return GomokuRules()
    case .connect6:   return Connect6Rules()
    case .renju:      return RenjuRules()
    }
}
