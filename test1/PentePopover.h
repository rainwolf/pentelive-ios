#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A small popover anchored at a point in a view, hosted by a native
/// UIPopoverPresentationController (popover style on iPhone and iPad).
///
/// The instance keeps itself alive while it is presented. `onDismiss` runs
/// exactly once, after the dismissal animation, whether the popover was
/// dismissed by a tap outside it or by -dismiss / -dismissWithCompletion:.
///
/// Callers that navigate (push, segue, present) after dismissing must do so in
/// the completion of -dismissWithCompletion:, because UIKit refuses a new
/// presentation while the popover is still animating out.
@interface PentePopover : NSObject

/// Shows `content` (and an optional title above it). Returns nil, after
/// logging, when no presenting view controller can be found for `view` (for
/// example when `view` is not in a window).
+ (nullable instancetype)showContentView:(UIView *)content
                                   title:(nullable NSString *)title
                                 atPoint:(CGPoint)point
                                  inView:(UIView *)view
                               onDismiss:(nullable void (^)(void))onDismiss;

/// Stacks `views` vertically, 10 pt apart, centred horizontally (views whose
/// autoresizingMask is exactly UIViewAutoresizingFlexibleWidth are stretched
/// to the widest one), with an optional title above them. Returns nil like
/// +showContentView:title:atPoint:inView:onDismiss:.
+ (nullable instancetype)showViews:(NSArray<UIView *> *)views
                             title:(nullable NSString *)title
                           atPoint:(CGPoint)point
                            inView:(UIView *)view
                         onDismiss:(nullable void (^)(void))onDismiss;

/// Animates the popover out, then runs `onDismiss`. No-op when not presented.
- (void)dismiss;

/// Animates the popover out, then runs `onDismiss` (once), then `completion`.
/// When the popover is already dismissed, `completion` runs immediately; when
/// it is already animating out, `completion` runs once that finishes.
- (void)dismissWithCompletion:(nullable void (^)(void))completion;

/// YES from a successful show until a dismissal starts.
@property(nonatomic, readonly) BOOL isPresented;

@end

NS_ASSUME_NONNULL_END
