//
//  PenteGame.h
//  penteLive
//
//  Created by rainwolf on 25/01/2018.
//  Copyright © 2018 Triade. All rights reserved.
//

#ifndef PenteGame_h
#define PenteGame_h

#endif /* PenteGame_h */
#import <Foundation/Foundation.h>

typedef int AbstractBoard[19];

struct Capture {
    int color;
    int position;
};

typedef NS_ENUM(NSInteger, PenteGameVariant) {
    PenteGameVariantPente,
    PenteGameVariantKeryoPente,
    PenteGameVariantGPente,
    PenteGameVariantDPente,
    PenteGameVariantDKPente,
    PenteGameVariantOPente,
    PenteGameVariantPoofPente,
    PenteGameVariantSwap2Pente,
    PenteGameVariantSwap2Keryo,
    PenteGameVariantGomoku,
    PenteGameVariantConnect6,
};

@interface PenteGame : NSObject {

    AbstractBoard *abstractBoard;

    int whiteCaptures, blackCaptures;
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSNumber *, NSNumber *>
                                        *> *goStoneGroupIDsByPlayer;
    NSMutableDictionary<
        NSNumber *,
        NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *>
        *goStoneGroupsByPlayerAndID;
}
@property(nonatomic) AbstractBoard *abstractBoard;
@property(atomic, assign) int whiteCaptures, blackCaptures;
// When set, capture/poof detection appends struct Capture NSValues for UI
// animation. Leave nil to skip recording.
@property(nonatomic, retain) NSMutableArray *captures;
@property(nonatomic, retain)
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSNumber *, NSNumber *>
                                        *> *goStoneGroupIDsByPlayer;
@property(nonatomic, retain) NSMutableDictionary<
    NSNumber *, NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *>
    *goStoneGroupsByPlayerAndID;

+ (NSString *)getGameName:(int)gameInt;

- (void)resetBoard;
- (void)replayMoves:(NSArray *)moves
            variant:(PenteGameVariant)variant
          untilMove:(NSInteger)untilMove;
- (void)detectCaptureOfOpponent:(int)opponentColor atPosition:(int)rowCol;
- (void)detectKeryoCaptureOfOpponent:(int)opponentColor atPosition:(int)rowCol;
- (BOOL)detectPoof:(int)myColor atPosition:(int)rowCol;
- (BOOL)detectKeryoPoof:(int)myColor atPosition:(int)rowCol;
- (BOOL)detectPenteOf:(int)color atPosition:(int)rowCol;
// Marks the rated-opening restriction (center 5x5) with -1.
- (void)maskTournamentOpening;
// Marks the G-Pente opening restriction (center 5x5 plus arms) with -1.
- (void)maskGPenteOpening;
- (void)unmaskGPenteOpening;
// Returns 0 = no winner yet, 1 = white wins, 2 = black wins.
- (int)winnerForVariant:(PenteGameVariant)variant moves:(NSArray *)moves;

@end
