//
//  boardView.m
//  test1
//
//  Created by rainwolf on 29/11/12.
//
//

#import "DBBoardView.h"
#import "PentePlayer.h"

@implementation DBBoardView {
    // Storyboard-created views skip init, so "not flashing" is the zero value.
    BOOL _flashing;
    int _flashCell;
    BOOL _flashStoneVisible;
    BOOL _flashStoneIsWhite;
    UIColor *_flashColor;
}
@synthesize lastMove;
@synthesize dbOptions;

static const NSTimeInterval kFlashInterval = 0.45;

- (int)grid {
    return self.gridSize > 0 ? self.gridSize : 19;
}

- (int)flashCell {
    return _flashing ? _flashCell : -1;
}

- (BOOL)flashStoneVisible {
    return _flashStoneVisible;
}

- (BOOL)flashStoneIsWhite {
    return _flashStoneIsWhite;
}

- (UIColor *)flashColor {
    return _flashColor;
}

- (BOOL)reduceMotion {
    return self.reduceMotionOverride != nil
               ? self.reduceMotionOverride.boolValue
               : UIAccessibilityIsReduceMotionEnabled();
}

- (BOOL)isFlashAnimating {
    return flashTimer != nil;
}

- (void)startFlashingCell:(int)cell
             stoneIsWhite:(BOOL)stoneIsWhite
                heatColor:(UIColor *)heatColor {
    [self stopFlashing];
    int grid = [self grid];
    if (cell < 0 || cell >= grid * grid) {
        return;
    }
    _flashing = YES;
    _flashCell = cell;
    _flashStoneIsWhite = stoneIsWhite;
    _flashColor = heatColor ?: [UIColor orangeColor];
    _flashStoneVisible = YES;
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(reduceMotionStatusChanged:)
               name:UIAccessibilityReduceMotionStatusDidChangeNotification
             object:nil];
    if (![self reduceMotion]) {
        __weak typeof(self) weakSelf = self;
        flashTimer = [NSTimer timerWithTimeInterval:kFlashInterval
                                            repeats:YES
                                              block:^(NSTimer *timer) {
                                                  [weakSelf flashTick];
                                              }];
        [[NSRunLoop mainRunLoop] addTimer:flashTimer forMode:NSRunLoopCommonModes];
    }
    [self setNeedsDisplay];
}

- (void)reduceMotionStatusChanged:(NSNotification *)note {
    if (!_flashing) {
        return;
    }
    // Restart so the timer switches on or off for the new setting.
    [self startFlashingCell:_flashCell
               stoneIsWhite:_flashStoneIsWhite
                  heatColor:_flashColor];
}

- (void)stopFlashing {
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:UIAccessibilityReduceMotionStatusDidChangeNotification
                object:nil];
    [flashTimer invalidate];
    flashTimer = nil;
    BOOL wasFlashing = _flashing;
    _flashing = NO;
    _flashColor = nil;
    _flashStoneVisible = NO;
    if (wasFlashing) {
        [self setNeedsDisplay];
    }
}

- (void)flashTick {
    if (!_flashing || [self reduceMotion]) {
        return;
    }
    _flashStoneVisible = !_flashStoneVisible;
    [self setNeedsDisplay];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [flashTimer invalidate];
}

- (void)setAbstractBoard:(AbstractBoard *)board {
    abstractBoard = board;
    //    for(int i = 0; i < 19; ++i)
    //        for(int j = 0; j < 19; ++j)
    //            abstractBoard[i][j] = board[i][j];
}

