#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// buttonIndex follows UIAlertView: 0 = the cancel button, 1...n = otherButtonTitles in order.
typedef void (^PenteAlertHandler)(NSInteger buttonIndex);

/// Replacement for UIAlertView. Shows a UIAlertControllerStyleAlert in a dedicated
/// alert-level overlay window on the app's window scene, one alert at a time, in FIFO
/// order, exactly like UIAlertView's own queue. Safe to call from any thread and from
/// any context (off-screen or deallocating view controllers, UIViews, alert handlers).
@interface PenteAlert : NSObject

+ (void)showWithTitle:(nullable NSString *)title
              message:(nullable NSString *)message
    cancelButtonTitle:(NSString *)cancelButtonTitle;

/// handler runs once, on the main thread, after the alert has been dismissed.
+ (void)showWithTitle:(nullable NSString *)title
              message:(nullable NSString *)message
    cancelButtonTitle:(NSString *)cancelButtonTitle
    otherButtonTitles:(nullable NSArray<NSString *> *)otherButtonTitles
              handler:(nullable PenteAlertHandler)handler;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
