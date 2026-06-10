//
//  PenteGameTests.m
//  Standalone behavioral tests for the shared PenteGame engine.
//
//  Run with:
//    clang -fobjc-arc -framework Foundation \
//      test1/PenteGame.m tests/PenteGameTests.m -o /tmp/pentegame_tests \
//      && /tmp/pentegame_tests
//
//  Kept outside the app target on purpose: the Xcode project has no unit
//  test target, and this needs nothing but Foundation.
//

#import "../test1/PenteGame.h"
#import <Foundation/Foundation.h>

static int failures = 0;

#define ASSERT_EQ(actual, expected, msg)                                       \
    do {                                                                       \
        long long _a = (long long)(actual), _e = (long long)(expected);        \
        if (_a != _e) {                                                        \
            printf("FAIL %s: %s — got %lld, expected %lld\n", __func__, msg,   \
                   _a, _e);                                                    \
            ++failures;                                                        \
        }                                                                      \
    } while (0)

static int boardStorage[19][19];

static PenteGame *freshGame(void) {
    PenteGame *g = [[PenteGame alloc] init];
    g.abstractBoard = boardStorage;
    [g resetBoard];
    g.whiteCaptures = 0;
    g.blackCaptures = 0;
    return g;
}

static int pos(int row, int col) { return row * 19 + col; }

static void testPairCapture(void) {
    PenteGame *g = freshGame();
    NSMutableArray *events = [[NSMutableArray alloc] init];
    g.captures = events;
    // white flanker, two black stones, white closes the pair
    boardStorage[5][5] = 1;
    boardStorage[5][6] = 2;
    boardStorage[5][7] = 2;
    boardStorage[5][8] = 1;
    [g detectCaptureOfOpponent:2 atPosition:pos(5, 8)];
    ASSERT_EQ(boardStorage[5][6], 0, "captured stone removed");
    ASSERT_EQ(boardStorage[5][7], 0, "captured stone removed");
    ASSERT_EQ(g.blackCaptures, 2, "two black stones captured");
    ASSERT_EQ(g.whiteCaptures, 0, "no white stones captured");
    ASSERT_EQ([events count], 2, "two capture events recorded");
    struct Capture c;
    [[events objectAtIndex:0] getValue:&c];
    ASSERT_EQ(c.color, 2, "event color is black");
    ASSERT_EQ(c.position, pos(5, 7), "first event position");
}

static void testCaptureWithoutEventArray(void) {
    PenteGame *g = freshGame();
    g.captures = nil; // MMAI-style consumer: no animation recording
    boardStorage[5][5] = 1;
    boardStorage[5][6] = 2;
    boardStorage[5][7] = 2;
    boardStorage[5][8] = 1;
    [g detectCaptureOfOpponent:2 atPosition:pos(5, 8)];
    ASSERT_EQ(g.blackCaptures, 2, "capture counted with nil captures array");
    ASSERT_EQ(boardStorage[5][6], 0, "captured stone removed");
}

static void testKeryoTripleCapture(void) {
    PenteGame *g = freshGame();
    boardStorage[5][5] = 1;
    boardStorage[5][6] = 2;
    boardStorage[5][7] = 2;
    boardStorage[5][8] = 2;
    boardStorage[5][9] = 1;
    [g detectKeryoCaptureOfOpponent:2 atPosition:pos(5, 9)];
    ASSERT_EQ(boardStorage[5][6], 0, "keryo stone removed");
    ASSERT_EQ(boardStorage[5][7], 0, "keryo stone removed");
    ASSERT_EQ(boardStorage[5][8], 0, "keryo stone removed");
    ASSERT_EQ(g.blackCaptures, 3, "three black stones captured");
}

