import UIKit

enum DBHeatScale {
    static func displayed(_ moves: [DBNextMove], occupied: Set<Int>, limit: Int?) -> [DBNextMove] {
        let free = moves.filter { !occupied.contains($0.move) }
        let sorted = DBMoveRanking.sorted(free)
        guard let limit = limit else { return sorted }
        return Array(sorted.prefix(max(0, limit)))
    }

    static func rgb(winPct w: Double, min: Double, max: Double) -> (r: Int, g: Int, b: Int) {
        let lo: Double, span: Double
        if max == min { lo = 0; span = 100 } else { lo = min; span = max - min }
        let t = Swift.min(Swift.max((w - lo) / span, 0), 1)
        func clampC(_ v: Double) -> Int {
            Swift.min(255, Swift.max(0, Int(v.rounded(.toNearestOrAwayFromZero))))
        }
        if t <= 0.5 {
            return (255, clampC(510 * (w - lo) / span), 0)
        }
        return (clampC(510 * ((lo + span) - w) / span), 255, 0)
    }

    static func colors(for displayed: [DBNextMove]) -> [Int: UIColor] {
        guard let lo = displayed.map({ $0.winPct }).min(),
              let hi = displayed.map({ $0.winPct }).max() else { return [:] }
        var out: [Int: UIColor] = [:]
        for m in displayed {
            let c = rgb(winPct: m.winPct, min: lo, max: hi)
            out[m.move] = UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255,
                                  blue: CGFloat(c.b) / 255, alpha: 1)
        }
        return out
    }
}
