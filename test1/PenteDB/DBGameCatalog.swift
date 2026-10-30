import Foundation

/// Game ids and names for the PenteDB screen. Ids match
/// GridStateFactory.java: speed = base + 1, turn-based = +50.
@objc final class DBGameCatalog: NSObject {
    /// Web picker order (react_pentedb boardGeometry.js): each Go board size
    /// is its own game id.
    static let baseGames: [Int] = [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31]

    private static let names: [Int: String] = [
        1: "Pente", 3: "Keryo-Pente", 5: "Gomoku", 7: "D-Pente", 9: "G-Pente",
        11: "Poof-Pente", 13: "Connect6", 15: "Boat-Pente", 17: "DK-Pente",
        19: "Go", 21: "Go (9x9)", 23: "Go (13x13)",
        25: "O-Pente", 27: "Swap2-Pente", 29: "Swap2-Keryo", 31: "Renju",
    ]
    private static let speedPrefix = "Speed "

    /// Exact names only ("Go" never matches "Gomoku"). Unknown names (nil, "",
    /// "Tombstone", turn-based names) give 0, meaning "not supported".
    @objc static func gameId(forName name: String?) -> Int {
        guard var n = name, !n.isEmpty else { return 0 }
        var speed = false
        if n.hasPrefix(speedPrefix) {
            speed = true
            n = String(n.dropFirst(speedPrefix.count))
        }
        guard let base = names.first(where: { $0.value == n })?.key else { return 0 }
        return speed ? base + 1 : base
    }

    @objc static func name(forGame id: Int) -> String {
        let base = baseGame(id)
        guard let n = names[base] else { return "" }
        return isSpeed(id) ? speedPrefix + n : n
    }

    /// Strips the +50 turn-based offset and the +1 speed offset.
    @objc static func baseGame(_ id: Int) -> Int {
        var v = id
        if v > 50 { v -= 50 }
        return v % 2 == 0 ? v - 1 : v
    }

    @objc static func isSpeed(_ id: Int) -> Bool {
        var v = id
        if v > 50 { v -= 50 }
        return v > 0 && v % 2 == 0
    }

    @objc static func isSupported(_ id: Int) -> Bool {
        return baseGames.contains(baseGame(id))
    }

    @objc static func speedVariant(ofBase base: Int) -> Int { return base + 1 }

    /// Board side: 9 / 13 for small Go, 15 for Renju, else 19. Speed and
    /// turn-based twins are stripped first (71 is turn-based Go 9x9).
    @objc static func gridSize(forGame id: Int) -> Int {
        switch baseGame(id) {
        case 21: return 9
        case 23: return 13
        case 31: return 15
        default: return 19
        }
    }

    /// Go 19x19, 9x9 and 13x13.
    @objc static func isGo(_ id: Int) -> Bool {
        let b = baseGame(id)
        return b == 19 || b == 21 || b == 23
    }

    @objc static func isRenju(_ id: Int) -> Bool {
        return baseGame(id) == 31
    }

    /// Go and Renju: player 1 is black and moves first. Every other game
    /// starts with white.
    @objc static func blackMovesFirst(game id: Int) -> Bool {
        return isGo(id) || isRenju(id)
    }

    /// The line a fresh board starts from: empty for Go, else the centre
    /// stone (180 on 19x19, 112 on Renju's 15x15).
    @objc static func initialMoves(forGame id: Int) -> [NSNumber] {
        if isGo(id) { return [] }
        let g = gridSize(forGame: id)
        return [NSNumber(value: (g / 2) * g + g / 2)]
    }

    /// Board coordinate for `cell` on this game's grid ("PASS" for grid²,
    /// "" for junk outside 0...grid²).
    @objc static func moveLabel(cell: Int, game id: Int) -> String {
        let g = gridSize(forGame: id)
        guard cell >= 0, cell <= g * g else { return "" }
        return DBMoveRanking.label(cell: cell, gridSize: g)
    }

    /// False for Gomoku (5), Connect6 (13), Renju (31) and every unsupported
    /// id (unknown names map to 0). Go counts captured stones.
    @objc static func hasCaptures(game id: Int) -> Bool {
        guard isSupported(id) else { return false }
        let b = baseGame(id)
        return b != 5 && b != 13 && b != 31
    }

    /// Direct switch on the base id (no name-substring matching). Boat-Pente maps
    /// to `.pente`, as in BoardVariantMapping. Go and Renju also fall back to
    /// `.pente`: they never reach the Pente engine (DBBoardReplayer branches on
    /// `isGo`/`isRenju` first). Unsupported ids fall back to `.pente`; callers
    /// gate on `isSupported` first.
    static func variant(forGame id: Int) -> PenteVariant {
        switch baseGame(id) {
        case 1, 15: return .pente
        case 3: return .keryoPente
        case 5: return .gomoku
        case 7: return .dPente
        case 9: return .gpente
        case 11: return .poofPente
        case 13: return .connect6
        case 17: return .dkPente
        case 25: return .oPente
        case 27: return .swap2Pente
        case 29: return .swap2Keryo
        default: return .pente
        }
    }

    /// Speed-Swap2 is out of scope.
    static func supportsSpeed(base: Int) -> Bool {
        return base != 27 && base != 29
    }
}
