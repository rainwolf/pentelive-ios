//
//  boardView.h
//  test1
//
//  Created by rainwolf on 29/11/12.
//
//

#import "PentePlayer.h"
#import <UIKit/UIKit.h>
typedef int AbstractBoard[19];

@interface DBBoardView : UIView {
    AbstractBoard *abstractBoard;
    int lastMove;
    NSDictionary<NSNumber *, UIColor *> *dbOptions;
    NSTimer *flashTimer;
}

@property int lastMove;
@property(retain, nonatomic) NSDictionary<NSNumber *, UIColor *> *dbOptions;
/// The selected Moves row's cell, or -1. The cell alternates between the
/// side to move's stone and `flashColor` (its heat colour); with Reduce
/// Motion on it shows a static ring instead.
@property(nonatomic, readonly) int flashCell;
@property(nonatomic, readonly) BOOL flashStoneVisible;
@property(nonatomic, readonly) BOOL flashStoneIsWhite;
@property(nonatomic, readonly, strong) UIColor *flashColor;
/// Test seam: when set, replaces UIAccessibilityIsReduceMotionEnabled().
@property(nonatomic, copy) NSNumber *reduceMotionOverride;
@property(nonatomic, readonly) BOOL reduceMotion;
/// True while the flash timer runs (never with Reduce Motion).
@property(nonatomic, readonly) BOOL isFlashAnimating;
- (void)startFlashingCell:(int)cell
             stoneIsWhite:(BOOL)stoneIsWhite
                heatColor:(UIColor *)heatColor;
- (void)stopFlashing;
/// One flash step (the timer calls it); visible for tests.
- (void)flashTick;
- (instancetype)init;
- (id)initWithFrame:(CGRect)frame;
- (void)setAbstractBoard:(AbstractBoard *)board;
- (void)drawRect:(CGRect)rect;

@end
