//
//  SceneDelegate.m
//  test1
//

#import "SceneDelegate.h"
#import "GamesTableViewController.h"
#import "PenteNavigationViewController.h"

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
    NSLog(@"penteliveee: scene connected");
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
