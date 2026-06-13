//
//  CorpusSnapshotGeneratorTests.m
//  One-off golden-corpus generator/verifier for the CURRENT Objective-C
//  PenteGame engine.
//
//  Generate-if-missing: the first run writes golden/<name>.json next to this
//  source file; later runs re-run the engine and verify the committed golden
//  still matches. To regenerate, delete PenteEngineTests/golden.
//
//  Variant is stored as a STABLE STRING name so the golden JSON is decoupled
//  from enum ordering: the existing PenteGameVariant and the new Swift
//  PenteVariant have DIFFERENT integer orders.
//

#import <XCTest/XCTest.h>
#import "../test1/PenteGame.h"

static int gBoardStorage[19][19];

@interface CorpusSnapshotGeneratorTests : XCTestCase
@end

@implementation CorpusSnapshotGeneratorTests

static PenteGameVariant VariantForName(NSString *name) {
    static NSDictionary<NSString *, NSNumber *> *map;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        map = @{
            @"pente": @(PenteGameVariantPente),
            @"keryoPente": @(PenteGameVariantKeryoPente),
            @"oPente": @(PenteGameVariantOPente),
            @"poofPente": @(PenteGameVariantPoofPente),
            @"dPente": @(PenteGameVariantDPente),
            @"dkPente": @(PenteGameVariantDKPente),
            @"gpente": @(PenteGameVariantGPente),
            @"swap2Pente": @(PenteGameVariantSwap2Pente),
            @"swap2Keryo": @(PenteGameVariantSwap2Keryo),
            @"gomoku": @(PenteGameVariantGomoku),
            @"connect6": @(PenteGameVariantConnect6),
        };
    });
    NSNumber *v = map[name];
    NSCAssert(v != nil, @"unknown variant name %@", name);
    return (PenteGameVariant)[v intValue];
}

// rowCol = row*19 + col. Each move-list is parity-checked so white (color 1)
// lands on even move indices and black (color 2) on odd, per replayMoves.
static NSArray<NSDictionary *> *Corpus(void) {
    return @[
        // Pente pair capture: W(5,5) B(5,6) Wneutral(0,0) B(5,7) W(5,8) closes
        // the pair -> (5,6),(5,7) removed, blackCaptures=2.
        @{ @"name": @"pente_pair_capture",
           @"variant": @"pente",
           @"moves": @[ @100, @101, @0, @102, @103 ] },
        // Keryo 3-capture (from tests/PenteGameTests.m testReplayKeryoCapture):
        // W B B B W on row 5 -> 3 black removed, blackCaptures=3.
        @{ @"name": @"keryo_triple_capture",
           @"variant": @"keryoPente",
           @"moves": @[ @100, @101, @240, @102, @280, @103, @104 ] },
        // Poof (self-capture): B(5,4) W(5,5) Wneutral(0,0) B(5,7) then
        // W(5,6) makes B W W B -> own (5,5),(5,6) poof, whiteCaptures=2.
        @{ @"name": @"poof_self_capture",
           @"variant": @"poofPente",
           @"moves": @[ @100, @99, @0, @102, @101 ] },
        // Keryo-poof both-ends regression (commit 63986f7): anti-diagonal
        // B(11,7) W(10,8) W(8,10) B(7,11), W places center (9,9) ->
        // B W W W B -> own (10,8),(9,9),(8,10) poof, whiteCaptures=3.
        @{ @"name": @"keryo_poof_antidiagonal",
           @"variant": @"oPente",
           @"moves": @[ @198, @216, @162, @144, @180 ] },
        // 5-in-a-row win (from testReplayPenteFiveInARowWin): white row 9
        // cols 9-13, black far away -> white wins.
        @{ @"name": @"pente_five_in_a_row_win",
           @"variant": @"pente",
           @"moves": @[ @180, @40, @181, @41, @182, @42, @183, @44, @184 ] },
        // Capture-threshold win: white closes 5 black pairs (rows
        // 10,12,14,16,18) -> blackCaptures=10 -> white wins. Lines are
        // pipelined so every closing flanker is a white (even-index) move;
        // index 18 is a harmless white neutral at (0,0).
        @{ @"name": @"pente_capture_threshold_win",
           @"variant": @"pente",
           @"moves": @[ @195, @196, @233, @197, @198, @234, @271, @235, @236,
                        @272, @309, @273, @274, @310, @347, @311, @312, @348,
                        @0, @349, @350 ] },
        // Connect6 cadence w,b,b,w,w,b (from testReplayConnect6Colors); no win.
        @{ @"name": @"connect6_cadence",
           @"variant": @"connect6",
           @"moves": @[ @0, @1, @2, @3, @4, @5 ] },
        // Gomoku 5-in-a-row win (no captures in Gomoku replay path).
        @{ @"name": @"gomoku_five_in_a_row_win",
           @"variant": @"gomoku",
           @"moves": @[ @180, @40, @181, @41, @182, @42, @183, @44, @184 ] },
    ];
}

