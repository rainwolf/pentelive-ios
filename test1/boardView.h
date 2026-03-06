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

#define WHITE 0
#define BLACK 1
#define RED 2

@interface StoneView : UIView {
    int stoneColor;
    BOOL fill;
}
@property(atomic, assign) int stoneColor;
@property(atomic, assign) BOOL fill;

- (void)drawRect:(CGRect)rect;

@end

@interface BoardView : UIView {
    AbstractBoard *abstractBoard;
    int lastMove;
    int lastConnect6Move;
    NSArray<NSNumber *> *whiteDeadStones, *blackDeadStones, *whiteTerritory,
        *blackTerritory;
    StoneView *whiteStoneView, *blackStoneView;
    UIView *whiteSquare, *blackSquare;
    BOOL go;
    int gridSize;
}
@property(nonatomic, retain) NSArray<NSNumber *> *whiteDeadStones,
    *blackDeadStones, *whiteTerritory, *blackTerritory;
@property(nonatomic, retain) StoneView *whiteStoneView, *blackStoneView;
@property(nonatomic, retain) UIView *whiteSquare, *blackSquare;
@property(atomic, assign) BOOL go;
@property(atomic, assign) int gridSize;
@property int lastMove;
@property int lastConnect6Move;
- (instancetype)init;
- (id)initWithFrame:(CGRect)frame;
- (void)setAbstractBoard:(AbstractBoard *)board;
- (void)drawRect:(CGRect)rect;

@end

@interface VerticalLine : UIView {
}
- (void)drawRect:(CGRect)rect;

@end

@interface HorizontalLine : UIView {
}
- (void)drawRect:(CGRect)rect;

@end
