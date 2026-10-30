import Foundation

/// Game ids and names for the PenteDB screen. Ids match
/// GridStateFactory.java: speed = base + 1, turn-based = +50.
@objc final class DBGameCatalog: NSObject {
    static let baseGames: [Int] = [1, 3, 5, 7, 9, 11, 13, 15, 17, 25, 27, 29]

    private static let names: [Int: String] = [
        1: "Pente", 3: "Keryo-Pente", 5: "Gomoku", 7: "D-Pente", 9: "G-Pente",
        11: "Poof-Pente", 13: "Connect6", 15: "Boat-Pente", 17: "DK-Pente",
        25: "O-Pente", 27: "Swap2-Pente", 29: "Swap2-Keryo",
    ]
    private static let speedPrefix = "Speed "

    /// Unknown names (Go, Renju, nil, "") give 0, meaning "not supported".
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

    @objc static func gridSize(forGame id: Int) -> Int { return 19 }

    /// False for Gomoku (5), Connect6 (13) and Renju (31).
    @objc static func hasCaptures(game id: Int) -> Bool {
        let b = baseGame(id)
        return b != 5 && b != 13 && b != 31
    }

    /// Direct switch on the base id (no name-substring matching). Boat-Pente maps
    /// to `.pente`, as in BoardVariantMapping. Unsupported ids fall back to `.pente`;
    /// callers gate on `isSupported` first.
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
