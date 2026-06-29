import XCTest
@testable import penteLive

/// Tests for the shared shape-relative D4 symmetry engine `RenjuLiveSymmetry`
/// (renju_symmetry_spec.md). Consolidates the former RenjuLiveSymmetryTests (core
/// transform/stabilizer behaviour) and RenjuLiveShapeSymmetryTests (the off-centre
/// regression position from the user's screenshot) into one file.
///
/// Regression position (m1..m4 = B,W,B,W), BLACK=2 / WHITE=1:
///   m1=(7,7)=112 BLACK, m2=(7,6)=97 WHITE, m3=(6,7)=111 BLACK, m4=(6,8)=126 WHITE.
/// BLACK = {(7,7),(6,7)}, WHITE = {(7,6),(6,8)}.
/// Ground-truth stabilizer = { (0,0,0), (4,13,14) } (180° about (6.5,7): (x,y)->(13-x,14-y)).
/// The old centre-based code yields {identity} here and would wrongly accept mirror pairs.
final class RenjuLiveSymmetryTests: XCTestCase {
    private func board(_ occ: [Int: Int]) -> (Int) -> Int { { occ[$0] ?? 0 } }
    private func idx(_ x: Int, _ y: Int) -> Int { x + y * 15 }
    private let identity = RenjuLiveSymmetry.Transform(0, 0, 0)

    // BLACK=2, WHITE=1
    private var regression: (Int) -> Int {
        board([112: 2, 97: 1, 111: 2, 126: 1])
    }

    // MARK: - Core transform behaviour

    func testApplyTransformIdentityAnd180() {
        let t180 = RenjuLiveSymmetry.Transform(4, 14, 14) // 180° about centre (7,7)
        XCTAssertEqual(RenjuLiveSymmetry.applyTransform(112, identity), 112)
        XCTAssertEqual(RenjuLiveSymmetry.applyTransform(112, t180), 112)
        XCTAssertEqual(RenjuLiveSymmetry.applyTransform(40, t180), 184)
        XCTAssertEqual(RenjuLiveSymmetry.applyTransform(184, t180), 40)
    }

    func testApplyTransformBoundsGuard() {
        // 180° about (6.5,7): (x,y) -> (13-x, 14-y). (14,14)=224 -> (-1,0) off board -> -1.
        let t = RenjuLiveSymmetry.Transform(4, 13, 14)
        XCTAssertEqual(RenjuLiveSymmetry.applyTransform(224, t), -1)
    }

    // MARK: - Stabilizer of simple shapes

    func testAsymmetricPositionIdentityStabilizer() {
        XCTAssertEqual(RenjuLiveSymmetry.stabilizer(board([112: 2, 129: 1])), [identity])
    }

    func testAsymmetricOnlyExactDup() {
        let v = board([112: 2, 129: 1])
        XCTAssertFalse(RenjuLiveSymmetry.isSymmetricDup(184, offers: [40], valueAt: v))
        XCTAssertTrue(RenjuLiveSymmetry.isSymmetricDup(40, offers: [40], valueAt: v))
    }

    func testSymmetricPositionRejectsRotations() {
        let v = board([112: 2]) // lone centre -> full D4
        XCTAssertEqual(RenjuLiveSymmetry.stabilizer(v).count, 8)
        XCTAssertTrue(RenjuLiveSymmetry.isSymmetricDup(184, offers: [40], valueAt: v))
        XCTAssertFalse(RenjuLiveSymmetry.isSymmetricDup(56, offers: [40], valueAt: v))
    }

