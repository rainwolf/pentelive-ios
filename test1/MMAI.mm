//
//  MMAI.mm
//  penteLive
//
//  Objective-C++ shim over the canonical C++ mmai engine (class CAi in
//  test1/mmai-core/Ai.{h,cpp}, synced from react_mmai commit ea15f28
//  "Add mobile portability seam to the engine").
//
//  This replaces the previous ~1764-line hand-ported Objective-C copy of the
//  engine. Behaviour is now identical to the canonical engine used by the
//  WASM/React and Android builds: each -getMove constructs a fresh CAi from the
//  current (game, level, useOpeningBook) and asks it for a move over the full
//  move list. NB: the canonical engine is much newer/stronger than the old
//  Obj-C port, so the moves it returns for Pente/Keryo will differ from the old
//  app — this is expected, not a regression.
//

#import <Foundation/Foundation.h>
#import "MMAI.h"
#import "mmai-core/Ai.h"

#include <memory>

@interface MMAI ()
// Private, only reached on a packaging error (tables missing from the bundle).
- (int)safeFallbackMove:(NSArray<NSNumber *> *)played;
@end

@implementation MMAI

@synthesize moves;
@synthesize useOpeningBook;
@synthesize seat;
@synthesize game;
@synthesize level;

- (instancetype)init {
    self = [super init];
    if (self) {
        moves = [[NSMutableArray alloc] init];
        // Mirror the old engine's defaults: opening book ON (old -init and
        // -reset both set obfl = 1). Default to a Pente game, first seat,
        // level 1; callers override via the properties before -getMove.
        useOpeningBook = YES;
        seat = 1;
        level = 1;
        game = 1;
    }
    return self;
}

// Directory holding pente.tbl / pente.scs / opngbk.pen. These are bundled as
// top-level app resources, so this is the bundle resource root (the directory
// that contains pente.tbl). The CAi constructor appends "/pente.tbl" etc.
// Computed once and cached (spec §2).
+ (const char *)filesDir {
    static NSString *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *tbl = [[NSBundle mainBundle] pathForResource:@"pente"
                                                        ofType:@"tbl"];
        cached = [tbl stringByDeletingLastPathComponent];
        if (cached == nil) {
            NSLog(@"[MMAI] pente.tbl not found in main bundle; CAi will try "
                  @"its default \"files\" directory.");
            cached = @"files";
        }
    });
    return [cached fileSystemRepresentation];
}

- (void)reset {
    // Mirror old semantics: fresh, empty move list. Every other piece of engine
    // state is rebuilt per -getMove inside a freshly constructed CAi.
    self.moves = [[NSMutableArray alloc] init];
}

- (void)addMove:(int)move {
    [self.moves addObject:[NSNumber numberWithInt:move]];
}