static void testPoof(void) {
    PenteGame *g = freshGame();
    NSMutableArray *events = [[NSMutableArray alloc] init];
    g.captures = events;
    boardStorage[5][4] = 2;
    boardStorage[5][5] = 1;
    boardStorage[5][7] = 2;
    boardStorage[5][6] = 1; // white plays into the poof
    BOOL poofed = [g detectPoof:1 atPosition:pos(5, 6)];
    ASSERT_EQ(poofed, YES, "poof detected");
    ASSERT_EQ(boardStorage[5][5], 0, "poofed stone removed");
    ASSERT_EQ(boardStorage[5][6], 0, "placed stone removed");
    ASSERT_EQ(g.whiteCaptures, 2, "poof counts two white captures");
    ASSERT_EQ([events count], 2, "poof records both stones");
    struct Capture c;
    [[events objectAtIndex:0] getValue:&c];
    ASSERT_EQ(c.position, pos(5, 6), "placed stone inserted first");
}

static void testKeryoPoofAntiDiagonalCenter(void) {
    // 3-stone keryo poof, placed stone in the center of the anti-diagonal:
    // black (11,7) / white (10,8) / white placed (9,9) / white (8,10) /
    // black (7,11)
    PenteGame *g = freshGame();
    boardStorage[11][7] = 2;
    boardStorage[10][8] = 1;
    boardStorage[8][10] = 1;
    boardStorage[7][11] = 2;
    boardStorage[9][9] = 1;
    BOOL poofed = [g detectKeryoPoof:1 atPosition:pos(9, 9)];
    ASSERT_EQ(poofed, YES, "anti-diagonal centered keryo poof detected");
    ASSERT_EQ(boardStorage[10][8], 0, "lower-left stone removed");
    ASSERT_EQ(boardStorage[9][9], 0, "center stone removed");
    ASSERT_EQ(boardStorage[8][10], 0, "upper-right stone removed");
    ASSERT_EQ(g.whiteCaptures, 3, "keryo poof counts three white captures");

    // regression for the old duplicated-condition bug: with the upper-right
    // own stone missing, no poof may fire
    PenteGame *g2 = freshGame();
    boardStorage[11][7] = 2;
    boardStorage[10][8] = 1;
    boardStorage[7][11] = 2;
    boardStorage[9][9] = 1;
    BOOL notPoofed = [g2 detectKeryoPoof:1 atPosition:pos(9, 9)];
    ASSERT_EQ(notPoofed, NO, "no poof when line is incomplete");
    ASSERT_EQ(boardStorage[9][9], 1, "placed stone stays");
    ASSERT_EQ(boardStorage[10][8], 1, "own stone stays");
    ASSERT_EQ(g2.whiteCaptures, 0, "no captures counted");
}

static void testReplayPenteFiveInARowWin(void) {
    PenteGame *g = freshGame();
    // white builds row 9 cols 9-13; black plays far away on row 2
    NSArray *moves = @[
        @(pos(9, 9)), @(pos(2, 2)), @(pos(9, 10)), @(pos(2, 3)), @(pos(9, 11)),
        @(pos(2, 4)), @(pos(9, 12)), @(pos(2, 6)), @(pos(9, 13))
    ];
    [g replayMoves:moves variant:PenteGameVariantPente untilMove:[moves count]];
    ASSERT_EQ(boardStorage[9][9], 1, "white stone placed");
    ASSERT_EQ(boardStorage[2][2], 2, "black stone placed");
    ASSERT_EQ([g winnerForVariant:PenteGameVariantPente moves:moves], 1,
              "white wins by pente");
}

static void testReplayWithStringMoves(void) {
    PenteGame *g = freshGame();
    // BoardViewController passes moves as strings; intValue must work
    NSArray *moves = @[ @"180", @"42" ];
    [g replayMoves:moves variant:PenteGameVariantPente untilMove:2];
    ASSERT_EQ(boardStorage[180 / 19][180 % 19], 1, "string move parsed white");
    ASSERT_EQ(boardStorage[42 / 19][42 % 19], 2, "string move parsed black");
}