    func testSingleAxisSymmetryTwoElementStabilizer() {
        let v = board([112: 2, 127: 1]) // vertical-axis symmetry
        let stab = RenjuLiveSymmetry.stabilizer(v)
        XCTAssertEqual(stab.count, 2)
        XCTAssertTrue(RenjuLiveSymmetry.isOfferDup(94, offers: [100], stab: stab))
        XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(158, offers: [100], stab: stab))
    }

    // MARK: - Off-centre regression position (the bug)

    func testStabilizerIsExactlyIdentityAnd180() {
        let stab = RenjuLiveSymmetry.stabilizer(regression)
        let expected: Set<RenjuLiveSymmetry.Transform> = [
            RenjuLiveSymmetry.Transform(0, 0, 0),
            RenjuLiveSymmetry.Transform(4, 13, 14),
        ]
        XCTAssertEqual(Set(stab), expected)
    }

    /// Masked cells (-1) are ignored — only coloured (>0) cells define the placed shape, matching
    /// RenjuOfferSymmetry's @objc contract (BoardViewController forwards abstractBoard's -1 masked
    /// cells). The regression board with several empty cells set to -1 must yield the SAME
    /// stabilizer {(0,0,0),(4,13,14)}. Fails if the placed-stone test is loosened from `v > 0` to `v != 0`.
    func testMaskedNegativeCellsIgnoredInStabilizer() {
        let masked = board([
            112: 2, 97: 1, 111: 2, 126: 1, // the 4 placed stones
            0: -1, 14: -1, 50: -1, 200: -1, 224: -1, // masked empties scattered around
        ])
        let stab = RenjuLiveSymmetry.stabilizer(masked)
        let expected: Set<RenjuLiveSymmetry.Transform> = [
            RenjuLiveSymmetry.Transform(0, 0, 0),
            RenjuLiveSymmetry.Transform(4, 13, 14),
        ]
        XCTAssertEqual(Set(stab), expected)
    }

    func testMirrorPairsAreRejected() {
        let stab = RenjuLiveSymmetry.stabilizer(regression)
        let pairs: [(Int, Int)] = [
            (idx(8, 4), idx(5, 10)), // 68  <-> 155
            (idx(6, 5), idx(7, 9)),  // 81  <-> 142
            (idx(5, 6), idx(8, 8)),  // 95  <-> 128
            (idx(9, 9), idx(4, 5)),  // 144 <-> 79
        ]
        for (a, b) in pairs {
            XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(a, offers: [], stab: stab), "first \(a) accepted")
            XCTAssertTrue(RenjuLiveSymmetry.isOfferDup(b, offers: [a], stab: stab), "\(b) should be dup of \(a)")
            XCTAssertTrue(RenjuLiveSymmetry.isOfferDup(a, offers: [b], stab: stab), "\(a) should be dup of \(b)")
        }
    }

    func testAsymmetricControlNoOverCollapse() {
        // Replace m4 (6,8) with (5,8) WHITE -> shape asymmetric -> stabilizer == {identity}.
        let asym = board([112: 2, 97: 1, 111: 2, idx(5, 8): 1])
        XCTAssertEqual(RenjuLiveSymmetry.stabilizer(asym), [identity])
        let stab = RenjuLiveSymmetry.stabilizer(asym)
        let a = idx(8, 4), b = idx(5, 10) // 68, 155
        XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(a, offers: [], stab: stab))
        XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(b, offers: [a], stab: stab)) // BOTH accepted
        XCTAssertTrue(RenjuLiveSymmetry.isOfferDup(a, offers: [a], stab: stab))  // only exact repeat
    }

    func testBoundsGuardNoFalseDup() {
        let stab = RenjuLiveSymmetry.stabilizer(regression)
        // (14,14)=224 -> 180° image (-1,0) off board -> sentinel -1, must not match anything.
        let far = idx(14, 14)     // 224
        let unrelated = idx(2, 2) // 32, whose image (11,12)=191 != 224
        XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(far, offers: [unrelated], stab: stab))
        XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(unrelated, offers: [far], stab: stab))
    }

    /// TRUE row-wraparound case — load-bearing for the PER-AXIS `0<=X<N` guard (not the flat
    /// `image < 0` sentinel). Offer (14,13)=209; candidate (14,0)=14. Under the stabilizer's
    /// non-identity op (4,13,14): lin_r4(14,0)=(-14,0); +(13,14)=(-1,14). X=-1 is off-board, so
    /// the per-axis guard yields the sentinel and (14,0) is ACCEPTED. WITHOUT the per-axis guard
    /// the naive flat index (-1)+(14*15)=209 == the prior offer -> (14,0) would be FALSELY rejected.
    func testBoundsGuardRowWraparoundNotFalseDup() {
        let stab = RenjuLiveSymmetry.stabilizer(regression)
        let offer = idx(14, 13)     // 209 (empty in the regression position)
        let candidate = idx(14, 0)  // 14  (empty)
        XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(candidate, offers: [offer], stab: stab),
                       "(14,0)=14 must not wrap-around onto (14,13)=209")
        XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(offer, offers: [candidate], stab: stab),
                       "(14,13)=209 must not wrap-around onto (14,0)=14")
    }

    func testValidTenOfferSetFullyAccepted() {
        let stab = RenjuLiveSymmetry.stabilizer(regression)
        // 10 points in distinct orbits (no two related by (4,13,14)).
        let offers = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        var accepted: [Int] = []
        for m in offers {
            XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(m, offers: accepted, stab: stab), "\(m) wrongly dup")
            accepted.append(m)
        }
        XCTAssertEqual(accepted.count, 10)
    }
}
