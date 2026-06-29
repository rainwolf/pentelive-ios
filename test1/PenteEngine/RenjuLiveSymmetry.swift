import Foundation

/// Shape-relative D4 offer dedup for Branch-B fifth-move offers — mirrors the server's
/// RenjuState (positionStabilizer + applyTransform), the JSP mobileGame, the React
/// renjuSymmetry.js and the Android RenjuSymmetry.
///
/// Symmetry is computed about the PLACED-STONE SHAPE, not about the fixed board centre.
/// A symmetry is an affine map `g(p) = lin(p, r) + (tx, ty)` (a D4 linear part in ABSOLUTE
/// board coordinates plus an integer translation) that maps the coloured placed set onto
/// itself colour-for-colour. This catches mirror/rotation symmetries about an off-centre
/// point or axis that a centre-based rotate would miss — e.g. a 180° point rotation about
/// (6.5, 7). A candidate offer is a duplicate only when some such symmetry maps it onto an
/// already-offered point. When the shape is asymmetric the stabilizer is just the identity,
/// so only an EXACT repeat is rejected (unchanged from the old behaviour).
///
/// 15×15 board; index = x + y*size, x = idx % size, y = idx / size (integer division).
enum RenjuLiveSymmetry {
    static let size = 15
    private static let rotX = [1, 1, 1, 1, -1, -1, -1, -1]
    private static let rotY = [1, 1, -1, -1, -1, -1, 1, 1]
    private static let rotF = [0, 1, 0, 1, 0, 1, 0, 1]

    /// A symmetry transform: D4 op `r` (0..7) applied in absolute coords, then translate by (tx, ty).
    /// `Hashable` (synthesized) so transforms can be collected into a `Set` (used by tests and any
    /// caller deduping the stabilizer); declared in production to avoid a duplicate-conformance build
    /// error from a retroactive test-scope extension.
    struct Transform: Equatable, Hashable {
        let r: Int
        let tx: Int
        let ty: Int
        init(_ r: Int, _ tx: Int, _ ty: Int) { self.r = r; self.tx = tx; self.ty = ty }
    }

    /// Linear D4 part applied to ABSOLUTE coordinates (no centre offset).
    private static func lin(_ x: Int, _ y: Int, _ r: Int) -> (Int, Int) {
        var x1 = x * rotX[r]
        var y1 = y * rotY[r]
        if rotF[r] == 1 { Swift.swap(&x1, &y1) }
        return (x1, y1)
    }

    /// Image of `move` under transform `t`. Returns sentinel `-1` if the image leaves the
    /// board (bounds guard prevents row wraparound from producing a false duplicate).
    static func applyTransform(_ move: Int, _ t: Transform, size: Int = size) -> Int {
        let (lx, ly) = lin(move % size, move / size, t.r)
        let x = lx + t.tx
        let y = ly + t.ty
        if x >= 0 && x < size && y >= 0 && y < size { return x + y * size }
        return -1
    }

    /// The transforms `(r, tx, ty)` mapping the current coloured placed set onto itself.
    /// Always includes the identity; for an asymmetric shape it is exactly `{identity}`.
    static func stabilizer(_ valueAt: (Int) -> Int, size: Int = size) -> [Transform] {
        var placed: [(x: Int, y: Int, c: Int)] = []
        var colourAt: [Int: Int] = [:]
        for m in 0..<(size * size) {
            let v = valueAt(m)
            if v > 0 {
                placed.append((m % size, m / size, v))
                colourAt[m] = v
            }
        }
        let identity = Transform(0, 0, 0)
        guard let p0 = placed.first else { return [identity] }
        let c0 = p0.c

        var result: [Transform] = []
        for r in 0..<8 {
            let (l0x, l0y) = lin(p0.x, p0.y, r)
            for q in placed where q.c == c0 {
                let tx = q.x - l0x
                let ty = q.y - l0y
                var ok = true
                for p in placed {
                    let (lx, ly) = lin(p.x, p.y, r)
                    let x = lx + tx
                    let y = ly + ty
                    if x < 0 || x >= size || y < 0 || y >= size { ok = false; break }
                    if colourAt[x + y * size] != p.c { ok = false; break }
                }
                if ok {
                    let t = Transform(r, tx, ty)
                    if !result.contains(t) { result.append(t) }
                }
            }
        }
        if !result.contains(identity) { result.append(identity) }
        return result
    }

    /// True if `move` maps onto an already-offered point under some transform in `stab`.
    /// The stabilizer is a group (closed, with inverses) so this one-directional check is complete.
    static func isOfferDup(_ move: Int, offers: [Int], stab: [Transform], size: Int = size) -> Bool {
        let acc = Set(offers)
        for t in stab {
            let img = applyTransform(move, t, size: size)
            if img >= 0 && acc.contains(img) { return true }
        }
        return false
    }

    static func isSymmetricDup(_ move: Int, offers: [Int], valueAt: (Int) -> Int, size: Int = size) -> Bool {
        return isOfferDup(move, offers: offers, stab: stabilizer(valueAt, size: size), size: size)
    }
}
