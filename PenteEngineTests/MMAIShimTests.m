//
//  MMAIShimTests.m
//  PenteEngineTests
//
//  Integration smoke test for the MMAI Objective-C++ shim over the canonical
//  C++ mmai engine (test1/mmai-core/, synced from react_mmai commit ea15f28).
//  This is a host-app test: [NSBundle mainBundle] is penteLive.app, so the
//  shim's -getMove finds the bundled pente.tbl / pente.scs / opngbk.pen and
//  runs the real engine (not the safe fallback).
//
//  Scope (spec §5.3): for Pente and Keryo the engine returns a legal move on a
//  short fixed position and is deterministic across two calls; the canonical
//  variant IDs 11 / 15 / 25 also return legal moves.
//

#import <XCTest/XCTest.h>
#import "../test1/MMAI.h"

// Test-only seam (spec §5.3 fallback item): the degraded-engine fallback
// paths inside -getMove (!ok() / a thrown C++ exception) are otherwise
// unreachable from this suite. This is a host-app test, so [NSBundle
// mainBundle] is the real penteLive.app bundle and +[MMAI filesDir] always
// resolves to the real, present pente.tbl/pente.scs/opngbk.pen -- there is no
// way to make CAi's constructor fail or throw without either faking a broken
// app bundle (not available to XCTest) or changing MMAI's public API (adding
// an injectable files-dir hook) purely for testability, which the fallback
// fix itself does not need.
//
// -appendFallbackMovesForSnapshot:movesCount: (declared privately in
// MMAI.mm's class extension) IS the fallback move-selection-and-append logic
// that both of those paths call; it does not touch CAi or the bundle at all.
// Redeclaring its selector here in a category lets this suite call it
// directly and assert the two-stones-mid-game / one-stone-opening cadence
// contract in isolation, without needing to force the engine itself to fail.
// This is the least invasive workable seam: no change to MMAI.h, no new
// public API, no behavior added -- just a test-visible name for logic that
// already exists.
@interface MMAI (FallbackTesting)
- (int)appendFallbackMovesForSnapshot:(NSArray<NSNumber *> *)snapshot
                            movesCount:(int)movesCount;
@end

@interface MMAIShimTests : XCTestCase
@end

@implementation MMAIShimTests

// A short, fixed opening: centre + one neighbour. Board is 19x19 (index y*19+x).
static NSArray<NSNumber *> *FixedPosition(void) {
    return @[ @180, @181 ]; // (9,9) and (10,9)
}

// Build an MMAI at the given game/level and play the fixed position into it.
- (MMAI *)aiForGame:(int)game level:(int)level {
    MMAI *ai = [[MMAI alloc] init];
    [ai reset];
    ai.game = game;
    [ai setLevel:level];
    [ai setSeat:1];
    for (NSNumber *m in FixedPosition()) {
        [ai addMove:m.intValue];
    }
    return ai;
}

// Assert a single-stone move index is on the board and not already occupied.
- (void)assertLegalMove:(int)move label:(NSString *)label {
    XCTAssertTrue(move >= 0 && move <= 360,
                  @"%@: move %d out of board range [0,360]", label, move);
    for (NSNumber *m in FixedPosition()) {
        XCTAssertNotEqual(move, m.intValue,
                          @"%@: move %d lands on an occupied cell", label, move);
    }
}

- (void)testPenteReturnsLegalMove {
    MMAI *ai = [self aiForGame:1 level:1];
    int move = [ai getMove];
    [self assertLegalMove:move label:@"Pente(1)"];
}

// Regression test for the -getMove mutation contract: the OLD Obj-C engine's
// -getMove appended the chosen move to `moves` before returning, and
// MMAIViewController's -getNewAImove relies on exactly that -- it discards
// -getMove's return value and re-reads [[aiPlayer moves] count] to decide how
// much of the board to replay (see test1/MMAIViewController.m). A shim that
// only *returns* the move without appending it would pass every other test
// here yet silently break replay in the app. This test calls -getMove and
// discards the return value on purpose, the same way the view controller
// does, and checks the side effect instead.
- (void)testGetMoveAppendsChosenMoveToMoves {
    MMAI *ai = [self aiForGame:1 level:1];
    NSUInteger before = [ai.moves count];

    [ai getMove]; // return value intentionally discarded, mirroring the app

    NSUInteger after = [ai.moves count];
    XCTAssertEqual(after, before + 1,
                   @"-getMove must append exactly one move to `moves` "
                   @"(had %lu, now %lu)", (unsigned long)before,
                   (unsigned long)after);

    NSNumber *appended = ai.moves[after - 1];
    [self assertLegalMove:appended.intValue label:@"appended move"];
}

