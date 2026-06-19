import Foundation

/// Stabilizer-based D4 offer dedup for Branch-B fifth-move offers — mirrors the server's
/// RenjuState.isSymmetricDuplicate (positionStabilizer + rotateMove) and react renjuSymmetry.js.
/// A candidate is a duplicate only if some symmetry that maps the PLACED stones onto themselves
/// also maps it onto an already-offered point. 15×15, centre index 112; index = x + y*size.
enum RenjuLiveSymmetry {
    static let size = 15
    private static let rotX = [1, 1, 1, 1, -1, -1, -1, -1]
    private static let rotY = [1, 1, -1, -1, -1, -1, 1, 1]
    private static let rotF = [0, 1, 0, 1, 0, 1, 0, 1]

    /// Image of `move` under D4 operation r (0..7), about the board centre.
    static func rotate(_ move: Int, _ r: Int, size: Int = size) -> Int {
        let off = size / 2
        let x = (move % size) - off
        let y = (move / size) - off
        var x1 = x * rotX[r]
        var y1 = y * rotY[r]
        if rotF[r] == 1 { Swift.swap(&x1, &y1) }
        return (x1 + off) + (y1 + off) * size
    }

    /// The operations (0..7) that map the current coloured position onto itself.
    static func stabilizer(_ valueAt: (Int) -> Int, size: Int = size) -> [Int] {
        var stab: [Int] = []
        for r in 0..<8 {
            var invariant = true
            var m = 0
            while m < size * size && invariant {
                let v = valueAt(m)
                if v > 0 && valueAt(rotate(m, r, size: size)) != v { invariant = false }
                m += 1
            }
            if invariant { stab.append(r) }
        }
        return stab
    }

    /// True if `move` maps onto an already-offered point under some op in `stab`.
    static func isOfferDup(_ move: Int, offers: [Int], stab: [Int], size: Int = size) -> Bool {
        let acc = Set(offers)
        return stab.contains { acc.contains(rotate(move, $0, size: size)) }
    }

    static func isSymmetricDup(_ move: Int, offers: [Int], valueAt: (Int) -> Int, size: Int = size) -> Bool {
        return isOfferDup(move, offers: offers, stab: stabilizer(valueAt, size: size), size: size)
    }
}
