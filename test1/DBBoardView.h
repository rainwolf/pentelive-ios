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
}

@property int lastMove;
@property(retain, nonatomic) NSDictionary<NSNumber *, UIColor *> *dbOptions;
- (instancetype)init;
- (id)initWithFrame:(CGRect)frame;
- (void)setAbstractBoard:(AbstractBoard *)board;
- (void)drawRect:(CGRect)rect;

@end
