//
//  AppDelegate.m
//  test1
//
//  Created by Walied Othman on 23/07/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "AVFoundation/AVFoundation.h"
#import "GamesTableViewController.h"


@implementation AppDelegate

@synthesize window = _window;
@synthesize notification;
@synthesize sndID;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
    
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
        [application registerForRemoteNotifications];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
         (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
    
    notification = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
//    NSLog(@"kitty1");
//    if (notification)
//    {
//        NSLog(@"Launched from push notification: %@", notification);
//    }
    
    NSString *penteSndPath = [[NSBundle mainBundle] pathForResource:@"penteLiveNotificationSound" ofType:@"caf"];
    NSURL *penteSndURL = [NSURL fileURLWithPath:penteSndPath];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)penteSndURL, &sndID);
    
    [[TSMessageView appearance] setContentTextColor:[UIColor blackColor]];
    [[TSMessageView appearance] setTitleTextColor:[UIColor blackColor]];

    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"termsAccepted"]) {
        NSString *message =
        @"This app uses device identifiers to personalise content and ads, delivered by Google's Adsense network.";
        UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:@"Cookies"
                                   message:message
                                  delegate:self
                         cancelButtonTitle:nil
                         otherButtonTitles:@"Close message", nil];
        [alert show];
    }
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}



- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
    if (deviceToken) {
        NSString *tokenString = [[[[NSString stringWithFormat:@"%@", deviceToken] stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@">" withString:@""] stringByReplacingOccurrencesOfString:@"<" withString:@""];
//NSLog(@"My token is: %@", tokenString);
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *storedTokenString = [defaults objectForKey: @"deviceToken"];
        if (storedTokenString) {
            if (![storedTokenString isEqualToString:tokenString]) {
                [defaults setObject:tokenString forKey:@"deviceToken"];
                [defaults removeObjectForKey:@"lastPing"];
           }
        } else {
            [defaults setObject:tokenString forKey:@"deviceToken"];
        }
    }
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    NSLog(@"Failed to get token, error: %@", error);
}


- (void)application:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary*)userInfo
{
//    NSLog(@"Received notification: %@", [userInfo objectForKey:@"gameID"]);
//    [self addMessageFromRemoteNotification:userInfo updateUI:YES];
    AudioServicesPlaySystemSound(self.sndID);

    if ([((PenteNavigationViewController *)self.window.rootViewController).visibleViewController respondsToSelector:@selector(dashboardParse)]) {
        [((GamesTableViewController *)((PenteNavigationViewController *)self.window.rootViewController).visibleViewController) dashboardParse];
    } else {
        [(PenteNavigationViewController *)self.window.rootViewController setDidMove:YES];
    }

    NSString *message = [[userInfo objectForKey:@"aps"] objectForKey:@"alert"];
    NSString *title = @"";
    NSString *buttonTitle = @"close";
    if ([message rangeOfString:@"your move"].location != NSNotFound) {
        title = @"It's your turn";
    }
    if ([message rangeOfString:@"new message"].location != NSNotFound) {
        title = @"New Message";
    }
    if ([message rangeOfString:@"invited you"].location != NSNotFound) {
        title = @"New invitation";
    }
    if ([message rangeOfString:@"device has been registered for notifications"].location == NSNotFound) {
        [TSMessage showNotificationInViewController:self.window.rootViewController
                                              title: title
                                           subtitle: message
                                              image:nil
                                               type:TSMessageNotificationTypeMessage
                                           duration:TSMessageNotificationDurationAutomatic
                                           callback:^{
                                               [(PenteNavigationViewController *)self.window.rootViewController setReceivedNotification:userInfo];
                                               if ([((PenteNavigationViewController *)self.window.rootViewController).visibleViewController respondsToSelector:@selector(parseMessages)]) {
                                                   [((GamesTableViewController *)((PenteNavigationViewController *)self.window.rootViewController).visibleViewController) parseMessages];
                                               } else {
                                                   [(PenteNavigationViewController *)self.window.rootViewController setDidMove:YES];
                                                   [(PenteNavigationViewController *)self.window.rootViewController popToRootViewControllerAnimated:YES];
                                               }
                                           }
                                        buttonTitle:buttonTitle
                                     buttonCallback:^{
                                         [TSMessage dismissActiveNotification];
                                     }
                                         atPosition:TSMessageNotificationPositionBottom
                               canBeDismissedByUser:YES];
    } else {
        [TSMessage showNotificationInViewController:self.window.rootViewController
                                              title: title
                                           subtitle: message
                                              image:nil
                                               type:TSMessageNotificationTypeMessage
                                           duration:TSMessageNotificationDurationAutomatic
                                           callback:nil
                                        buttonTitle:buttonTitle
                                     buttonCallback:^{
                                         [TSMessage dismissActiveNotification];
                                     }
                                         atPosition:TSMessageNotificationPositionBottom
                               canBeDismissedByUser:YES];
    }

}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:@"termsAccepted"];
    [defaults synchronize];
}

@end
