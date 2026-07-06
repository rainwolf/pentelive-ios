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

@end
