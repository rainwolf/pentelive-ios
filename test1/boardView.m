//
//  boardView.m
//  test1
//
//  Created by rainwolf on 29/11/12.
//
//

#import "BoardView.h"
#import "PentePlayer.h"



@implementation BoardView
@synthesize lastMove;
@synthesize lastConnect6Move;
@synthesize whiteTerritory, whiteDeadStones, blackTerritory, blackDeadStones;
@synthesize whiteStoneView, blackStoneView;
@synthesize whiteSquare, blackSquare;
@synthesize go;
@synthesize gridSize;

-(void) setAbstractBoard: (AbstractBoard*) board {
    abstractBoard = board;
}

-(instancetype) init {
    if (self = [super init]) {
        lastMove = -1;
        lastConnect6Move = -1;
        gridSize = 19;
    }
    return self;
}
- (id)initWithCoder:(NSCoder *)aCoder{
    if(self = [super initWithCoder:aCoder]){
        CGFloat h = self.frame.size.height;
        blackStoneView = [[StoneView alloc] initWithFrame:CGRectMake(0, 0, h, h)];
        [blackStoneView setStoneColor:BLACK];
        [blackStoneView setFill:YES];
        [blackStoneView setAlpha:0.7];
        blackStoneView.clipsToBounds = YES;
        [blackStoneView setOpaque:NO];
        whiteStoneView = [[StoneView alloc] initWithFrame:CGRectMake(0, 0, h, h)];
        [whiteStoneView setStoneColor:WHITE];
        [whiteStoneView setFill:YES];
        [whiteStoneView setAlpha:0.7];
        whiteStoneView.clipsToBounds = YES;
        [whiteStoneView setOpaque:NO];
        whiteSquare = [[UIView alloc] init];
//        [whiteSquare setAlpha:0.9];
        whiteSquare.clipsToBounds = YES;
        [whiteSquare setOpaque:NO];
        [whiteSquare setBackgroundColor:[UIColor whiteColor]];
        blackSquare = [[UIView alloc] init];
//        [blackSquare setAlpha:0.9];
        blackSquare.clipsToBounds = YES;
        [blackSquare setOpaque:NO];
        [blackSquare setBackgroundColor:[UIColor blackColor]];

        lastMove = -1;
        lastConnect6Move = -1;
        gridSize = 19;
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame {
    NSLog(@"init kitten");
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        lastMove = -1;
        lastConnect6Move = -1;
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
    float margin = self.bounds.size.width / (2*gridSize);
        // draw the grid
    for (int i = 0; i < gridSize; ++i) {
        CGContextMoveToPoint(context, margin, margin + i*margin*2);
        CGContextAddLineToPoint(context, self.bounds.size.width - margin,  margin + i*margin*2);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, margin + i*margin*2, margin);
        CGContextAddLineToPoint(context, margin + i*margin*2, self.bounds.size.width - margin);
        CGContextStrokePath(context);
    }
    CGRect circle;
    if (go) {
        int c = gridSize/2, l = 3;
        if (gridSize == 9) { l = 2; }
        int r = gridSize - 1 - l;
        circle = CGRectMake(margin + 2*c*margin - margin/4, margin + 2*c*margin - margin/4, margin/2, margin/2);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        circle = CGRectMake(margin + 2*l*margin - margin/4, margin + 2*l*margin - margin/4, margin/2, margin/2);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        circle = CGRectMake(margin + 2*l*margin - margin/4, margin + 2*r*margin - margin/4, margin/2, margin/2);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        circle = CGRectMake(margin + 2*r*margin - margin/4, margin + 2*r*margin - margin/4, margin/2, margin/2);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        circle = CGRectMake(margin + 2*r*margin - margin/4, margin + 2*l*margin - margin/4, margin/2, margin/2);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        if (gridSize > 9) {
            circle = CGRectMake(margin + 2*l*margin - margin/4, margin + 2*c*margin - margin/4, margin/2, margin/2);
            CGContextAddEllipseInRect(context, circle);
            CGContextFillPath(context);
            circle = CGRectMake(margin + 2*c*margin - margin/4, margin + 2*l*margin - margin/4, margin/2, margin/2);
            CGContextAddEllipseInRect(context, circle);
            CGContextFillPath(context);
            circle = CGRectMake(margin + 2*c*margin - margin/4, margin + 2*r*margin - margin/4, margin/2, margin/2);
            CGContextAddEllipseInRect(context, circle);
            CGContextFillPath(context);
            circle = CGRectMake(margin + 2*r*margin - margin/4, margin + 2*c*margin - margin/4, margin/2, margin/2);
            CGContextAddEllipseInRect(context, circle);
            CGContextFillPath(context);
        }
    } else {
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
    }
        // draw the game
    
    for(int i = 0; i < gridSize; ++i) {
        for(int j = 0; j < gridSize; ++j) {
            if (abstractBoard[i][j] > 0) {
                circle = CGRectMake(j*2*margin,i*2*margin,2*margin,2*margin);
                CGPoint centre = CGPointMake(circle.origin.x + margin - margin/6, circle.origin.y + margin - margin/6);

                CGContextSaveGState(context);
                size_t num_locations = 2;
                CGFloat locations[2] = { 0.0, 1.0 };
                CGFloat start = 150.0/255.0;
                CGFloat end = 0.0f;
                if (abstractBoard[i][j] == 1) {
                    start = 1.0;
                    end = 210.0/255.0;
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
                CGContextRestoreGState(context);
            }
        }
    }
    
    
    for (NSNumber *stone in whiteDeadStones) {
        int stoneInt = stone.intValue, i = stoneInt/gridSize, j = stoneInt%gridSize;
        circle = CGRectMake(j*2*margin,i*2*margin,2*margin,2*margin);
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, circle.origin.x, circle.origin.y);
        [whiteStoneView setFrame:circle];
        whiteStoneView.layer.cornerRadius = margin;
        [whiteStoneView.layer renderInContext:UIGraphicsGetCurrentContext()];
        CGContextRestoreGState(context);
    }
    for (NSNumber *stone in blackDeadStones) {
        int stoneInt = stone.intValue, i = stoneInt/gridSize, j = stoneInt%gridSize;
        circle = CGRectMake(j*2*margin,i*2*margin,2*margin,2*margin);
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, circle.origin.x, circle.origin.y);
        [blackStoneView setFrame:circle];
        blackStoneView.layer.cornerRadius = margin;
        [blackStoneView.layer renderInContext:UIGraphicsGetCurrentContext()];
        CGContextRestoreGState(context);
    }
    CGFloat width = margin*5/6;
    for (NSNumber *stone in whiteTerritory) {
        int stoneInt = stone.intValue, i = stoneInt/gridSize, j = stoneInt%gridSize;
        circle = CGRectMake(j*2*margin + margin - width/2,i*2*margin + margin - width/2,width,width);
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, circle.origin.x, circle.origin.y);
        [whiteSquare setFrame:circle];
        [whiteSquare.layer renderInContext:UIGraphicsGetCurrentContext()];
        CGContextRestoreGState(context);
    }
    for (NSNumber *stone in blackTerritory) {
        int stoneInt = stone.intValue, i = stoneInt/gridSize, j = stoneInt%gridSize;
        circle = CGRectMake(j*2*margin + margin - width/2,i*2*margin + margin - width/2,width,width);
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, circle.origin.x, circle.origin.y);
        [blackSquare setFrame:circle];
        [blackSquare.layer renderInContext:UIGraphicsGetCurrentContext()];
        CGContextRestoreGState(context);
    }

    CGContextSaveGState(context);
    if (lastConnect6Move > -1) {
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1 green:0 blue:0 alpha:0.8].CGColor);
        int i = lastConnect6Move / gridSize, j = lastConnect6Move % gridSize;
        circle = CGRectMake(j*2*margin + 2*margin/3,i*2*margin + 2*margin/3, 2*margin/3,2*margin/3);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
    }
    if (lastMove > -1) {
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:1 green:0 blue:0 alpha:0.8].CGColor);
        int i = lastMove / gridSize, j = lastMove % gridSize;
        circle = CGRectMake(j*2*margin + 2*margin/3,i*2*margin + 2*margin/3, 2*margin/3,2*margin/3);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        CGContextRestoreGState(context);

    }
}




