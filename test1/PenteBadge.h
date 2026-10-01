#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A small capsule count badge: white bold text on a coloured pill, pinned to
/// the top-right corner of a view (4 pt above its top edge, flush with its
/// right edge, following it when the view is resized). Sizing carried over
/// from the badge pod this replaces: 6 pt padding, 8 pt minimum text height,
/// single digits drawn as a circle.
@interface UIView (PenteBadge)

/// Shows `value` in the view's badge, creating it on first use and updating
/// it in place after that (never a second label). nil, @"" and @"0" remove the
/// badge. Returns the badge label, or nil when the badge was removed, so a
/// caller can make room for it.
- (nullable UILabel *)pente_setBadgeValue:(nullable NSString *)value
                                    color:(UIColor *)color;

@end

@interface UIBarButtonItem (PenteBadge)

/// Badge fallback for systems without UIBarButtonItemBadge (before iOS 26).
/// Attaches the badge to the item's customView when it has one, otherwise to
/// the view UIKit created for the item (looked up through its `view` key, as
/// the pod did). When that view does not exist yet, tries once more after the
/// current layout pass.
- (void)pente_setBadgeValue:(nullable NSString *)value color:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
