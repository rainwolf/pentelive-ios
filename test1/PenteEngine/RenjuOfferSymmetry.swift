import Foundation

/// Client-side D4 symmetry dedup for Branch-B 5th-move offers (15×15, centre (7,7)).
/// Mirrors the server's renjuRotate/renjuStabilizer/renjuIsSymmetricDup so the client
/// agrees with `offerFifthMove`. UX nicety only — the server rejects violations anyway.
@objc final class RenjuOfferSymmetry: NSObject {
    static let size = 15
    static let centre = 7   // (7,7) on a 15×15 board

    /// The set of D4 images (rotations + reflections) of `move`, INCLUDING `move` itself.
    /// Off-board images are dropped (cannot occur for in-bounds offers, but safe).
    static func d4Images(of move: Int) -> Set<Int> {
        let x = move % size, y = move / size
        let dx = x - centre, dy = y - centre
        let orbits: [(Int, Int)] = [
            ( dx,  dy), (-dy,  dx), (-dx, -dy), ( dy, -dx),   // rotations
            (-dx,  dy), ( dx, -dy), ( dy,  dx), (-dy, -dx),   // reflections
        ]
        var out = Set<Int>()
        for (tx, ty) in orbits {
            let cx = tx + centre, cy = ty + centre
            guard cx >= 0, cx < size, cy >= 0, cy < size else { continue }
            out.insert(cy * size + cx)
        }
        return out
    }

    /// True if `move` shares no D4 image with any already-accepted offer; on success it
    /// records `move`'s images into `accepted` and returns true.
    static func tryAccept(_ move: Int, into accepted: inout Set<Int>) -> Bool {
        let images = d4Images(of: move)
        if !accepted.isDisjoint(with: images) { return false }
        accepted.formUnion(images)
        return true
    }

    /// @objc bridge for the Objective-C opening UI: the D4 images of `move` as NSNumbers.
    @objc(d4ImagesOf:)
    static func d4ImagesOf(_ move: Int) -> [NSNumber] {
        return d4Images(of: move).map { NSNumber(value: $0) }
    }
}