- (instancetype)init {
    if (self = [super init]) {
        lastMove = -1;
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        lastMove = -1;
    }
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 1.2);
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    int grid = [self grid];
    float margin = self.bounds.size.width / (2 * grid);
    // draw the grid
    for (int i = 0; i < grid; ++i) {
        CGContextMoveToPoint(context, margin, margin + i * margin * 2);
        CGContextAddLineToPoint(context, self.bounds.size.width - margin,
                                margin + i * margin * 2);
        CGContextStrokePath(context);
        CGContextMoveToPoint(context, margin + i * margin * 2, margin);
        CGContextAddLineToPoint(context, margin + i * margin * 2,
                                self.bounds.size.width - margin);
        CGContextStrokePath(context);
    }
    CGRect circle;
    if (self.go) {
        // Go star points, as on the live BoardView.
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        int c = grid / 2, l = grid == 9 ? 2 : 3;
        int r = grid - 1 - l;
        int stars[9][2] = {{c, c}, {l, l}, {l, r}, {r, r}, {r, l},
                           {l, c}, {c, l}, {c, r}, {r, c}};
        int count = grid > 9 ? 9 : 5;
        for (int s = 0; s < count; ++s) {
            circle = CGRectMake(margin + 2 * stars[s][0] * margin - margin / 4,
                                margin + 2 * stars[s][1] * margin - margin / 4,
                                margin / 2, margin / 2);
            CGContextAddEllipseInRect(context, circle);
            CGContextFillPath(context);
        }
    } else if (grid == 15) {
        // Renju: 9 circles at cols/rows {3, 7, 11}, as on the live BoardView.
        int starPoints[9] = {48, 52, 56, 108, 112, 116, 168, 172, 176};
        for (int s = 0; s < 9; ++s) {
            int col = starPoints[s] % grid, row = starPoints[s] / grid;
            circle = CGRectMake(margin + 2 * col * margin - margin / 2,
                                margin + 2 * row * margin - margin / 2, margin,
                                margin);
            CGContextAddEllipseInRect(context, circle);
            CGContextStrokePath(context);
        }
    } else {
        // draw the 5 little special circles
        circle =
            CGRectMake(margin + 12 * margin - margin / 2,
                       margin + 12 * margin - margin / 2, margin, margin);
        CGContextAddEllipseInRect(context, circle);
        CGContextStrokePath(context);
        circle.origin.x =
            self.bounds.size.width - margin - 12 * margin - margin / 2;
        CGContextAddEllipseInRect(context, circle);
        CGContextStrokePath(context);
        circle.origin.x =
            self.bounds.size.width - margin - 12 * margin - margin / 2;
        circle.origin.y =
            self.bounds.size.width - margin - 12 * margin - margin / 2;
        CGContextAddEllipseInRect(context, circle);
        CGContextStrokePath(context);
        circle.origin.x = margin + 12 * margin - margin / 2;
        circle.origin.y =
            self.bounds.size.width - margin - 12 * margin - margin / 2;
        CGContextAddEllipseInRect(context, circle);
        CGContextStrokePath(context);
        circle.origin.x = self.bounds.size.width / 2 - margin / 2;
        circle.origin.y = self.bounds.size.width / 2 - margin / 2;
        CGContextAddEllipseInRect(context, circle);
        CGContextStrokePath(context);
    }
    // draw the game

    for (int i = 0; i < grid; ++i) {
        for (int j = 0; j < grid; ++j) {
            if (abstractBoard[i][j] > 0) {
                circle = CGRectMake(j * 2 * margin, i * 2 * margin, 2 * margin,
                                    2 * margin);
                CGPoint centre =
                    CGPointMake(circle.origin.x + margin - margin / 6,
                                circle.origin.y + margin - margin / 6);

                CGContextSaveGState(context);
                size_t num_locations = 2;
                CGFloat locations[2] = {0.0, 1.0};
                CGFloat start = 150.0 / 255.0;
                CGFloat end = 0.0f;
                if (abstractBoard[i][j] == 2) {
                    //                    CGContextSetFillColorWithColor(context,
                    //                    [UIColor blackColor].CGColor);
                } else {
                    start = 1.0;
                    end = 210.0 / 255.0;
                    //                    CGContextSetFillColorWithColor(context,
                    //                    [UIColor whiteColor].CGColor); circle
                    //                    = CGRectMake(j*2*margin,i*2*margin,
                    //                    2*margin,2*margin);
                    //                    CGContextAddEllipseInRect(context,
                    //                    circle); CGContextFillPath(context);
                }
                CGFloat components[8] = {
                    start, start, start, 1.0,  // Start color
                    end,   end,   end,   1.0}; // End color

                CGColorSpaceRef myColorspace = CGColorSpaceCreateDeviceRGB();
                CGGradientRef myGradient = CGGradientCreateWithColorComponents(
                    myColorspace, components, locations, num_locations);

                CGContextAddEllipseInRect(context, circle);
                CGContextSetShadow(context, CGSizeMake(margin / 6, margin / 6),
                                   0);
                CGContextFillPath(context);
                CGContextAddEllipseInRect(context, circle);
                CGContextClip(context);
                CGContextDrawRadialGradient(context, myGradient, centre, 0.0f,
                                            centre, 5 * margin / 4, 0);
                //                CGContextSetFillColorWithColor(context,
                //                [UIColor blackColor].CGColor);
                CGContextRestoreGState(context);

                //                CGContextAddEllipseInRect(context, circle);
                //                CGContextFillPath(context);
                //                if (abstractBoard[i][j] == 2) {
                //                    CGContextSetFillColorWithColor(context,
                //                    [UIColor blackColor].CGColor);
                //                } else {
                //                    CGContextSetFillColorWithColor(context,
                //                    [UIColor whiteColor].CGColor); circle =
                //                    CGRectMake(j*2*margin,i*2*margin,
                //                    2*margin,2*margin);
                //                    CGContextAddEllipseInRect(context,
                //                    circle); CGContextFillPath(context);
                //                }
            }
        }
    }
    //    NSLog(@"kittys %i",lastConnect6Move);
    //    NSLog(@"kittys %i",lastMove);
    CGContextSaveGState(context);
    // A pass (grid²) has no cell.
    if (lastMove > -1 && lastMove < grid * grid) {
        CGContextSetFillColorWithColor(
            context, [UIColor colorWithRed:1 green:0 blue:0 alpha:0.8].CGColor);
        int i = lastMove / grid, j = lastMove % grid;
        circle = CGRectMake(j * 2 * margin + 2 * margin / 3,
                            i * 2 * margin + 2 * margin / 3, 2 * margin / 3,
                            2 * margin / 3);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);
        CGContextRestoreGState(context);
    }

    for (NSNumber *move in [dbOptions allKeys]) {
        int moveInt = [move intValue];
        if (moveInt < 0 || moveInt >= grid * grid) {
            continue;
        }
        int i = moveInt / grid, j = moveInt % grid;
        CGContextSaveGState(context);
        CGContextSetFillColorWithColor(context,
                                       [dbOptions objectForKey:move].CGColor);
        //        CGContextSetFillColorWithColor(context, [UIColor
        //        blueColor].CGColor); circle = CGRectMake(j*2*margin +
        //        2*margin/3,i*2*margin + 2*margin/3, 2*margin/3,2*margin/3);
        circle =
            CGRectMake(j * 2 * margin, i * 2 * margin, 2 * margin, 2 * margin);
        CGContextAddEllipseInRect(context, circle);
        CGContextFillPath(context);

        CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextSetLineWidth(context, 0.5);
        circle =
            CGRectMake(j * 2 * margin, i * 2 * margin, 2 * margin, 2 * margin);
        CGContextAddEllipseInRect(context, circle);
        //        CGContextFillPath(context);
        CGContextStrokePath(context);
        CGContextRestoreGState(context);
    }

    if (_flashing) {
        int i = _flashCell / grid, j = _flashCell % grid;
        circle =
            CGRectMake(j * 2 * margin, i * 2 * margin, 2 * margin, 2 * margin);
        CGContextSaveGState(context);
        if ([self reduceMotion]) {
            // Static highlight: the heat colour under a thick ring.
            CGContextSetFillColorWithColor(context, _flashColor.CGColor);
            CGContextAddEllipseInRect(context, circle);
            CGContextFillPath(context);
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
            CGContextSetLineWidth(context, margin / 4);
            CGContextAddEllipseInRect(context, CGRectInset(circle, margin / 8, margin / 8));
            CGContextStrokePath(context);
        } else if (_flashStoneVisible) {
            CGPoint centre = CGPointMake(circle.origin.x + margin - margin / 6,
                                         circle.origin.y + margin - margin / 6);
            CGFloat start = _flashStoneIsWhite ? 1.0 : 150.0 / 255.0;
            CGFloat end = _flashStoneIsWhite ? 210.0 / 255.0 : 0.0;
            CGFloat locations[2] = {0.0, 1.0};
            CGFloat components[8] = {start, start, start, 1.0,
                                     end,   end,   end,   1.0};
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            CGGradientRef gradient =
                CGGradientCreateWithColorComponents(space, components, locations, 2);
            CGContextAddEllipseInRect(context, circle);
            CGContextClip(context);
            CGContextDrawRadialGradient(context, gradient, centre, 0.0f, centre,
                                        5 * margin / 4, 0);
            CGGradientRelease(gradient);
            CGColorSpaceRelease(space);
        } else {
            CGContextSetFillColorWithColor(context, _flashColor.CGColor);
            CGContextAddEllipseInRect(context, circle);
            CGContextFillPath(context);
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
            CGContextSetLineWidth(context, 0.5);
            CGContextAddEllipseInRect(context, circle);
            CGContextStrokePath(context);
        }
        CGContextRestoreGState(context);
    }
}

@end
