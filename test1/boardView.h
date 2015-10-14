//
//  boardView.h
//  test1
//
//  Created by rainwolf on 29/11/12.
//
//

#import <UIKit/UIKit.h>
#import "PentePlayer.h"

@interface BoardView : UIView {
    int abstractBoard[19][19];
    int lastMove;
    int lastConnect6Move;
}
@property int lastMove;
@property int lastConnect6Move;
-(void) setAbstractBoard: (int[19][19]) board;
- (void)drawRect:(CGRect)rect;

@end


@interface StoneView : UIView {
    UIColor *stoneColor;
}
@property(nonatomic,retain) UIColor *stoneColor;

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
