#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Full-size translucent white overlay with a centred large activity indicator.
/// Blocks touches to the views beneath it while it is added to a superview.
@interface PenteSpinnerOverlay : UIView

- (instancetype)initWithFrame:(CGRect)frame NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)startAnimating;
- (void)stopAnimating;

@end

NS_ASSUME_NONNULL_END
