import XCTest
@testable import penteLive

final class RenjuLiveSymmetryTests: XCTestCase {
    private func board(_ occ: [Int: Int]) -> (Int) -> Int { { occ[$0] ?? 0 } }

    func testRotateCentreFixedAnd180() {
        XCTAssertEqual(RenjuLiveSymmetry.rotate(112, 0), 112)
        XCTAssertEqual(RenjuLiveSymmetry.rotate(112, 4), 112)
        XCTAssertEqual(RenjuLiveSymmetry.rotate(40, 4), 184)
        XCTAssertEqual(RenjuLiveSymmetry.rotate(184, 4), 40)
    }
    func testAsymmetricPositionIdentityStabilizer() {
        XCTAssertEqual(RenjuLiveSymmetry.stabilizer(board([112: 2, 129: 1])), [0])
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
}
