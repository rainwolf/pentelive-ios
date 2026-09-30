#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Same cases, order and raw values as TSMessageNotificationType.
typedef NS_ENUM(NSInteger, PenteBannerType) {
    PenteBannerTypeMessage = 0,
    PenteBannerTypeWarning,
    PenteBannerTypeError,
    PenteBannerTypeSuccess
};

/// Same cases, order and raw values as TSMessageNotificationPosition.
typedef NS_ENUM(NSInteger, PenteBannerPosition) {
    PenteBannerPositionTop = 0,
    PenteBannerPositionNavBarOverlay,
    PenteBannerPositionBottom
};

/// Special values for the duration parameter, numerically equal to
/// TSMessageNotificationDuration. Any other value is a duration in seconds.
/// Swift sees PenteBannerDuration.automatic / .endless (rawValue: TimeInterval).
typedef NSTimeInterval PenteBannerDuration NS_TYPED_ENUM;
/// 0: 0.3 + 1.5 + 0.04 x banner height in points seconds (TSMessage's formula).
FOUNDATION_EXPORT PenteBannerDuration const PenteBannerDurationAutomatic;
/// -1: shown until dismissed, or until its host view leaves the window.
FOUNDATION_EXPORT PenteBannerDuration const PenteBannerDurationEndless;

/// Replacement for TSMessage. Shows a floating card banner (Liquid Glass on
/// iOS 26+, a frosted material before that; the type shows as a coloured icon)
/// in the presenting view controller's navigation controller view, one banner
/// at a time, in FIFO order. A banner
/// whose title and subtitle match one already queued or showing is dropped.
/// Safe to call from any thread; all work happens on the main thread.
@interface PenteBanner : NSObject

/// image is accepted for call-site compatibility with TSMessage and ignored.
/// A tap runs callback, then dismisses. The optional right-side button runs
/// buttonCallback, then dismisses. dismissingEnabled adds swipe-to-dismiss and,
/// when there is no callback, tap-to-dismiss.
+ (void)showNotificationInViewController:(UIViewController *)viewController
                                   title:(NSString *)title
                                subtitle:(nullable NSString *)subtitle
                                   image:(nullable UIImage *)image
                                    type:(PenteBannerType)type
                                duration:(NSTimeInterval)duration
                                callback:(nullable void (^)(void))callback
                             buttonTitle:(nullable NSString *)buttonTitle
                          buttonCallback:(nullable void (^)(void))buttonCallback
                              atPosition:(PenteBannerPosition)position
                    canBeDismissedByUser:(BOOL)dismissingEnabled;

/// Position Top, no callback, no button.
+ (void)showNotificationInViewController:(UIViewController *)viewController
                                   title:(NSString *)title
                                subtitle:(nullable NSString *)subtitle
                                    type:(PenteBannerType)type
                                duration:(NSTimeInterval)duration
                    canBeDismissedByUser:(BOOL)dismissingEnabled;

/// Fades out the banner on screen, on the next main-queue turn, but only once it
/// has finished animating in; a banner still animating in ignores the call, as
/// in TSMessage. Returns NO when no banner is queued or showing, YES otherwise
/// (also when the call ends up ignored), as TSMessage does.
+ (BOOL)dismissActiveNotification;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
