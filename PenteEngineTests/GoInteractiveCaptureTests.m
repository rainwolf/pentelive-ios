//
//  GoInteractiveCaptureTests.m
//  Regression for the turn-based Go board: replayGoGame: routes through the
//  Swift GoGame engine, and a tapped (not yet submitted) move must still show
//  its captures and the capture counters must reflect the replayed game.
//
//  Position is production game 50000000744395 (Go 9x9) after 10 moves:
//  white F6 (32) has black on F7, E6 and F5; black G6 (33) takes its last
//  liberty.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

extern int gridSize, koMove, whiteCaptures, blackCaptures;

// BoardViewController.h pulls in AppDelegate.h (@import), which this
// non-modular test target cannot compile, so declare only what is used.
@interface BoardViewController : UIViewController
@end

// Test-visible names for existing private BoardViewController methods.
@interface BoardViewController (GoCaptureTesting)
- (void)replayGoGame:(int)untilMove;
- (void)copyGoBoard;
- (void)addGoMove:(int)move;
- (int)getBoardValue:(int)pos;
@end

@interface GoInteractiveCaptureTests : XCTestCase
@end

@implementation GoInteractiveCaptureTests

static NSArray<NSString *> *ProductionMoves(void) {
    return @[ @"40", @"50", @"49", @"32", @"41", @"42", @"31", @"60", @"23", @"58" ];
}

- (BoardViewController *)boardWithMoves:(NSArray<NSString *> *)moves {
    BoardViewController *vc = [[BoardViewController alloc] init];
    [vc setValue:[moves mutableCopy] forKey:@"movesList"];
    return vc;
}

- (void)setUp {
    gridSize = 9;
    koMove = -1;
    whiteCaptures = 0;
    blackCaptures = 0;
}

- (void)tearDown {
    gridSize = 19;
    koMove = -1;
    whiteCaptures = 0;
    blackCaptures = 0;
}

- (void)testTappedMoveCapturesSurroundedStone {
    BoardViewController *vc = [self boardWithMoves:ProductionMoves()];
    [vc replayGoGame:10];
    [vc copyGoBoard];
    XCTAssertEqual([vc getBoardValue:32], 1, @"white F6 present before the tap");

    [vc addGoMove:33];

    XCTAssertEqual([vc getBoardValue:33], 2, @"black G6 placed");
    XCTAssertEqual([vc getBoardValue:32], 0, @"white F6 captured by G6");
}

- (void)testTappedMoveCapturesConnectedGroup {
    // White {40,41} has one liberty left at 50.
    BoardViewController *vc = [self boardWithMoves:@[
        @"39", @"40", @"31", @"41", @"49", @"0", @"42", @"80", @"32", @"8"
    ]];
    [vc replayGoGame:10];
    [vc copyGoBoard];

    [vc addGoMove:50];

    XCTAssertEqual([vc getBoardValue:40], 0, @"white 40 captured with its group");
    XCTAssertEqual([vc getBoardValue:41], 0, @"white 41 captured with its group");
}

// Black 41 has just taken white 40 in a ko shape.
static NSArray<NSString *> *KoMoves(void) {
    return @[ @"31", @"32", @"49", @"50", @"39", @"42", @"0", @"40", @"41" ];
}

- (void)testKoPointBlockedForImmediateRetake {
    BoardViewController *vc = [self boardWithMoves:KoMoves()];
    [vc replayGoGame:9];

    XCTAssertEqual(koMove, 40);
    XCTAssertEqual([vc getBoardValue:40], -1, @"ko point is marked so a tap there is rejected");
}

- (void)testKoMarkerSurvivesTapElsewhere {
    BoardViewController *vc = [self boardWithMoves:KoMoves()];
    [vc replayGoGame:9];
    [vc copyGoBoard];

    [vc addGoMove:80];

    XCTAssertEqual([vc getBoardValue:80], 1, @"white preview stone placed");
    XCTAssertEqual([vc getBoardValue:40], -1, @"ko marker kept through the preview");
}

- (void)testKoPointFreeAfterIntermediateMove {
    NSArray<NSString *> *moves = [KoMoves() arrayByAddingObject:@"80"];
    BoardViewController *vc = [self boardWithMoves:moves];
    [vc replayGoGame:10];

    XCTAssertEqual(koMove, -1);
    XCTAssertEqual([vc getBoardValue:40], 0, @"black may fill the old ko point");
}

- (void)testReplayCountsCaptures {
    NSArray<NSString *> *moves = [ProductionMoves() arrayByAddingObject:@"33"];
    BoardViewController *vc = [self boardWithMoves:moves];
    [vc replayGoGame:11];

    XCTAssertEqual([vc getBoardValue:32], 0, @"white F6 captured in replay");
    XCTAssertEqual(whiteCaptures, 1, @"one white stone captured");
    XCTAssertEqual(blackCaptures, 0);
}

@end