- (int)getMove {
    NSArray<NSNumber *> *snapshot = self.moves;
    int movesCount = (int)snapshot.count;

    // Marshal into a plain C array for the engine. Clamp defensively: CAi's
    // internal sx/sy/brd tables are sized for exactly 361 cells (a 19x19
    // board), so a move list longer than that -- or containing a corrupt
    // value outside the board -- must never reach CAi::getMove. Out-of-range
    // values are dropped (not clamped in place); anything dropped is logged
    // once here, not once per bad value.
    BOOL sawInvalid = (movesCount > 361);
    int *cmoves =
        (int *)malloc(sizeof(int) * (movesCount > 0 ? MIN(movesCount, 361) : 1));
    int marshaledCount = 0;
    for (int i = 0; i < movesCount && marshaledCount < 361; i++) {
        int v = [snapshot[i] intValue];
        if (v < 0 || v > 360) {
            sawInvalid = YES;
            continue;
        }
        cmoves[marshaledCount++] = v;
    }
    if (sawInvalid) {
        NSLog(@"[MMAI] *** move list had out-of-range or excess entries; "
              @"clipped to %d of %d before handing off to the engine. ***",
              marshaledCount, movesCount);
    }

    // Fresh engine per call: the canonical CAi has no incremental replay / no
    // setGame — it consumes the whole move list at once and derives the
    // side-to-move from move-count parity. `game` passes straight through (see
    // the mapping table in MMAI.h); `level` and the opening-book flag come from
    // the properties.
    int mv = 0;
    BOOL engineThrew = NO;
    try {
        // Heap-allocate: sizeof(CAi) is roughly 50KB (18 planes of a 19x19
        // board history plus search scratch state) and -getMove runs on a
        // detached NSThread with the platform default (~512KB) stack. A
        // stack-resident CAi would share that budget with the engine's own
        // recursive Tree()/Eval() search, risking a stack overflow;
        // std::unique_ptr keeps the engine object off the thread stack and
        // guarantees it is freed on every exit path, including an exception.
        std::unique_ptr<CAi> ai(new CAi(self.game, self.level,
                                         self.useOpeningBook ? true : false,
                                         [MMAI filesDir]));

        if (!ai->ok()) {
            // ctor could not open one or more of pente.tbl / pente.scs /
            // opngbk.pen under the bundle resource dir. Do not return an
            // engine move (the tables are uninitialised); return a safe
            // legal cell and shout about it in the log.
            NSLog(@"[MMAI] *** CAi LOAD FAILURE: pattern tables (pente.tbl / "
                  @"pente.scs / opngbk.pen) missing from the app bundle. "
                  @"Returning a SAFE FALLBACK move, not a real search result. "
                  @"***");
            mv = [self safeFallbackMove:snapshot];
        } else {
            mv = ai->getMove(cmoves, marshaledCount);
        }
    } catch (...) {
        // Any C++ exception out of construction or search (bad_alloc, a
        // corrupt table read, etc.) must not crash the AI thread. Fall back
        // to the same safe move used for the ok()==false case, below.
        engineThrew = YES;
    }
    free(cmoves);

    if (engineThrew) {
        NSLog(@"[MMAI] *** CAi threw a C++ exception during construction or "
              @"search; returning a SAFE FALLBACK move instead of crashing "
              @"the AI thread. ***");
        mv = [self safeFallbackMove:snapshot];
    }

    // Mirror the OLD Obj-C engine's -getMove side effect (test1/MMAI.m@main,
    // ~line 341): append the chosen move -- including a fallback move -- to
    // `moves` exactly once, unconditionally, immediately before returning.
    // MMAIViewController's -getNewAImove depends on exactly this: it
    // discards -getMove's return value and re-reads
    // [[aiPlayer moves] count] to decide how much of the board to replay.
    [self.moves addObject:[NSNumber numberWithInt:mv]];

    return mv;
}

// Deterministic legal cell for the (packaging-error only) case where the
// engine could not load its tables, or where construction/search threw:
// prefer the centre, otherwise the first empty cell.
//
// The final `return 180` below is reachable only if every one of the 361
// cells is already occupied -- i.e. a completely full 19x19 board. That
// cannot happen in practice: every supported variant ends the game (five in
// a row, a capture win, etc.) well before the board fills, so by the time
// -getMove could be called with 361 played moves the game is already over
// upstream of this shim. We still must return *some* on-board index to keep
// the "always append exactly one move" contract (see -getMove), so we
// return the centre rather than -1: -1 is not a legal board index and would
// corrupt the `moves` list that MMAIViewController's move-count-driven
// replay depends on.
- (int)safeFallbackMove:(NSArray<NSNumber *> *)played {
    BOOL occupied[361] = {NO};
    for (NSNumber *n in played) {
        int m = n.intValue;
        if (m >= 0 && m < 361) {
            occupied[m] = YES;
        }
    }
    if (!occupied[180]) {
        return 180; // centre of the 19x19 board
    }
    for (int m = 0; m < 361; m++) {
        if (!occupied[m]) {
            return m;
        }
    }
    // Unreachable in practice -- see comment above. Not a legal cell if we
    // truly get here, but it satisfies the "return an on-board index" and
    // "append exactly one move" contracts rather than returning -1.
    return 180;
}

@end
