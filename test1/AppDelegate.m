//
//  AppDelegate.m
//  test1
//
//  Created by Walied Othman on 23/07/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "AVFoundation/AVFoundation.h"
#import "BoardViewController.h"
#import "GamesTableViewController.h"
//@import Firebase;
@import RMStore;
#import "PenteNavigationViewController.h"
#import "SceneDelegate.h"
@import TSMessages;
@import UserNotifications;
#import "penteLive-Swift.h"

// Conformance lives here rather than in the header: nothing outside this file
// talks to the app delegate as a notification-centre delegate, and declaring it
// here keeps UserNotifications out of every translation unit that imports
// AppDelegate.h.
@interface AppDelegate () <UNUserNotificationCenterDelegate>
@end

@implementation AppDelegate {
    // Duplicate-suppression state for -handleRemoteNotificationUserInfo:; see
    // that method for why the payload itself is the key.
    NSDictionary *_lastHandledUserInfo;
    NSTimeInterval _lastHandledAt;
}
@synthesize notification;
@synthesize sndID, broadcastSndID;

#pragma mark - Window access

+ (PenteNavigationViewController *)rootNavigationController {
    // Deliberately avoids UIWindowScene's key-window property, which is iOS 15+.
    // -connectedScenes, UIWindowScene, -activationState and -windows are all
    // iOS 13, so nothing here constrains the deployment target above 13.0.
    UIWindowScene *active = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState ==
            UISceneActivationStateForegroundActive) {
            active = windowScene;
            break;
        }
        // Remember the first window scene seen, but keep looking for a
        // foreground-active one, which wins.
        if (active == nil) {
            active = windowScene;
        }
    }
    if (active == nil) {
        return nil;
    }

    // Prefer the scene delegate's own window (UIKit assigns it from
    // UISceneStoryboardFile); fall back to the scene's window list.
    UIWindow *window = nil;
    id<UISceneDelegate> sceneDelegate = active.delegate;
    if ([sceneDelegate isKindOfClass:[SceneDelegate class]]) {
        window = ((SceneDelegate *)sceneDelegate).window;
    }
    if (window == nil) {
        window = active.windows.firstObject;
    }

    UIViewController *root = window.rootViewController;
    if (![root isKindOfClass:[PenteNavigationViewController class]]) {
        return nil;
    }
    return (PenteNavigationViewController *)root;
}