static void testReplayKeryoCapture(void) {
    PenteGame *g = freshGame();
    NSArray *moves = @[
        @(pos(5, 5)), @(pos(5, 6)), @(pos(12, 12)), @(pos(5, 7)),
        @(pos(14, 14)), @(pos(5, 8)), @(pos(5, 9))
    ];
    [g replayMoves:moves
           variant:PenteGameVariantKeryoPente
         untilMove:[moves count]];
    ASSERT_EQ(g.blackCaptures, 3, "keryo replay captures three");
    ASSERT_EQ(boardStorage[5][7], 0, "keryo replay removed stones");
    ASSERT_EQ([g winnerForVariant:PenteGameVariantKeryoPente moves:moves], 0,
              "no winner below 15 captures");
}

static void testCaptureWinThresholds(void) {
    PenteGame *g = freshGame();
    NSArray *moves = @[ @(pos(9, 9)) ];
    g.whiteCaptures = 10;
    ASSERT_EQ([g winnerForVariant:PenteGameVariantPente moves:moves], 2,
              "10 white stones captured means black wins");
    g.whiteCaptures = 0;
    g.blackCaptures = 10;
    ASSERT_EQ([g winnerForVariant:PenteGameVariantPente moves:moves], 1,
              "10 black stones captured means white wins");
    g.blackCaptures = 14;
    ASSERT_EQ([g winnerForVariant:PenteGameVariantKeryoPente moves:moves], 0,
              "keryo needs 15");
    g.blackCaptures = 15;
    ASSERT_EQ([g winnerForVariant:PenteGameVariantKeryoPente moves:moves], 1,
              "keryo 15 black captured means white wins");
}

static void testReplayConnect6Colors(void) {
    PenteGame *g = freshGame();
    // Connect6 order: w, b, b, w, w, b, b, ...
    NSArray *moves = @[ @0, @1, @2, @3, @4, @5 ];
    [g replayMoves:moves
           variant:PenteGameVariantConnect6
         untilMove:[moves count]];
    ASSERT_EQ(boardStorage[0][0], 1, "connect6 move 0 white");
    ASSERT_EQ(boardStorage[0][1], 2, "connect6 move 1 black");
    ASSERT_EQ(boardStorage[0][2], 2, "connect6 move 2 black");
    ASSERT_EQ(boardStorage[0][3], 1, "connect6 move 3 white");
    ASSERT_EQ(boardStorage[0][4], 1, "connect6 move 4 white");
    ASSERT_EQ(boardStorage[0][5], 2, "connect6 move 5 black");
}

static void testMasks(void) {
    PenteGame *g = freshGame();
    boardStorage[9][9] = 1;
    [g maskTournamentOpening];
    ASSERT_EQ(boardStorage[7][7], -1, "tournament mask set");
    ASSERT_EQ(boardStorage[9][9], 1, "stone untouched by mask");
    ASSERT_EQ(boardStorage[6][7], 0, "outside mask untouched");
    [g resetBoard];
    boardStorage[9][9] = 1;
    [g maskGPenteOpening];
    ASSERT_EQ(boardStorage[9][13], -1, "g-pente arm masked");
    ASSERT_EQ(boardStorage[13][9], -1, "g-pente arm masked");
    [g unmaskGPenteOpening];
    ASSERT_EQ(boardStorage[9][13], 0, "g-pente arm unmasked");
    ASSERT_EQ(boardStorage[7][7], 0, "center unmasked");
    ASSERT_EQ(boardStorage[9][9], 1, "stone survives unmask");
}

int main(void) {
    @autoreleasepool {
        testPairCapture();
        testCaptureWithoutEventArray();
        testKeryoTripleCapture();
        testPoof();
        testKeryoPoofAntiDiagonalCenter();
        testReplayPenteFiveInARowWin();
        testReplayWithStringMoves();
        testReplayKeryoCapture();
        testCaptureWinThresholds();
        testReplayConnect6Colors();
        testMasks();
    }
    if (failures == 0) {
        printf("ALL TESTS PASSED\n");
        return 0;
    }
    printf("%d FAILURES\n", failures);
    return 1;
}