@end



















@implementation StoneView
@synthesize stoneColor;
@synthesize fill;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGFloat circleSide = fill?self.bounds.size.width:self.bounds.size.width/1.2;
    CGFloat indent = (self.bounds.size.width - circleSide)/2;
    CGRect circle = CGRectMake(indent, indent,circleSide,circleSide);
    CGFloat margin = circle.size.width/2;
    CGPoint centre = CGPointMake(circle.origin.x + margin - margin/6, circle.origin.y + margin - margin/6);
    size_t num_locations = 2;
    CGFloat locations[2] = { 0.0, 1.0 };
    CGFloat start = 150.0/255.0;
    CGFloat end = 0.0f;
    if (stoneColor == WHITE) {
        start = 1.0;
        end = 210.0/255.0;
    }
    CGFloat components[8] = { start,start,start, 1.0,  // Start color
        end,end,end, 1.0 }; // End color
    if (stoneColor == RED) {
        start = 1.0;
        end = 210.0/255.0;
        components[0] = start;
        components[1] = end;
        components[2] = end;
        components[4] = start;
        components[5] = 0;
        components[6] = 0;
    }
    CGColorSpaceRef myColorspace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef myGradient = CGGradientCreateWithColorComponents (myColorspace, components, locations, num_locations);
    
    CGContextAddEllipseInRect(context, circle);
    CGContextSetShadow(context, CGSizeMake(margin/6, margin/6), 0);
    CGContextFillPath(context);
    CGContextAddEllipseInRect(context, circle);
    CGContextClip(context);
    CGContextDrawRadialGradient(context, myGradient, centre, 0.0f, centre, 5*margin/4, 0);
    
    CGGradientRelease(myGradient);
    CGColorSpaceRelease(myColorspace);

//    CGContextAddEllipseInRect(context, circle);
//    CGContextFillPath(context);
//    CGContextSetFillColorWithColor(context, stoneColor.CGColor);
//    //    circle = CGRectMake(0.25, 0.25,self.bounds.size.width-0.5,self.bounds.size.height-0.5);
//    circle = CGRectMake(0, 0,self.bounds.size.width,self.bounds.size.height);
//    CGContextAddEllipseInRect(context, circle);
//    CGContextFillPath(context);
}

@end


@implementation VerticalLine

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 3);
    CGContextMoveToPoint(context, self.bounds.size.width/2, 1);
    CGContextAddLineToPoint(context, self.bounds.size.width/2, self.bounds.size.height);
    CGContextStrokePath(context);
}

@end



@implementation HorizontalLine

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 3);
    CGContextMoveToPoint(context, 1, self.bounds.size.height/2);
    CGContextAddLineToPoint(context, self.bounds.size.width, self.bounds.size.height/2);
    CGContextStrokePath(context);
}

@end
