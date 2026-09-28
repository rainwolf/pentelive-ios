#import "PenteAlert.h"

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

/// The overlay window. Touches that land on the window itself or on the host's
/// blank root view fall through to the app below, so the overlay never blocks
/// the app while no alert is on screen (queue being pumped, previous alert
/// animating out, or a presentation that never landed). A presented alert lives
/// in UIKit's presentation container, a sibling of the host view directly under
/// the window, so its dimming view is still what a touch outside the alert
/// hits, and it blocks.
@interface PenteAlertWindow : UIWindow
@end

@implementation PenteAlertWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.viewIfLoaded) {
        return nil;
    }
    return hit;
}

/// Keeps VoiceOver out of the app underneath, but only while an alert is
/// actually presented, so an empty overlay never traps VoiceOver the way it no
/// longer traps touches.
- (BOOL)accessibilityViewIsModal {
    return self.rootViewController.presentedViewController != nil;
}
@end

static const NSTimeInterval kPenteAlertRetryInterval = 0.25;

static NSMutableArray<UIAlertController *> *sQueue;  // waiting, FIFO
static UIAlertController *sCurrent;                  // on screen (or being presented)
static UIWindow *sWindow;                            // overlay; nil when nothing to show
static BOOL sPumpScheduled;

static NSInteger PenteAlertSceneRank(UIScene *scene) {
    switch (scene.activationState) {
    case UISceneActivationStateForegroundActive:
        return 0;
    case UISceneActivationStateForegroundInactive:
        return 1;
    default:
        return 2;
    }
}

/// The app's own window, resolved through the connected scenes rather than
/// through the root navigation controller's view, which has no window while a
/// full-screen modal (e.g. the camera picker) covers it. nil until a scene has
/// connected.
static UIWindow *PenteAlertAppWindow(void) {
    // Foreground-active wins, then foreground-inactive, then the first seen.
    UIWindowScene *best = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        if (best == nil ||
            PenteAlertSceneRank(scene) < PenteAlertSceneRank(best)) {
            best = (UIWindowScene *)scene;
        }
    }
    // Prefer the scene delegate's window (SceneDelegate, built by UIKit from
    // UISceneStoryboardFile); fall back to the scene's first normal-level one.
    id<UISceneDelegate> delegate = best.delegate;
    if ([delegate respondsToSelector:@selector(window)]) {
        UIWindow *window = ((id<UIWindowSceneDelegate>)delegate).window;
        if (window != nil) {
            return window;
        }
    }
    for (UIWindow *window in best.windows) {
        if (window != sWindow && window.windowLevel == UIWindowLevelNormal) {
            return window;
        }
    }
    return nil;
}

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
    UIWindow *appWindow = PenteAlertAppWindow();
    UIWindowScene *scene = appWindow.windowScene;
    if (scene == nil) { // before scene:willConnectToSession: - wait for the app window
        [self schedulePumpAfter:kPenteAlertRetryInterval];
        return;
    }
    if (sWindow != nil && sWindow.windowScene != scene) {
        sWindow.hidden = YES;
        sWindow = nil;
    }
    if (sWindow == nil) {
        sWindow = [[PenteAlertWindow alloc] initWithWindowScene:scene];
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
    // The overlay is never key, so the app window keeps its first responder and
    // the keyboard, whose window sits above UIWindowLevelAlert, could cover the
    // alert's buttons. UIAlertView's key window dismissed it; do the same, per
    // alert.
    [appWindow endEditing:YES];
    [host presentViewController:sCurrent animated:YES completion:nil];
}

@end
