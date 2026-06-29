import Foundation

/// @objc bridge that lets the turn-based opening UI (BoardViewController) dedup Branch-B
/// 5th-move offers using the SHAPE-RELATIVE symmetry of the current placed position.
///
/// This used to compute the full 8-fold D4 orbit about the FIXED board centre (7,7) with NO
/// stabilizer — i.e. it assumed the board was always fully symmetric and over-collapsed
/// EVERY opening, wrongly rejecting legal rotated/reflected offers. It is now a thin wrapper
/// around `RenjuLiveSymmetry` (the single, correct, shape-relative algorithm shared with the
/// live game room and mirrored from the server's RenjuState / JSP / React / Android ports):
/// two offers collide only when some symmetry that maps the 4 PLACED coloured stones onto
/// themselves maps one offer onto the other. When the placed shape is asymmetric the
/// stabilizer is just the identity, so only an EXACT repeat is rejected.
///
/// 15×15 board; flat index = x + y*size, x = idx % size, y = idx / size.
@objc final class RenjuOfferSymmetry: NSObject {
    /// True iff `candidate` duplicates one of `offers` under the stabilizer of the placed
    /// shape described by `board`.
    ///
    /// - Parameters:
    ///   - candidate: flat index of the offer being considered.
    ///   - offers: flat indices already picked.
    ///   - board: the current board as a flat array of length `size*size`; each cell is the
    ///     occupant value (0 empty, >0 a colour — e.g. 1 white / 2 black; negatives such as
    ///     masked cells are ignored). Only coloured (>0) cells define the placed shape.
    ///   - size: board edge length (15 for renju).
    @objc(wouldDuplicate:offers:board:size:)
    static func wouldDuplicate(_ candidate: Int,
                               offers: [NSNumber],
                               board: [NSNumber],
                               size: Int) -> Bool {
        let valueAt: (Int) -> Int = { idx in
            (idx >= 0 && idx < board.count) ? board[idx].intValue : 0
        }
        let stab = RenjuLiveSymmetry.stabilizer(valueAt, size: size)
        let offerInts = offers.map { $0.intValue }
        return RenjuLiveSymmetry.isOfferDup(candidate, offers: offerInts, stab: stab, size: size)
    }
}
