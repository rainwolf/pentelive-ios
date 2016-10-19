//
//  boardView.h
//  test1
//
//  Created by rainwolf on 29/11/12.
//
//

#import <UIKit/UIKit.h>
#import "PentePlayer.h"

@interface DBBoardView : UIView {
    int abstractBoard[19][19];
    int lastMove;
    NSDictionary<NSNumber *, UIColor *> *dbOptions;
}
@property int lastMove;
@property(retain, nonatomic) NSDictionary<NSNumber *, UIColor *> *dbOptions;
-(instancetype) init;
- (id)initWithFrame:(CGRect)frame;
-(void) setAbstractBoard: (int[19][19]) board;
- (void)drawRect:(CGRect)rect;

@end


