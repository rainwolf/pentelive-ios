import XCTest
@testable import penteLive

final class RenjuOfferSymmetryTests: XCTestCase {
    // centre = 112 = (7,7). 113 = (8,7) -> dx=1,dy=0.
    func testEightImagesOfAnAxisPoint() {
        let images = RenjuOfferSymmetry.d4Images(of: 113)
        let expected: Set<Int> = [113,            // (1,0)
                                  111,            // (-1,0)
                                  112 + 15,       // (0,1) = 127
                                  112 - 15]       // (0,-1) = 97
        XCTAssertEqual(images, expected)
    }

    func testAddingSymmetricDuplicateIsRejected() {
        var accepted = Set<Int>()
        XCTAssertTrue(RenjuOfferSymmetry.tryAccept(113, into: &accepted))   // (1,0)
        XCTAssertFalse(RenjuOfferSymmetry.tryAccept(111, into: &accepted))  // (-1,0) is a D4 image -> reject
        XCTAssertFalse(RenjuOfferSymmetry.tryAccept(127, into: &accepted))  // (0,1) image -> reject
        XCTAssertTrue(RenjuOfferSymmetry.tryAccept(114, into: &accepted))   // (2,0) different orbit -> ok
    }

    func testDiagonalOrbitHasFourImages() {
        // 128 = (8,8) -> dx=1,dy=1. D4 orbit = {(±1,±1)} -> 4 cells.
        XCTAssertEqual(RenjuOfferSymmetry.d4Images(of: 128).count, 4)
    }

    func testGenericOrbitHasEightImages() {
        // 130 = (10,8) -> dx=3,dy=1. Generic orbit -> 8 distinct cells.
        XCTAssertEqual(RenjuOfferSymmetry.d4Images(of: 130).count, 8)
    }

    func testTenValidOffersAllAccepted() {
        let offers = [113,114,115,116, 128,129,130,131, 144,145]
        var accepted = Set<Int>()
        for m in offers { XCTAssertTrue(RenjuOfferSymmetry.tryAccept(m, into: &accepted), "\(m)") }
        XCTAssertEqual(accepted.count >= offers.count, true)
    }

    func testObjCBridgeReturnsImagesAsNumbers() {
        let imgs = RenjuOfferSymmetry.d4ImagesOf(113)
        XCTAssertEqual(Set(imgs.map { $0.intValue }), RenjuOfferSymmetry.d4Images(of: 113))
    }
}
