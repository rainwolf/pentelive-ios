//
//  boardView.m
//  test1
//
//  Created by rainwolf on 29/11/12.
//
//

#import "DBBoardView.h"
#import "PentePlayer.h"



@implementation DBBoardView
@synthesize lastMove;
@synthesize dbOptions;

-(void) setAbstractBoard: (AbstractBoard*) board {
    abstractBoard = board;
//    for(int i = 0; i < 19; ++i)
//        for(int j = 0; j < 19; ++j)
//            abstractBoard[i][j] = board[i][j];
}

-(instancetype) init {
    if (self = [super init]) {
        lastMove = -1;
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        lastMove = -1;
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 1.2);
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    float margin = self.bounds.size.width / 38;
        // draw the grid
    for (int i = 0; i < 19; ++i) {
        CGContextMoveToPoint(context, margin, margin + i*margin*2);
        CGContextAddLineToPoint(context, self.bounds.size.width - margin,  margin + i*margin*2);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, margin + i*margin*2, margin);
        CGContextAddLineToPoint(context, margin + i*margin*2, self.bounds.size.width - margin);
        CGContextStrokePath(context);
    }
        // draw the 5 little special circles
    CGRect circle = CGRectMake(margin + 12*margin - margin/2, margin + 12*margin - margin/2, margin, margin);
    CGContextAddEllipseInRect(context, circle);
    CGContextStrokePath(context);
    circle.origin.x = self.bounds.size.width - margin - 12*margin - margin/2;
    CGContextAddEllipseInRect(context, circle);
    CGContextStrokePath(context);
    circle.origin.x = self.bounds.size.width - margin - 12*margin - margin/2;
    circle.origin.y = self.bounds.size.width - margin - 12*margin - margin/2;
    CGContextAddEllipseInRect(context, circle);
    CGContextStrokePath(context);
    circle.origin.x = margin + 12*margin - margin/2;
    circle.origin.y = self.bounds.size.width - margin - 12*margin - margin/2;
    CGContextAddEllipseInRect(context, circle);
    CGContextStrokePath(context);
    circle.origin.x = self.bounds.size.width/2 - margin/2;
    circle.origin.y = self.bounds.size.width/2 - margin/2;
    CGContextAddEllipseInRect(context, circle);
    CGContextStrokePath(context);
        // draw the game
    
    for(int i = 0; i < 19; ++i) {
        for(int j = 0; j < 19; ++j) {
            if (abstractBoard[i][j] > 0) {
                circle = CGRectMake(j*2*margin,i*2*margin,2*margin,2*margin);
                CGPoint centre = CGPointMake(circle.origin.x + margin - margin/6, circle.origin.y + margin - margin/6);
                
                CGContextSaveGState(context);
                size_t num_locations = 2;
                CGFloat locations[2] = { 0.0, 1.0 };
                CGFloat start = 150.0/255.0;
                CGFloat end = 0.0f;
                if (abstractBoard[i][j] == 2) {
//                    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
                } else {
                    start = 1.0;
                    end = 210.0/255.0;
//                    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
//                    circle = CGRectMake(j*2*margin,i*2*margin, 2*margin,2*margin);
//                    CGContextAddEllipseInRect(context, circle);
//                    CGContextFillPath(context);
                }
                CGFloat components[8] = { start,start,start, 1.0,  // Start color
                    end,end,end, 1.0 }; // End color
                
                CGColorSpaceRef myColorspace = CGColorSpaceCreateDeviceRGB();
                CGGradientRef myGradient = CGGradientCreateWithColorComponents (myColorspace, components, locations, num_locations);
                
                CGContextAddEllipseInRect(context, circle);
                CGContextSetShadow(context, CGSizeMake(margin/6, margin/6), 0);
                CGContextFillPath(context);
                CGContextAddEllipseInRect(context, circle);
                CGContextClip(context);
                CGContextDrawRadialGradient(context, myGradient, centre, 0.0f, centre, 5*margin/4, 0);
//                CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
                CGContextRestoreGState(context);
                
//                CGContextAddEllipseInRect(context, circle);
//                CGContextFillPath(context);
//                if (abstractBoard[i][j] == 2) {
//                    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
//                } else {
//                    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
//                    circle = CGRectMake(j*2*margin,i*2*margin, 2*margin,2*margin);
//                    CGContextAddEllipseInRect(context, circle);
//                    CGContextFillPath(context);
//                }
            }
        }
    }
//    NSLog(@"kittys %i",lastConnect6Move);
//    NSLog(@"kittys %i",lastMove);
    CGContextSaveGState(context);
    if (lastMove > -1) {
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1 green:0 blue:0 alpha:0.8].CGColor);
        int i = lastMove / 19, j = lastMove % 19;
        circle = CGRectMake(j*2*margin + 2*margin/3,i*2*margin + 2*margin/3, 2*margin/3,2*margin/3);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        CGContextRestoreGState(context);
    }
    
    for (NSNumber *move in [dbOptions allKeys]) {
        int moveInt = [move intValue];
        int i = moveInt / 19, j = moveInt % 19;
        CGContextSaveGState(context);
        CGContextSetFillColorWithColor(context, [dbOptions objectForKey:move].CGColor);
        //        CGContextSetFillColorWithColor(context, [UIColor blueColor].CGColor);
        //        circle = CGRectMake(j*2*margin + 2*margin/3,i*2*margin + 2*margin/3, 2*margin/3,2*margin/3);
        circle = CGRectMake(j*2*margin,i*2*margin,2*margin,2*margin);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        
        CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextSetLineWidth(context, 0.5);
        circle = CGRectMake(j*2*margin,i*2*margin,2*margin,2*margin);
        CGContextAddEllipseInRect(context, circle);
//        CGContextFillPath(context);
        CGContextStrokePath(context);
        CGContextRestoreGState(context);
    }
}




@end