static NSString *GoldenDir(void) {
    NSString *thisFile = [NSString stringWithUTF8String:__FILE__];
    return [[thisFile stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:@"golden"];
}

// Runs the CURRENT ObjC engine over one case and returns its snapshot dict.
static NSDictionary *SnapshotForCase(NSDictionary *c) {
    PenteGame *g = [[PenteGame alloc] init];
    g.abstractBoard = gBoardStorage;
    [g resetBoard];
    NSArray *moves = c[@"moves"];
    PenteGameVariant variant = VariantForName(c[@"variant"]);
    [g replayMoves:moves variant:variant untilMove:(NSInteger)[moves count]];
    int winner = [g winnerForVariant:variant moves:moves];

    NSMutableArray *board = [NSMutableArray arrayWithCapacity:19];
    for (int i = 0; i < 19; ++i) {
        NSMutableArray *row = [NSMutableArray arrayWithCapacity:19];
        for (int j = 0; j < 19; ++j) {
            [row addObject:@(gBoardStorage[i][j])];
        }
        [board addObject:row];
    }
    return @{
        @"name": c[@"name"],
        @"variant": c[@"variant"],
        @"moves": moves,
        @"expected": @{
            @"winner": @(winner),
            @"whiteCaptures": @(g.whiteCaptures),
            @"blackCaptures": @(g.blackCaptures),
            @"board": board,
        },
    };
}

- (NSDictionary *)snapshotNamed:(NSString *)name {
    for (NSDictionary *c in Corpus()) {
        if ([c[@"name"] isEqualToString:name]) {
            return SnapshotForCase(c);
        }
    }
    return nil;
}

- (void)testGenerateOrVerifyGoldenCorpus {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = GoldenDir();
    NSError *err = nil;
    [fm createDirectoryAtPath:dir
        withIntermediateDirectories:YES
                     attributes:nil
                          error:&err];
    XCTAssertNil(err, @"create golden dir: %@", err);

    NSInteger generated = 0, verified = 0;
    for (NSDictionary *c in Corpus()) {
        NSDictionary *snapshot = SnapshotForCase(c);
        NSString *path = [dir stringByAppendingPathComponent:
            [c[@"name"] stringByAppendingPathExtension:@"json"]];

        NSData *json = [NSJSONSerialization
            dataWithJSONObject:snapshot
                       options:(NSJSONWritingPrettyPrinted |
                                NSJSONWritingSortedKeys)
                         error:&err];
        XCTAssertNotNil(json, @"serialize %@: %@", c[@"name"], err);

        if (![fm fileExistsAtPath:path]) {
            BOOL ok = [json writeToFile:path atomically:YES];
            XCTAssertTrue(ok, @"write golden %@", path);
            ++generated;
            continue;
        }
        NSData *existing = [NSData dataWithContentsOfFile:path];
        NSDictionary *existingObj =
            [NSJSONSerialization JSONObjectWithData:existing
                                            options:0
                                              error:&err];
        XCTAssertEqualObjects(existingObj, snapshot,
            @"golden %@ is stale; the current engine no longer reproduces it. "
             "Delete PenteEngineTests/golden to regenerate.", c[@"name"]);
        ++verified;
    }
    NSLog(@"[corpus] generated=%ld verified=%ld dir=%@",
          (long)generated, (long)verified, dir);

    // Sanity: named win/capture cases must really exercise their behaviour,
    // so a mis-authored move-list can never silently bake a wrong golden.
    XCTAssertEqual([[self snapshotNamed:@"pente_five_in_a_row_win"]
                       [@"expected"][@"winner"] intValue], 1);
    XCTAssertEqual([[self snapshotNamed:@"pente_capture_threshold_win"]
                       [@"expected"][@"winner"] intValue], 1);
    XCTAssertEqual([[self snapshotNamed:@"gomoku_five_in_a_row_win"]
                       [@"expected"][@"winner"] intValue], 1);
    XCTAssertEqual([[self snapshotNamed:@"keryo_triple_capture"]
                       [@"expected"][@"blackCaptures"] intValue], 3);
    XCTAssertEqual([[self snapshotNamed:@"poof_self_capture"]
                       [@"expected"][@"whiteCaptures"] intValue], 2);
    XCTAssertEqual([[self snapshotNamed:@"keryo_poof_antidiagonal"]
                       [@"expected"][@"whiteCaptures"] intValue], 3);
}

@end
