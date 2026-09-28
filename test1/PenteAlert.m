#import "PenteAlert.h"
#import "AppDelegate.h"
#import "PenteNavigationViewController.h" // AppDelegate.h only forward-declares it

/// Blank root view controller of the overlay window. Portrait-only, like every
/// app view controller (they all return UIInterfaceOrientationMaskPortrait, and
/// Info.plist lists only Portrait). No status-bar overrides: no app view controller
/// overrides prefersStatusBarHidden/preferredStatusBarStyle either.
@interface PenteAlertHostViewController : UIViewController
@end

@implementation PenteAlertHostViewController
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}
@end

static const NSTimeInterval kPenteAlertRetryInterval = 0.25;

static NSMutableArray<UIAlertController *> *sQueue;  // waiting, FIFO
static UIAlertController *sCurrent;                  // on screen (or being presented)
static UIWindow *sWindow;                            // overlay; nil when nothing to show
static BOOL sPumpScheduled;

@implementation PenteAlert

+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message
    cancelButtonTitle:(NSString *)cancelButtonTitle {
    [self showWithTitle:title
                  message:message
        cancelButtonTitle:cancelButtonTitle
        otherButtonTitles:nil
                  handler:nil];
}

+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message
    cancelButtonTitle:(NSString *)cancelButtonTitle
    otherButtonTitles:(NSArray<NSString *> *)otherButtonTitles
              handler:(PenteAlertHandler)handler {
    if (![NSThread isMainThread]) { // UIKit objects may only be built on main
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showWithTitle:title
                          message:message
                cancelButtonTitle:cancelButtonTitle
                otherButtonTitles:otherButtonTitles
                          handler:handler];
        });
        return;
    }
    PenteAlertHandler h = [handler copy];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    // Cancel is added first. UIKit places a Cancel-style action where UIAlertView put
    // its cancel button (left of 2 buttons, bottom of a 3+ stack) whatever the order.
    [alert addAction:[UIAlertAction actionWithTitle:cancelButtonTitle
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *a) {
                                                [PenteAlert finishWithHandler:h index:0];
                                            }]];
    [otherButtonTitles enumerateObjectsUsingBlock:^(NSString *t, NSUInteger i, BOOL *stop) {
        [alert addAction:[UIAlertAction actionWithTitle:t
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
                                                    [PenteAlert finishWithHandler:h
                                                                            index:(NSInteger)i + 1];
                                                }]];
    }];
    if (sQueue == nil) sQueue = [NSMutableArray array];
    [sQueue addObject:alert]; // enqueued synchronously: FIFO order = call order
    [self schedulePumpAfter:0];
}

/// Runs from UIAlertAction's handler, i.e. after the alert has been dismissed.
+ (void)finishWithHandler:(PenteAlertHandler)h index:(NSInteger)index {
    sCurrent = nil;
    if (h) h(index);            // may enqueue a follow-up alert (Settings 1345, Games 4331)
    [self schedulePumpAfter:0]; // next alert, or tear the overlay down
}

+ (void)schedulePumpAfter:(NSTimeInterval)delay {
    if (sPumpScheduled) return;
    sPumpScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                       sPumpScheduled = NO;
                       [PenteAlert pump];
                   });
}

+ (void)pump {
    if (sCurrent != nil) return; // one at a time; its action handler pumps again
    if (sQueue.count == 0) {     // nothing left: remove the overlay so it never eats touches
        sWindow.hidden = YES;
        sWindow = nil;
        return;
    }
    UIWindowScene *scene = [AppDelegate rootNavigationController].viewIfLoaded.window.windowScene;
    if (scene == nil) { // before scene:willConnectToSession: - wait for the app window
        [self schedulePumpAfter:kPenteAlertRetryInterval];
        return;
    }
    if (sWindow != nil && sWindow.windowScene != scene) {
        sWindow.hidden = YES;
        sWindow = nil;
    }
    if (sWindow == nil) {
        sWindow = [[UIWindow alloc] initWithWindowScene:scene];
        sWindow.frame = scene.coordinateSpace.bounds;
        sWindow.windowLevel = UIWindowLevelAlert;
        sWindow.backgroundColor = [UIColor clearColor];
        sWindow.rootViewController = [[PenteAlertHostViewController alloc] init];
        sWindow.hidden = NO; // visible but deliberately NOT key; see design decisions
    }
    UIViewController *host = sWindow.rootViewController;
    if (host.presentedViewController != nil) { // previous alert still animating out
        [self schedulePumpAfter:kPenteAlertRetryInterval];
        return;
    }
    sCurrent = sQueue.firstObject;
    [sQueue removeObjectAtIndex:0];
    [host presentViewController:sCurrent animated:YES completion:nil];
}

@end