#pragma mark - Application life cycle

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    if (@available(iOS 15.0, *)) {
        [UITableView appearance].sectionHeaderTopPadding = 0.0f;
    }

    if (![[NSUserDefaults standardUserDefaults]
            objectForKey:@"installationDate"]) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date]
                                                  forKey:@"installationDate"];
    }

    //    [[AVAudioSession sharedInstance]
    //    setCategory:AVAudioSessionCategoryAmbient error:nil];
    [[AVAudioSession sharedInstance]
        setCategory:AVAudioSessionCategoryAmbient
        withOptions:AVAudioSessionCategoryOptionMixWithOthers
              error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];

    if ([application
            respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        [application registerUserNotificationSettings:
                         [UIUserNotificationSettings
                             settingsForTypes:(UIUserNotificationTypeSound |
                                               UIUserNotificationTypeAlert |
                                               UIUserNotificationTypeBadge)
                                   categories:nil]];
        [application registerForRemoteNotifications];
    }

    // MUST be assigned before this method returns. When the app is launched by
    // a tapped notification, iOS delivers the response to this delegate during
    // launch; a delegate installed any later than here never sees it.
    //
    // Installing it also changes where foreground pushes land: with a delegate
    // present iOS calls
    // -userNotificationCenter:willPresentNotification:withCompletionHandler:
    // instead of the legacy -application:didReceiveRemoteNotification:. Both
    // are wired to the same -handleRemoteNotificationUserInfo:, so the
    // foreground banner/sound/refresh behaviour is unchanged.
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;

    //    else {
    //        [[UIApplication sharedApplication]
    //        registerForRemoteNotificationTypes:
    //         (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound |
    //         UIRemoteNotificationTypeAlert)];
    //    }

    // Kept only as the pre-scene fallback: under the UIScene life cycle UIKit
    // hands this method a nil launchOptions and puts the tapped payload on
    // UISceneConnectionOptions.notificationResponse instead, so on every
    // current launch this assigns nil. -[SceneDelegate
    // scene:willConnectToSession:options:] is what actually fills this in, and
    // it runs after this method but ~2 ms before -[PenteNavigationViewController
    // viewDidLoad] reads the property.
    notification = [launchOptions
        objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    //    NSLog(@"kitty1");
    //    if (notification)
    //    {
    //        NSLog(@"Launched from push notification: %@", notification);
    //    }

    NSString *penteSndPath =
        [[NSBundle mainBundle] pathForResource:@"penteLiveNotificationSound"
                                        ofType:@"caf"];
    NSURL *penteSndURL = [NSURL fileURLWithPath:penteSndPath];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)penteSndURL, &sndID);
    NSString *broadcastSndPath =
        [[NSBundle mainBundle] pathForResource:@"newplayer" ofType:@"caf"];
    NSURL *broadcastSndURL = [NSURL fileURLWithPath:broadcastSndPath];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)broadcastSndURL,
                                     &broadcastSndID);

    [[TSMessageView appearance] setContentTextColor:[UIColor blackColor]];
    [[TSMessageView appearance] setTitleTextColor:[UIColor blackColor]];

    [[TSMessageView appearance] setAlpha:0.9f];

    NSSet *products = [NSSet setWithArray:@[ @"1YRNOADSORLIMITS" ]];
    [[RMStore defaultStore] requestProducts:products
        success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
            // Async completion: resolve the scene root when the block runs, not
            // when it was created. This method runs before the scene connects.
            PenteNavigationViewController *nav =
                [AppDelegate rootNavigationController];
            for (SKProduct *product in products) {
                if ([product.productIdentifier
                        isEqualToString:@"1YRNOADSORLIMITS"]) {
                    [nav setSubscription:product];
                }
            }
        }
        failure:^(NSError *error) {
            NSLog(@"Something went wrong");
        }];

    if ([[NSUserDefaults standardUserDefaults]
            boolForKey:@"shouldSendReceipt"]) {
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];

        NSString *url =
            @"https://www.pente.org/gameServer/iOSReceiptValidation";
        NSString *postString = [NSString
            stringWithFormat:@"name=%@&receipt=%@",
                             [[NSUserDefaults standardUserDefaults]
                                 stringForKey:@"username"],
                             [self URLEncodedString_ch:
                                       [receipt
                                           base64EncodedStringWithOptions:0]]];

        NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding
                                    allowLossyConversion:YES];
        NSString *postLength = [NSString
            stringWithFormat:@"%lu", (unsigned long)[postData length]];

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded"
            forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:20.0];

        //    [request setHTTPShouldUsePipelining: YES];

        [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        NSString *dashboardString =
            [[NSString alloc] initWithData:responseData
                                  encoding:NSUTF8StringEncoding];
        //        NSLog(dashboardString);

        // Async completion: resolve the scene root when the block runs, not when
        // it was created — this method runs before the scene connects. The nil
        // guard is not optional: handed a nil presenting view controller,
        // TSMessage falls back to the app-wide key window's root view
        // controller, the deprecated API this migration is moving away from. An
        // early return keeps that path dormant.
        PenteNavigationViewController *nav =
            [AppDelegate rootNavigationController];
        if (!nav) {
            return;
        }

        if ([dashboardString containsString:@"success"]) {
            [[NSUserDefaults standardUserDefaults]
                setBool:NO
                 forKey:@"shouldSendReceipt"];
            [TSMessage
                showNotificationInViewController:nav
                                           title:NSLocalizedString(
                                                     @"Purchase registration "
                                                     @"successful",
                                                     nil)
                                        subtitle:nil
                                           image:nil
                                            type:
                                                TSMessageNotificationTypeSuccess
                                        duration:
                                            TSMessageNotificationDurationAutomatic
                                        callback:^{
                                            [TSMessage
                                                dismissActiveNotification];
                                        }
                                     buttonTitle:nil
                                  buttonCallback:nil
                                      atPosition:
                                          TSMessageNotificationPositionBottom
                            canBeDismissedByUser:YES];
        } else if ([dashboardString containsString:@"invalid receipt"]) {
            [[NSUserDefaults standardUserDefaults]
                setBool:NO
                 forKey:@"shouldSendReceipt"];
            [TSMessage
                showNotificationInViewController:nav
                                           title:NSLocalizedString(
                                                     @"Purchase restore failed",
                                                     nil)
                                        subtitle:
                                            NSLocalizedString(
                                                @"No valid purchase to restore",
                                                nil)
                                           image:nil
                                            type:
                                                TSMessageNotificationTypeSuccess
                                        duration:
                                            TSMessageNotificationDurationAutomatic
                                        callback:^{
                                            [TSMessage
                                                dismissActiveNotification];
                                        }
                                     buttonTitle:nil
                                  buttonCallback:nil
                                      atPosition:
                                          TSMessageNotificationPositionBottom
                            canBeDismissedByUser:YES];
        } else {
            [TSMessage
                showNotificationInViewController:nav
                                           title:NSLocalizedString(
                                                     @"Purchase registration "
                                                     @"failed",
                                                     nil)
                                        subtitle:
                                            NSLocalizedString(
                                                @"The app will retry purchase "
                                                @"registration at pente.org "
                                                @"every time the app starts",
                                                nil)
                                           image:nil
                                            type:
                                                TSMessageNotificationTypeWarning
                                        duration:
                                            TSMessageNotificationDurationAutomatic
                                        callback:^{
                                            [TSMessage
                                                dismissActiveNotification];
                                        }
                                     buttonTitle:nil
                                  buttonCallback:nil
                                      atPosition:
                                          TSMessageNotificationPositionBottom
                            canBeDismissedByUser:YES];
        }
        }];
    }

    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if
    // appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    //    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    //    [defaults removeObjectForKey:@"lastPing"];
    //    [defaults synchronize];
    if (deviceToken) {
        //        NSString *tokenString = [[[[NSString stringWithFormat:@"%@",
        //        deviceToken] stringByReplacingOccurrencesOfString:@" "
        //        withString:@""] stringByReplacingOccurrencesOfString:@">"
        //        withString:@""] stringByReplacingOccurrencesOfString:@"<"
        //        withString:@""];
        NSUInteger capacity = deviceToken.length * 2;
        NSMutableString *tokenString =
            [NSMutableString stringWithCapacity:capacity];
        const unsigned char *buf = deviceToken.bytes;
        NSInteger i;
        for (i = 0; i < deviceToken.length; ++i) {
            [tokenString appendFormat:@"%02X", (unsigned int)buf[i]];
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *storedTokenString = [defaults objectForKey:@"deviceToken"];
        if (storedTokenString) {
            if (![storedTokenString isEqualToString:tokenString]) {
                [defaults setObject:tokenString forKey:@"deviceToken"];
                [defaults removeObjectForKey:@"lastPing"];
                [defaults synchronize];
            }
        } else {
            [defaults setObject:tokenString forKey:@"deviceToken"];
        }
    }
}

