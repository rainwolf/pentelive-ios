#import "PenteSpinnerOverlay.h"

@implementation PenteSpinnerOverlay {
    UIActivityIndicatorView *spinner;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.alpha = 0.75;
        self.userInteractionEnabled = YES;
        self.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        spinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        spinner.hidesWhenStopped = YES;
        spinner.center =
            CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                   UIViewAutoresizingFlexibleRightMargin |
                                   UIViewAutoresizingFlexibleTopMargin |
                                   UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:spinner];
    }
    return self;
}

- (void)startAnimating {
    [spinner startAnimating];
}

- (void)stopAnimating {
    [spinner stopAnimating];
}

@end