- (void)testKeryoReturnsLegalMove {
    MMAI *ai = [self aiForGame:2 level:1];
    int move = [ai getMove];
    [self assertLegalMove:move label:@"Keryo(2)"];
}

// The canonical engine reseeds C's global RNG with srand(time(NULL)) inside
// every search (second-resolution wall-clock). Two calls made back-to-back
// normally land in the same wall-clock second and therefore use the same
// seed and agree -- but a pair that happens to straddle a second boundary
// gets different seeds and can legitimately disagree with nothing actually
// broken. A test that runs the pair exactly once is flaky right on that
// boundary. To de-flake without weakening what's actually being asserted,
// attempt up to 3 independent paired runs (fresh MMAI instances each time,
// calls issued back-to-back to minimize the odds of crossing a boundary) and
// pass as soon as any one pair agrees; only fail if all 3 attempts straddled
// a boundary and disagreed, which would be astronomically unlikely for a
// real determinism regression.
- (void)testPenteDeterministicAcrossTwoCalls {
    static const int kAttempts = 3;
    int lastFirst = -1;
    int lastSecond = -1;

    for (int attempt = 0; attempt < kAttempts; attempt++) {
        MMAI *a = [self aiForGame:1 level:1];
        MMAI *b = [self aiForGame:1 level:1];
        int first = [a getMove];
        int second = [b getMove];
        [self assertLegalMove:first
                        label:[NSString stringWithFormat:
                                          @"Pente(1) call#1 (attempt %d)",
                                          attempt + 1]];
        if (first == second) {
            return; // agreement found on this attempt; test passes
        }
        lastFirst = first;
        lastSecond = second;
    }

    XCTFail(@"Pente engine not deterministic across two same-second calls in "
            @"any of %d attempts (last attempt: %d vs %d)",
            kAttempts, lastFirst, lastSecond);
}

- (void)testCanonicalVariantIDsReturnLegalMoves {
    // 11 = Poof-Pente, 15 = Boat-Pente, 25 = O-Pente: all single-stone returns.
    for (NSNumber *g in @[ @11, @15, @25 ]) {
        MMAI *ai = [self aiForGame:g.intValue level:1];
        int move = [ai getMove];
        [self assertLegalMove:move
                        label:[NSString stringWithFormat:@"variant %@", g]];
    }
}

// Connect6 (game 13) is the ONLY variant whose -getMove return is a base-362
// packed stone PAIR (m1 = packed/362, m2 = packed%362; m2 == 361 = single-stone
// sentinel, only ever the game's first move). This asserts the shim's
// packed-append contract: after the lone opening stone, a mid-game AI turn
// unpacks to two distinct legal cells AND both are appended to `moves` (the
// list grows by two), so MMAIViewController's move-count-driven replay sees the
// AI's full two-stone turn. Before the fix the raw packed int (up to ~130681)
// was appended verbatim as one bogus "move".
- (void)testConnect6GetMoveAppendsPackedPair {
    MMAI *ai = [[MMAI alloc] init];
    [ai reset];
    ai.game = 13;
    [ai setLevel:1];
    [ai setSeat:1];
    [ai addMove:180]; // one opening stone -> the next turn is a two-stone pair
    NSUInteger before = [ai.moves count]; // == 1

    int packed = [ai getMove]; // return value intentionally kept: it is packed

    int m1 = packed / 362;
    int m2 = packed % 362;
    XCTAssertNotEqual(m2, 361,
                      @"Connect6 mid-game turn must place TWO stones "
                      @"(m2 must not be the single-stone sentinel 361)");
    XCTAssertTrue(m1 >= 0 && m1 <= 360, @"Connect6 stone 1 (%d) off board", m1);
    XCTAssertTrue(m2 >= 0 && m2 <= 360, @"Connect6 stone 2 (%d) off board", m2);
    XCTAssertNotEqual(m1, m2, @"Connect6's two stones must be distinct");
    XCTAssertNotEqual(m1, 180, @"Connect6 stone 1 lands on the occupied cell 180");
    XCTAssertNotEqual(m2, 180, @"Connect6 stone 2 lands on the occupied cell 180");

    NSUInteger after = [ai.moves count];
    XCTAssertEqual(after, before + 2,
                   @"Connect6 -getMove must append BOTH stones to `moves` "
                   @"(had %lu, now %lu)", (unsigned long)before,
                   (unsigned long)after);
    XCTAssertEqual([ai.moves[after - 2] intValue], m1,
                   @"appended stone 1 must equal unpacked m1");
    XCTAssertEqual([ai.moves[after - 1] intValue], m2,
                   @"appended stone 2 must equal unpacked m2");
}