- (void)application:(UIApplication *)application
    didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"Failed to get token, error: %@", error);
}

- (void)application:(UIApplication *)application
    didReceiveRemoteNotification:(NSDictionary *)userInfo {
    // Pre-scene / no-UN-delegate path. Retained rather than deleted so nothing
    // depends on iOS choosing one delivery route over the other; both routes
    // land in the single implementation below. Now that a notification-centre
    // delegate exists this is expected never to fire; the log says so out loud
    // rather than leaving it to inference.
    NSLog(@"penteliveee: push via legacy didReceiveRemote");
    [self handleRemoteNotificationUserInfo:userInfo];
}

/// Bounds-checked component access for the alert-body parsers below.
///
/// Notification bodies are assembled server-side from player-supplied text:
/// message subjects and display names both land inside the alert string
/// unfiltered. A parser that assumes its separator was present therefore
/// indexes past the end of the split array on the first hostile or merely
/// unexpected payload and raises NSRangeException. Returning nil instead lets
/// each arm fall back to showing the raw alert body.
static NSString *DSGAlertComponentOrNil(NSArray<NSString *> *components,
                                        NSUInteger index) {
    if (index >= [components count]) {
        return nil;
    }
    return [components objectAtIndex:index];
}

/// The one implementation of "a push arrived while the app is running".
///
/// Called from the legacy -application:didReceiveRemoteNotification: and from
/// -userNotificationCenter:willPresentNotification:withCompletionHandler:.
/// iOS calls only one of the two for any given push, but that is its choice,
/// not something the app can enforce, so the duplicate guard below makes a
/// second delivery of the same payload a no-op rather than a second banner and
/// a second sound.
- (void)handleRemoteNotificationUserInfo:(NSDictionary *)userInfo {
    //    NSLog(@"Received notification: %@", [userInfo
    //    objectForKey:@"gameID"]); [self
    //    addMessageFromRemoteNotification:userInfo updateUI:YES];

    //    NSLog(@"penteliveee: %@", userInfo);

    // Duplicate suppression. APNs exposes no stable per-push id to both entry
    // points, so the payload is the key: an identical dictionary arriving
    // within the window is treated as the same push redelivered. Two genuinely
    // distinct pushes always differ (gameID, setID or the alert body), and two
    // byte-identical ones inside a two-second window are not something the
    // server produces.
    static const NSTimeInterval kDuplicateWindow = 2.0;
    NSTimeInterval nowInterval = [NSDate timeIntervalSinceReferenceDate];
    if (userInfo != nil && _lastHandledUserInfo != nil &&
        [_lastHandledUserInfo isEqualToDictionary:userInfo] &&
        (nowInterval - _lastHandledAt) < kDuplicateWindow) {
        NSLog(@"penteliveee: duplicate notif suppressed");
        return;
    }
    _lastHandledUserInfo = [userInfo copy];
    _lastHandledAt = nowInterval;

    // One resolution for the whole method. Deliberately not guarded here: every
    // use below is a plain message send, which is a no-op on nil exactly as it
    // was when the retired app-global window was nil. The TSMessage
    // presentations at the end of the method get an explicit guard instead,
    // where nil actually matters.
    PenteNavigationViewController *nav = [AppDelegate rootNavigationController];

    UIApplication *application = [UIApplication sharedApplication];
    if (application.applicationState == UIApplicationStateInactive ||
        application.applicationState == UIApplicationStateBackground) {
        [nav setReceivedNotification:userInfo];
        NSLog(@"penteliveee: inactive notif %@", userInfo);
        return;
    }

    if ([userInfo objectForKey:@"silentNotification"]) {
        if ([nav.visibleViewController
                respondsToSelector:@selector(refreshDashboard)]) {
            [((GamesTableViewController *)(nav.visibleViewController))
                refreshDashboard];
        } else {
            [nav setDidMove:YES];
        }
        return;
    }

    NSString *message;
    if ([[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]
            isKindOfClass:[NSDictionary class]]) {
        message = [[[userInfo objectForKey:@"aps"] objectForKey:@"alert"]
            objectForKey:@"body"];
    } else {
        message = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
    }
    // The alert body is whatever JSON the payload carried. Every use below is a
    // string selector, so a non-string body would be an unrecognised-selector
    // crash rather than a wrong banner. nil stays nil: the string selectors are
    // all no-ops on nil, exactly as before.
    if (message != nil && ![message isKindOfClass:[NSString class]]) {
        message = [NSString stringWithFormat:@"%@", message];
    }

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"inAppSoundsOff"]) {
        if ([message containsString:@"Live Game Alert"] &&
            [message containsString:@"wants to play live"] &&
            [userInfo objectForKey:@"liveBroadCastPlayer"] &&
            [userInfo objectForKey:@"liveBroadCastGame"]) {
            AudioServicesPlaySystemSound(self.broadcastSndID);
        } else {
            AudioServicesPlaySystemSound(self.sndID);
        }
    }

    if ([nav.visibleViewController
            respondsToSelector:@selector(refreshDashboard)]) {
        [((GamesTableViewController *)nav.visibleViewController)
            refreshDashboard];
    } else {
        [nav setDidMove:YES];
    }

    NSString *title = @"";
    NSString *buttonTitle = @"close";

    // Which kind of push this is, decided on the payload's custom properties
    // rather than on the alert text.
    //
    // The server (CacheNotificationServer.java) tags every alerting push with
    // exactly one unambiguous property: a move push carries gameID, an
    // invitation carries setID, a private message carries msgID, and a live
    // invite carries liveBroadCastPlayer plus liveBroadCastGame. Registration
    // pushes carry none of them. Those keys are already what the dashboard
    // dispatches on (-[GamesTableViewController parseMessages]).
    //
    // Deciding on the text instead let a player choose which arm someone else's
    // app took, because the message subject is interpolated into the alert body
    // unfiltered: a subject reading "your move" steered a private message into
    // the move parser. Keys are not player-writable, so that misrouting is gone
    // rather than merely defused.
    //
    // The text tests are kept as the fallback for any payload that arrives
    // without a recognised key, so a push from an older or future server build
    // is classified exactly as it was before.
    BOOL hasGameID = [userInfo objectForKey:@"gameID"] != nil;
    BOOL hasMsgID = [userInfo objectForKey:@"msgID"] != nil;
    BOOL hasSetID = [userInfo objectForKey:@"setID"] != nil;
    BOOL hasLiveInvite =
        [userInfo objectForKey:@"liveBroadCastPlayer"] != nil &&
        [userInfo objectForKey:@"liveBroadCastGame"] != nil;
    BOOL isKeyed = hasGameID || hasMsgID || hasSetID || hasLiveInvite;

    BOOL isMove = isKeyed ? hasGameID : [message containsString:@"your move"];
    BOOL isNewMessage =
        isKeyed ? hasMsgID : [message containsString:@"new message"];
    BOOL isInvitation =
        isKeyed ? hasSetID : [message containsString:@"invited you"];

    if (isMove) {
        if ([nav.visibleViewController
                isKindOfClass:[BoardViewController class]]) {
            BoardViewController *vc =
                (BoardViewController *)nav.visibleViewController;
            if ([[[vc game] gameID]
                    isEqualToString:[userInfo objectForKey:@"gameID"]]) {
                [vc replayGame];
                return;
            }
        }
    }

    // Each arm below reformats the server's alert body into the app's own copy.
    // None of them may assume its separator was present: where the expected
    // structure is missing the arm leaves `message` as the raw alert body,
    // which is already a readable sentence, rather than indexing off the end of
    // the split array or substituting an empty string.
    if (isMove) {
        title = NSLocalizedString(@"It's your turn", nil);
        NSArray<NSString *> *splitStr = [[message
            stringByReplacingOccurrencesOfString:@"It's your move in a game of "
                                      withString:@""]
            componentsSeparatedByString:@" against "];
        NSString *gameName = DSGAlertComponentOrNil(splitStr, 0);
        NSString *opponent = DSGAlertComponentOrNil(splitStr, 1);
        if (gameName != nil && opponent != nil) {
            NSString *format = NSLocalizedString(
                @"It's your move against %@ in a game of %@.", nil);
            message = [NSString stringWithFormat:format, opponent, gameName];
        }
    } else if (isNewMessage) {
        NSArray<NSString *> *splitStr =
            [message componentsSeparatedByString:@" sent you a new message! "];
        NSString *sender = DSGAlertComponentOrNil(splitStr, 0);
        NSString *body = DSGAlertComponentOrNil(splitStr, 1);
        if (sender != nil && body != nil) {
            title = [NSString
                stringWithFormat:NSLocalizedString(@"New Message from %@", nil),
                                 sender];
            message = body;
        }
    } else if (isInvitation) {
        title = NSLocalizedString(@"New invitation", nil);
        NSArray<NSString *> *splitStr = [message
            componentsSeparatedByString:@" has invited you to a game of "];
        NSString *inviter = DSGAlertComponentOrNil(splitStr, 0);
        NSString *gameName = DSGAlertComponentOrNil(splitStr, 1);
        if (inviter != nil && gameName != nil) {
            NSString *format =
                NSLocalizedString(@"%@ has invited you to a game of %@.", nil);
            message = [NSString stringWithFormat:format, inviter, gameName];
        }
    } else if ([message containsString:@"Live Game Alert"] &&
               [message containsString:@"wants to play live"] &&
               [userInfo objectForKey:@"liveBroadCastPlayer"] &&
               [userInfo objectForKey:@"liveBroadCastGame"]) {
        title = NSLocalizedString(@"live game room alert", nil);
        NSString *player = [userInfo objectForKey:@"liveBroadCastPlayer"];
        NSString *game = [userInfo objectForKey:@"liveBroadCastGame"];
        message = [NSString
            stringWithFormat:NSLocalizedString(
                                 @"%@ wants to play a live game of %@.", nil),
                             player, game];
    }
    // Nil guard covering both TSMessage branches below. Not optional: handed a
    // nil presenting view controller, TSMessage falls back to the app-wide key
    // window's root view controller, the deprecated API this migration is moving
    // away from. An early return keeps that path dormant.
    if (!nav) {
        return;
    }

    // Registration pushes are the one family the server sends with no custom
    // property at all, so they are still recognised by their text - but only
    // when the payload carried no key that identifies it as something else.
    // Without that guard a player could put the registration sentence in a
    // message subject and replace someone else's banner with a fake one.
    if (isKeyed ||
        ![message
            containsString:@"device has been registered for notifications"]) {
        [TSMessage
            showNotificationInViewController:nav
            title:title
            subtitle:message
            image:nil
            type:TSMessageNotificationTypeMessage
            duration:TSMessageNotificationDurationAutomatic
            callback:^{
                // Re-resolved, NOT captured from the enclosing nav: this block
                // outlives the method, and the root can legitimately change
                // between the banner appearing and the user tapping it. This is
                // the only lifetime-sensitive window site in the file.
                PenteNavigationViewController *tappedNav =
                    [AppDelegate rootNavigationController];
                if (!tappedNav) {
                    return;
                }
                [tappedNav setReceivedNotification:userInfo];
                if ([tappedNav.visibleViewController
                        respondsToSelector:@selector(refreshDashboard)]) {
                    [((GamesTableViewController *)
                          tappedNav.visibleViewController) refreshDashboard];
                } else {
                    [tappedNav setDidMove:YES];
                    [tappedNav popToRootViewControllerAnimated:YES];
                }
            }
            buttonTitle:buttonTitle
            buttonCallback:^{
                [TSMessage dismissActiveNotification];
            }
            atPosition:TSMessageNotificationPositionBottom
            canBeDismissedByUser:YES];
    } else {
        [TSMessage
            showNotificationInViewController:nav
                                       title:NSLocalizedString(
                                                 @"Registration success!", nil)
                                    subtitle:
                                        NSLocalizedString(
                                            @"Your device has been registered "
                                            @"for push notifications",
                                            nil)
                                       image:nil
                                        type:TSMessageNotificationTypeSuccess
                                    duration:
                                        TSMessageNotificationDurationAutomatic
                                    callback:nil
                                 buttonTitle:buttonTitle
                              buttonCallback:^{
                                  [TSMessage dismissActiveNotification];
                              }
                                  atPosition:TSMessageNotificationPositionBottom
                        canBeDismissedByUser:YES];
    }
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)presentedNotification
         withCompletionHandler:
             (void (^)(UNNotificationPresentationOptions))completionHandler {
    // Where foreground pushes arrive now that a delegate exists. Same payload,
    // same handler, so the in-app TSMessage banner, the notification sound and
    // the dashboard refresh are literally the code that ran before.
    NSLog(@"penteliveee: push via UN willPresent");
    [self handleRemoteNotificationUserInfo:presentedNotification.request.content
                                              .userInfo];

    // None, not banner/sound: the app presents its own TSMessage banner and
    // plays its own sound (honouring the in-app sound preference). Asking iOS
    // to present as well would put a system banner on top of the TSMessage one
    // and play the push sound over the app's — exactly the double-handling this
    // change has to avoid. Suppressing the system presentation reproduces
    // pre-delegate behaviour, where iOS never displayed a foreground push.
    completionHandler(UNNotificationPresentationOptionNone);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler {
    // The only callback a tap produces when the app is suspended or in the
    // background: the scene is not reconnected, so
    // -scene:willConnectToSession:options: does not run, and the app is not
    // running in the foreground, so the legacy remote-notification method does
    // not run either.
    //
    // This deliberately does not navigate. It parks the payload where the
    // existing flow already looks for it, and the measured ordering does the
    // rest: this fires ~159 microseconds before -sceneWillEnterForeground:,
    // which calls -refreshDashboard, which calls -parseMessages, which reads
    // receivedNotification, navigates, and clears it.
    if (![response.actionIdentifier
            isEqualToString:UNNotificationDefaultActionIdentifier]) {
        // A dismissal, or a custom action the app does not define. Nothing to
        // deep-link to.
        completionHandler();
        return;
    }

    NSDictionary *userInfo = response.notification.request.content.userInfo;
    PenteNavigationViewController *nav = [AppDelegate rootNavigationController];
    if (nav) {
        NSLog(@"penteliveee: notif tap -> nav");
        [nav setReceivedNotification:userInfo];
    } else {
        // No scene yet. This is the cold-launch race: park it on the app
        // delegate, which -[PenteNavigationViewController viewDidLoad] copies
        // into receivedNotification. Harmlessly redundant with the
        // SceneDelegate's read of UISceneConnectionOptions.notificationResponse
        // — both assign the same payload.
        NSLog(@"penteliveee: notif tap -> appDelegate");
        self.notification = userInfo;
    }
    completionHandler();
}

#pragma mark - Helpers

- (NSString *)URLEncodedString_ch:(NSString *)input {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[input UTF8String];
    int sourceLen = (int)strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' ') {
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' ||
                   thisChar == '~' || (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

@end
