import Foundation

enum DBMoveRanking {
    static let lowSampleThreshold = 5
    private static let columns = Array("ABCDEFGHJKLMNOPQRST")

    static func wilsonLowerBound(wins: Int, games: Int) -> Double {
        guard games > 0 else { return 0 }
        let z = 1.96
        let n = Double(games)
        let p = Double(wins) / n
        let z2 = z * z
        let centre = p + z2 / (2 * n)
        let margin = z * ((p * (1 - p) + z2 / (4 * n)) / n).squareRoot()
        return (centre - margin) / (1 + z2 / n)
    }

    static func sorted(_ moves: [DBNextMove]) -> [DBNextMove] {
        let keyed = moves.enumerated().map { (i: $0.offset, m: $0.element,
            w: wilsonLowerBound(wins: $0.element.wins, games: $0.element.games)) }
        return keyed.sorted { a, b in
            let aHigh = a.m.games >= lowSampleThreshold
            let bHigh = b.m.games >= lowSampleThreshold
            if aHigh != bHigh { return aHigh }
            if a.w != b.w { return a.w > b.w }
            if a.m.games != b.m.games { return a.m.games > b.m.games }
            return a.i < b.i
        }.map { $0.m }
    }

    static func label(cell: Int, gridSize: Int) -> String {
        if cell == gridSize * gridSize { return "PASS" }
        let x = cell % gridSize
        let y = cell / gridSize
        let col = x < columns.count ? String(columns[x]) : "?"
        return "\(col)\(gridSize - y)"
    }
}