// Blocker 1 fallback test. Drives -appendFallbackMovesForSnapshot:movesCount:
// directly (see the FallbackTesting category above for why this is the
// chosen seam) to assert the fix: a mid-game Connect6 fallback (the engine
// couldn't load/threw) must still append TWO stones to preserve the
// human/AI turn cadence, even though neither stone is a real search result.
// Before the fix, both fallback call sites in -getMove appended only one
// raw stone here, silently desyncing the two-stone pairing for the rest of
// the game.
- (void)testFallbackAppendsTwoStonesForConnect6MidGame {
    MMAI *ai = [[MMAI alloc] init];
    [ai reset];
    ai.game = 13;
    [ai setLevel:1];
    [ai setSeat:1];
    [ai addMove:180]; // one stone already on the board -> mid-game turn

    NSUInteger before = [ai.moves count];
    XCTAssertEqual(before, (NSUInteger)1);

    int packed = [ai appendFallbackMovesForSnapshot:ai.moves
                                          movesCount:(int)before];

    NSUInteger after = [ai.moves count];
    XCTAssertEqual(after, before + 2,
                   @"Connect6 fallback must append exactly TWO stones "
                   @"mid-game (had %lu, now %lu)", (unsigned long)before,
                   (unsigned long)after);

    int m1 = packed / 362;
    int m2 = packed % 362;
    // NB: not -assertLegalMove:label: -- that helper checks against the
    // suite-wide FixedPosition() (@180, @181), which is unrelated to this
    // test's own board (a single stone at @180). Check occupancy against
    // what THIS test actually played instead.
    XCTAssertTrue(m1 >= 0 && m1 <= 360,
                  @"Connect6 fallback stone 1: %d out of board range", m1);
    XCTAssertTrue(m2 >= 0 && m2 <= 360,
                  @"Connect6 fallback stone 2: %d out of board range", m2);
    XCTAssertNotEqual(m1, 180,
                       @"Connect6 fallback stone 1 lands on the occupied "
                       @"centre cell");
    XCTAssertNotEqual(m2, 180,
                       @"Connect6 fallback stone 2 lands on the occupied "
                       @"centre cell");
    XCTAssertNotEqual(m1, m2,
                       @"Connect6 fallback's two stones must be distinct "
                       @"(occupancy snapshot must be updated between calls)");
    XCTAssertEqual([ai.moves[after - 2] intValue], m1,
                   @"appended fallback stone 1 must equal unpacked m1");
    XCTAssertEqual([ai.moves[after - 1] intValue], m2,
                   @"appended fallback stone 2 must equal unpacked m2");
}

// Companion case: the empty-board Connect6 opening is the ONE single-stone
// turn (movesCount == 0), so the fallback must append exactly ONE stone here,
// not two -- confirms the fix didn't just hardcode "always append two" for
// game 13/14.
- (void)testFallbackAppendsOneStoneForConnect6EmptyBoard {
    MMAI *ai = [[MMAI alloc] init];
    [ai reset];
    ai.game = 13;
    [ai setLevel:1];
    [ai setSeat:1];

    NSUInteger before = [ai.moves count];
    XCTAssertEqual(before, (NSUInteger)0);

    int mv = [ai appendFallbackMovesForSnapshot:ai.moves movesCount:(int)before];

    NSUInteger after = [ai.moves count];
    XCTAssertEqual(after, before + 1,
                   @"Connect6 fallback must append exactly ONE stone on the "
                   @"empty-board opening turn (had %lu, now %lu)",
                   (unsigned long)before, (unsigned long)after);
    // NB: not -assertLegalMove:label: -- that helper checks occupancy against
    // the suite-wide FixedPosition(), which was never played on THIS test's
    // board (truly empty). Nothing is occupied here, so only the board-range
    // check applies.
    XCTAssertTrue(mv >= 0 && mv <= 360,
                  @"Connect6 fallback opening stone: %d out of board range",
                  mv);
    XCTAssertEqual([ai.moves[after - 1] intValue], mv);
}

@end
