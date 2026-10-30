import UIKit

struct DBMoveRow: Equatable {
    var cell: Int
    var label: String
    var pctText: String
    var barFraction: Double
    var gamesText: String
    var color: UIColor
}

enum DBMovesViewModel {
    /// 0 means All.
    static let showOptions: [Int] = [10, 20, 40, 0]

    static func rows(stats: DBPositionStats, occupied: Set<Int>, limit: Int?, game: Int,
                     sort: DBMoveSort = .winRate, locale: Locale = .current) -> [DBMoveRow] {
        let grid = DBGameCatalog.gridSize(forGame: game)
        let displayed = DBHeatScale.displayed(stats.nextMoves, occupied: occupied, limit: limit,
                                              sort: sort, gridSize: grid)
        let colors = DBHeatScale.colors(for: displayed)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return displayed.map { m in
            DBMoveRow(
                cell: m.move,
                label: DBMoveRanking.label(cell: m.move, gridSize: grid),
                pctText: "\(Int(m.winPct.rounded()))%",
                barFraction: min(1, max(0, m.winPct / 100)),
                gamesText: formatter.string(from: NSNumber(value: m.games)) ?? "\(m.games)",
                color: colors[m.move] ?? .clear)
        }
    }
}
