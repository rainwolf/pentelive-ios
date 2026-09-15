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
#import "penteLive-Swift.h"

@implementation AppDelegate
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
    //    else {
    //        [[UIApplication sharedApplication]
    //        registerForRemoteNotificationTypes:
    //         (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound |
    //         UIRemoteNotificationTypeAlert)];
    //    }

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
    //    NSLog(@"Received notification: %@", [userInfo
    //    objectForKey:@"gameID"]); [self
    //    addMessageFromRemoteNotification:userInfo updateUI:YES];

    //    NSLog(@"penteliveee: %@", userInfo);
    // One resolution for the whole method. Deliberately not guarded here: every
    // use below is a plain message send, which is a no-op on nil exactly as it
    // was when the retired app-global window was nil. The TSMessage
    // presentations at the end of the method get an explicit guard instead,
    // where nil actually matters.
    PenteNavigationViewController *nav = [AppDelegate rootNavigationController];

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
    if ([message containsString:@"your move"]) {
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

    if ([message containsString:@"your move"]) {
        title = NSLocalizedString(@"It's your turn", nil);
        NSArray<NSString *> *splitStr = [[message
            stringByReplacingOccurrencesOfString:@"It's your move in a game of "
                                      withString:@""]
            componentsSeparatedByString:@" against "];
        message = [NSString
            stringWithFormat:NSLocalizedString(
                                 @"It's your move against %@ in a game of %@.",
                                 nil),
                             [splitStr objectAtIndex:1],
                             [splitStr objectAtIndex:0]];
    } else if ([message containsString:@"new message"]) {
        NSArray<NSString *> *splitStr =
            [message componentsSeparatedByString:@" sent you a new message! "];
        title = [NSString
            stringWithFormat:NSLocalizedString(@"New Message from %@", nil),
                             [splitStr objectAtIndex:0]];
        message = [splitStr objectAtIndex:1];
    } else if ([message containsString:@"invited you"]) {
        title = NSLocalizedString(@"New invitation", nil);
        NSArray<NSString *> *splitStr = [message
            componentsSeparatedByString:@" has invited you to a game of "];
        message = [NSString
            stringWithFormat:NSLocalizedString(
                                 @"%@ has invited you to a game of %@.", nil),
                             [splitStr objectAtIndex:0],
                             [splitStr objectAtIndex:1]];
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

    if (![message
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
