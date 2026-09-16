//
//  SceneDelegate.m
//  test1
//

#import "SceneDelegate.h"
#import "AppDelegate.h"
#import "GamesTableViewController.h"
#import "PenteNavigationViewController.h"
@import UserNotifications;

@implementation SceneDelegate {
    BOOL _hasBackgrounded;
}
@synthesize window = _window;

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
    // UIKit has already built self.window and its rootViewController from
    // UISceneStoryboardFile by the time this runs. Phase 1's mirror onto
    // AppDelegate.window is gone: call sites now ask
    // +[AppDelegate rootNavigationController], which resolves this window
    // through the scene at the moment it is needed. sceneDidDisconnect: went
    // with the mirror — it existed only to stop the strong app-global reference
    // outliving its scene, and there is no longer such a reference.

    // Cold launch from a tapped push. Under the scene life cycle UIKit hands
    // -application:didFinishLaunchingWithOptions: a nil launchOptions and puts
    // the payload here instead, which is why the app delegate's
    // UIApplicationLaunchOptionsRemoteNotificationKey read has been coming back
    // nil. Parking it on the app delegate now works because this method
    // finishes ~2 ms before -[PenteNavigationViewController viewDidLoad] copies
    // that property into receivedNotification; -parseMessages then finds it and
    // navigates, exactly as it did before the scene migration.
    UNNotificationResponse *response = connectionOptions.notificationResponse;
    if (response != nil &&
        [response.actionIdentifier
            isEqualToString:UNNotificationDefaultActionIdentifier]) {
        AppDelegate *appDelegate =
            (AppDelegate *)[UIApplication sharedApplication].delegate;
        appDelegate.notification =
            response.notification.request.content.userInfo;
    }
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    _hasBackgrounded = YES;
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // GUARD, NOT OPTIONAL: unlike applicationWillEnterForeground:,
    // sceneWillEnterForeground: also fires on first connection, i.e. at cold
    // launch. Running the body then is a new behaviour — see note below.
    if (!_hasBackgrounded) {
        return;
    }
    NSLog(@"penteliveee: foreground");
    PenteNavigationViewController *nav =
        (PenteNavigationViewController *)self.window.rootViewController;
    if ([nav.visibleViewController
            respondsToSelector:@selector(refreshDashboard)]) {
        [((GamesTableViewController *)nav.visibleViewController)
            refreshDashboard];
    } else {
        [nav setDidMove:YES];
        [nav popToRootViewControllerAnimated:YES];
    }
}

@end
