//
//  SceneDelegate.m
//  test1
//

#import "SceneDelegate.h"
#import "AppDelegate.h"
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
    // UISceneStoryboardFile by the time this runs. Mirror it onto the
    // AppDelegate so the existing self.window.* call sites keep resolving.
    // Single-scene only: valid while UIApplicationSupportsMultipleScenes
    // is <false/>. Phase 2 replaces this with a real accessor.
    NSLog(@"penteliveee: scene connected");
    AppDelegate *appDelegate =
        (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.window = self.window;
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // appDelegate.window is strong, so without this the mirror outlives the
    // scene and every AppDelegate window site silently targets a detached
    // view hierarchy after a disconnect/reconnect cycle.
    AppDelegate *appDelegate =
        (AppDelegate *)[[UIApplication sharedApplication] delegate];
    if (appDelegate.window == self.window) {
        appDelegate.window = nil;
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
