import Foundation

/// Builders for the three live Renju opening events. Keys are byte-for-byte the server contract
/// (note the asymmetric "10": Offer10 vs Taraguchi10Select1). Outbound always carries time:0.
enum RenjuWire {
    static func swap(swap: Bool, move: Int, player: String, table: Int) -> [String: Any] {
        ["dsgRenjuTaraguchiSwapTableEvent": ["swap": swap, "move": move, "player": player, "table": table, "time": 0] as [String: Any]]
    }
    static func offer10(moves: [Int], player: String, table: Int) -> [String: Any] {
        ["dsgRenjuTaraguchiOffer10TableEvent": ["moves": moves, "player": player, "table": table, "time": 0] as [String: Any]]
    }
    static func select1(move: Int, player: String, table: Int) -> [String: Any] {
        ["dsgRenjuTaraguchi10Select1TableEvent": ["move": move, "player": player, "table": table, "time": 0] as [String: Any]]
    }
}
