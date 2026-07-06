//
//  MMAI.h
//  penteLive
//
//  Created by rainwolf on 08/06/16.
//  Copyright © 2016 Triade. All rights reserved.
//
//  Thin Objective-C facade over the canonical C++ mmai engine
//  (test1/mmai-core/, synced from react_mmai commit ea15f28). The engine
//  proper lives in mmai-core/Ai.{h,cpp} (class CAi); the bridge that drives it
//  is MMAI.mm (Objective-C++). This header is deliberately kept pure
//  Objective-C so that the pure-.m clients (MMAIViewController,
//  DatabaseViewController) can keep importing it without pulling in C++.
//
//  ---------------------------------------------------------------------------
//  GAME ID MAPPING  (value of the `game` property / -setGame:, forwarded
//  verbatim to the CAi constructor, which derives its VariantConfig from it):
//
//     1  = Pente               (legacy VC value)
//     2  = Keryo-Pente         (legacy VC value; the canonical engine already
//                               maps 2 -> Keryo, so existing callers are
//                               unchanged)
//    11  = Poof-Pente          (canonical server ID; passes straight through)
//    13  = Connect6            (canonical server ID; packed return, see below)
//    15  = Boat-Pente          (canonical server ID)
//    25  = O-Pente             (canonical server ID)
//
//  Even IDs are "speed" twins with identical board rules. Today's callers only
//  ever pass 1 or 2; the higher IDs are engine-supported and pass through
//  unchanged, so a future variant-aware UI can select them without any change
//  to this shim.
//  ---------------------------------------------------------------------------
//  CONNECT6 (game == 13) PACKED RETURN VALUE: for Connect6, -getMove returns
//  TWO stones packed base-362 in a single int `p`:
//
//        first  stone:  m1 = p / 362
//        second stone:  m2 = p % 362      (m2 == 361 is the "no second stone"
//                                          sentinel)
//
//  Every other variant returns a single 0..360 board index (index = y*19 + x).
//  Connect6 IS wired end-to-end on this branch: MMAIViewController drives it
//  through -getMove (which unpacks and appends both stones -- see MMAI.mm)
//  and the two-stone turn cadence is reflected in its swipe-undo and
//  activeGame handling. This is documented here so a future caller in a
//  different screen (e.g. DatabaseViewController, which cannot currently
//  select game 13/14) knows to unpack the pair correctly before wiring in.
//  ---------------------------------------------------------------------------
//

#ifndef MMAI_h
#define MMAI_h

#endif /* MMAI_h */

@interface MMAI : NSObject {
    NSMutableArray<NSNumber *> *moves;
    BOOL useOpeningBook;
    int seat, level, game;
}
@property(retain, nonatomic, readwrite) NSMutableArray<NSNumber *> *moves;
@property(assign, atomic, readwrite, getter=useOpeningBook,
          setter=setUseOpeningBook:) BOOL useOpeningBook;
// `seat` is retained for source compatibility (callers still set it), but the
// canonical engine derives the side-to-move from the parity of the move count,
// so seat is advisory only and does NOT affect -getMove. Kept + documented per
// the integration spec (old code used it to pick a per-player search level; the
// canonical CAi takes a single `level`).
@property(assign, readwrite, atomic, setter=setSeat:, getter=seat) int seat;
@property(assign, readwrite, atomic) int game;
@property(assign, readwrite, atomic, setter=setLevel:, getter=level) int level;

- (void)reset;
- (void)addMove:(int)move;
- (int)getMove;

@end
