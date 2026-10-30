import XCTest
import UIKit
@testable import penteLive

/// DBBoardView drawn off-screen (no window): grid size, stones, heat, flash.
final class DBBoardViewTests: XCTestCase {
    private var cells = [Int32](repeating: 0, count: 361)

    private func render(_ view: DBBoardView) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return cells.withUnsafeMutableBufferPointer { buf -> UIImage in
            view.setAbstractBoard(UnsafeMutableRawPointer(buf.baseAddress!).assumingMemoryBound(to: AbstractBoard.self))
            defer { view.setAbstractBoard(nil) }
            return UIGraphicsImageRenderer(size: view.bounds.size, format: format).image { ctx in
                UIColor.white.setFill()
                ctx.fill(view.bounds)
                view.draw(view.bounds)
            }
        }
    }

    /// Brightness (0...1) at a point.
    private func brightness(_ image: UIImage, _ x: Int, _ y: Int) -> CGFloat {
        let cg = image.cgImage!
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
        return (CGFloat(px[0]) + CGFloat(px[1]) + CGFloat(px[2])) / (3 * 255)
    }

    private func board(grid: Int32, go: Bool = false, side: CGFloat = 180) -> DBBoardView {
        let v = DBBoardView(frame: CGRect(x: 0, y: 0, width: side, height: side))!
        v.gridSize = grid
        v.go = go
        return v
    }

    func testDefaultGridIsNineteen() {
        let v = DBBoardView(frame: CGRect(x: 0, y: 0, width: 190, height: 190))!
        XCTAssertEqual(v.gridSize, 0, "storyboard-style zero value")
        XCTAssertEqual(v.grid(), 19)
        v.startFlashingCell(360, stoneIsWhite: true, heat: .red)
        XCTAssertEqual(v.flashCell, 360)
        v.stopFlashing()
    }

    func testFlashGuardFollowsTheGrid() {
        let v = board(grid: 9)
        v.reduceMotionOverride = true
        v.startFlashingCell(81, stoneIsWhite: true, heat: .red)
        XCTAssertEqual(v.flashCell, -1, "the 9x9 pass sentinel never flashes")
        v.startFlashingCell(80, stoneIsWhite: true, heat: .red)
        XCTAssertEqual(v.flashCell, 80)
        v.stopFlashing()
        let r = board(grid: 15)
        r.reduceMotionOverride = true
        r.startFlashingCell(225, stoneIsWhite: false, heat: nil)
        XCTAssertEqual(r.flashCell, -1)
        r.startFlashingCell(224, stoneIsWhite: false, heat: nil)
        XCTAssertEqual(r.flashCell, 224)
        r.stopFlashing()
    }

    func testNineByNineStoneIsDrawnInItsCell() {
        // Cell 40 = row 4 col 4 on 9x9; stride-19 buffer index 4*19+4.
        cells[4 * 19 + 4] = 2
        let img = render(board(grid: 9, go: true))
        // 180 / 9 = 20 points per cell: row 4 col 4 spans 80...100. Samples
        // sit off the grid lines (lines run through cell centres).
        XCTAssertLessThan(brightness(img, 94, 94), 0.5, "black stone at the 9x9 centre")
        XCTAssertGreaterThan(brightness(img, 24, 24), 0.9, "row 1 col 1 is empty")
    }

    func testNineteenGridDoesNotDrawTheSameBufferAtNineByNineCells() {
        cells[4 * 19 + 4] = 2
        let img = render(board(grid: 0))
        // On 19x19 the stone sits near (42, 42), not at the board centre.
        XCTAssertGreaterThan(brightness(img, 94, 94), 0.9)
        XCTAssertLessThan(brightness(img, 42, 42), 0.5)
    }

    func testThirteenAndFifteenStoneCentres() {
        cells[12 * 19 + 12] = 2
        let img13 = render(board(grid: 13, go: true, side: 130))
        XCTAssertLessThan(brightness(img13, 125, 125), 0.5, "13x13 bottom-right corner")
        cells = [Int32](repeating: 0, count: 361)
        cells[7 * 19 + 7] = 2
        let img15 = render(board(grid: 15, side: 150))
        XCTAssertLessThan(brightness(img15, 75, 75), 0.5, "Renju H8")
    }

    func testOffBoardHeatAndPassLastMoveAreNotDrawn() {
        let v = board(grid: 9)
        v.lastMove = 81
        v.dbOptions = [NSNumber(value: 81): UIColor.black, NSNumber(value: 90): UIColor.black,
                       NSNumber(value: 10): UIColor.black]
        let img = render(v)
        // Off-board keys and the pass last-move are skipped (they would land
        // outside the 180-point image anyway); on-board heat still paints.
        XCTAssertLessThan(brightness(img, 24, 24), 0.5, "cell 10 = row 1 col 1 is painted")
        XCTAssertGreaterThan(brightness(img, 4, 4), 0.9)
        XCTAssertGreaterThan(brightness(img, 4, 176), 0.9)
    }
}
