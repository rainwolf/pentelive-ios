import XCTest
@testable import penteLive

/// Shape-relative tests for the turn-based opening UI's @objc dedup bridge
/// (`RenjuOfferSymmetry.wouldDuplicate:offers:board:size:`), consistent with
/// renju_symmetry_spec.md. These exercise the ObjC-facing surface the BoardViewController
/// calls; the underlying algorithm is covered in depth by RenjuLiveSymmetryTests.
///
/// Regression position (m1..m4 = B,W,B,W), BLACK=2 / WHITE=1:
///   m1=(7,7)=112 BLACK, m2=(7,6)=97 WHITE, m3=(6,7)=111 BLACK, m4=(6,8)=126 WHITE.
/// Ground-truth stabilizer = { (0,0,0), (4,13,14) } (180° about (6.5,7): (x,y)->(13-x,14-y)).
final class RenjuOfferSymmetryTests: XCTestCase {
    private let size = 15

    /// A 15×15 board as a flat [NSNumber] from an occupancy map (idx -> colour).
    private func board(_ occ: [Int: Int]) -> [NSNumber] {
        var b = Array(repeating: 0, count: size * size)
        for (k, v) in occ { b[k] = v }
        return b.map { NSNumber(value: $0) }
    }
    private func nums(_ xs: [Int]) -> [NSNumber] { xs.map { NSNumber(value: $0) } }
    private func dup(_ candidate: Int, _ offers: [Int], _ b: [NSNumber]) -> Bool {
        RenjuOfferSymmetry.wouldDuplicate(candidate, offers: nums(offers), board: b, size: size)
    }

    private var regression: [NSNumber] { board([112: 2, 97: 1, 111: 2, 126: 1]) }

    // 1. Dedup now fires: each mirror pair collides in both directions; first of a pair is
    //    accepted against an empty offer list.
    func testMirrorPairsAreRejected() {
        let b = regression
        let pairs: [(Int, Int)] = [
            (68, 155), // (8,4) <-> (5,10)
            (81, 142), // (6,5) <-> (7,9)
            (95, 128), // (5,6) <-> (8,8)
            (144, 79), // (9,9) <-> (4,5)
        ]
        for (a, p) in pairs {
            XCTAssertFalse(dup(a, [], b), "first \(a) should be accepted")
            XCTAssertTrue(dup(p, [a], b), "\(p) should be a dup of \(a)")
            XCTAssertTrue(dup(a, [p], b), "\(a) should be a dup of \(p)")
        }
    }

    // 2. No over-collapse: an asymmetric shape (m4 moved to (5,8)=125) has only the identity
    //    stabilizer, so mirror points are BOTH accepted; only an exact repeat is rejected.
    func testAsymmetricControlNoOverCollapse() {
        let b = board([112: 2, 97: 1, 111: 2, 125: 1])
        XCTAssertFalse(dup(68, [], b))
        XCTAssertFalse(dup(155, [68], b)) // would be a dup in the symmetric position; here it is not
        XCTAssertTrue(dup(68, [68], b))   // exact repeat still rejected
    }

    // 3. Bounds guard: (14,14)=224's 180° image (-1,0) leaves the board -> sentinel, never a
    //    false duplicate.
    func testBoundsGuardNoFalseDup() {
        let b = regression
        XCTAssertFalse(dup(224, [32], b))
        XCTAssertFalse(dup(32, [224], b))
    }

    // 3b. TRUE row-wraparound — load-bearing for the PER-AXIS 0<=X<N guard. Offer (14,13)=209;
    //     candidate (14,0)=14. Under the non-identity op (4,13,14): lin_r4(14,0)=(-14,0); +(13,14)
    //     =(-1,14). X=-1 off-board -> sentinel -> (14,0) ACCEPTED. Without the per-axis guard the
    //     naive flat index (-1)+(14*15)=209 == the offer -> (14,0) would be FALSELY rejected.
    func testBoundsGuardRowWraparoundNotFalseDup() {
        let b = regression
        XCTAssertFalse(dup(14, [209], b), "(14,0)=14 must not wrap onto (14,13)=209")
        XCTAssertFalse(dup(209, [14], b), "(14,13)=209 must not wrap onto (14,0)=14")
    }

    // 4. A valid 10-offer set (10 distinct orbits) is fully accepted.
    func testValidTenOfferSetFullyAccepted() {
        let b = regression
        var accepted: [Int] = []
        for m in 0..<10 {
            XCTAssertFalse(dup(m, accepted, b), "\(m) wrongly flagged as duplicate")
            accepted.append(m)
        }
        XCTAssertEqual(accepted.count, 10)
    }

    // 4b. Masked cells (-1) forwarded by BoardViewController are ignored (only >0 cells define the
    //     placed shape). The regression board with several empty cells set to -1 keeps the SAME
    //     stabilizer, so mirror pairs are still deduped exactly as in `testMirrorPairsAreRejected`.
    //     Fails if the placed-stone test is loosened from `v > 0` to `v != 0`.
    func testMaskedNegativeCellsIgnored() {
        let b = board([112: 2, 97: 1, 111: 2, 126: 1,
                       0: -1, 14: -1, 50: -1, 200: -1, 224: -1])
        // Mirror pair (8,4)=68 <-> (5,10)=155 under (4,13,14) still collides both ways.
        XCTAssertFalse(dup(68, [], b), "first 68 should be accepted")
        XCTAssertTrue(dup(155, [68], b), "155 should be a dup of 68 despite masked cells")
        XCTAssertTrue(dup(68, [155], b), "68 should be a dup of 155 despite masked cells")
    }

    // 5. Empty board (no placed stones) -> identity-only stabilizer -> only exact repeats clash.
    func testEmptyBoardOnlyExactRepeat() {
        let b = board([:])
        XCTAssertFalse(dup(111, [], b))
        XCTAssertFalse(dup(111, [113], b)) // pure D4 image of 113 about (7,7) — NOT collapsed now
        XCTAssertTrue(dup(111, [111], b))
    }
}
