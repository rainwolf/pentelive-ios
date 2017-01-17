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
#import "BoardViewController.h"
@import Firebase;
#import "RMStore.h"


@implementation AppDelegate

@synthesize window = _window;
@synthesize notification;
@synthesize sndID;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
//    NSLog(@"kitty");

//    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionMixWithOthers error: nil];
    [[AVAudioSession sharedInstance] setActive:YES error: nil];
    
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
        NSLocalizedString(@"This app uses device identifiers to personalise content and ads, delivered by Google's Adsense network.",nil);
        UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cookies", nil)
                                   message:message
                                  delegate:self
                         cancelButtonTitle:nil
                         otherButtonTitles:NSLocalizedString(@"Close message",nil), nil];
        [alert show];
    }
    
    [FIRApp configure];


    NSSet *products = [NSSet setWithArray:@[@"1YRNOADSORLIMITS"]];
    [[RMStore defaultStore] requestProducts:products success:^(NSArray *products, NSArray *invalidProductIdentifiers) {
        for (SKProduct *product in products) {
            if ([product.productIdentifier isEqualToString:@"1YRNOADSORLIMITS"]) {
                    [((PenteNavigationViewController *)self.window.rootViewController) setSubscription:product];
            }
        }
    } failure:^(NSError *error) {
        NSLog(@"Something went wrong");
    }];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"shouldSendReceipt"]) {
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
        
        NSString *url = @"https://www.pente.org/gameServer/iOSReceiptValidation";
        NSString *postString = [NSString stringWithFormat:@"name=%@&receipt=%@", [[NSUserDefaults standardUserDefaults] stringForKey:@"username"], [self URLEncodedString_ch:[receipt base64EncodedStringWithOptions:0]]];
        
        NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:20.0];
        
        //    [request setHTTPShouldUsePipelining: YES];
        
        NSURLResponse *response;
        NSError *error;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//        NSLog(dashboardString);
        
        if ([dashboardString containsString:@"success"]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"shouldSendReceipt"];
            [TSMessage showNotificationInViewController:((PenteNavigationViewController *)self.window.rootViewController)
                                                  title: NSLocalizedString(@"Purchase registration successful",nil)
                                               subtitle: nil
                                                  image:nil
                                                   type: TSMessageNotificationTypeSuccess
                                               duration:TSMessageNotificationDurationAutomatic
                                               callback: ^{
                                                   [TSMessage dismissActiveNotification];
                                               }
                                            buttonTitle: nil
                                         buttonCallback:nil
                                             atPosition:TSMessageNotificationPositionBottom
                                   canBeDismissedByUser:YES];
        } else {
            [TSMessage showNotificationInViewController:((PenteNavigationViewController *)self.window.rootViewController)
                                                  title: NSLocalizedString(@"Purchase registration failed",nil)
                                               subtitle: NSLocalizedString(@"The app will retry purchase registration at pente.org every time the app starts",nil)
                                                  image:nil
                                                   type: TSMessageNotificationTypeWarning
                                               duration:TSMessageNotificationDurationAutomatic
                                               callback: ^{
                                                   [TSMessage dismissActiveNotification];
                                               }
                                            buttonTitle: nil
                                         buttonCallback:nil
                                             atPosition:TSMessageNotificationPositionBottom
                                   canBeDismissedByUser:YES];
        }

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
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults removeObjectForKey:@"lastPing"];
//    [defaults synchronize];
    if (deviceToken) {
        NSString *tokenString = [[[[NSString stringWithFormat:@"%@", deviceToken] stringByReplacingOccurrencesOfString:@" " withString:@""] stringByReplacingOccurrencesOfString:@">" withString:@""] stringByReplacingOccurrencesOfString:@"<" withString:@""];
//NSLog(@"My token is: %@", tokenString);
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *storedTokenString = [defaults objectForKey: @"deviceToken"];
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
        if ([((PenteNavigationViewController *)self.window.rootViewController).visibleViewController isKindOfClass:[BoardViewController class]]) {
            BoardViewController *vc = (BoardViewController *) ((PenteNavigationViewController *)self.window.rootViewController).visibleViewController;
            if ([[[vc game] gameID] isEqualToString: [userInfo objectForKey:@"gameID"]]) {
                [vc replayGame];
                return;
            }
        }
    }

    if ([message containsString:@"your move"]) {
        title = NSLocalizedString(@"It's your turn",nil);
        NSArray<NSString *>* splitStr = [[message stringByReplacingOccurrencesOfString:@"It's your move in a game of " withString:@""] componentsSeparatedByString:@" against "];
        message = [NSString stringWithFormat:NSLocalizedString(@"It's your move against %@ in a game of %@.", nil), [splitStr objectAtIndex:1], [splitStr objectAtIndex:0]];
    } else if ([message containsString:@"new message"]) {
        NSArray<NSString *>* splitStr = [message componentsSeparatedByString:@" sent you a new message! "];
        title = [NSString stringWithFormat:NSLocalizedString(@"New Message from %@",nil), [splitStr objectAtIndex:0]];
        message = [splitStr objectAtIndex:1];
    } else if ([message containsString:@"invited you"]) {
        title = NSLocalizedString(@"New invitation",nil);
        NSArray<NSString *>* splitStr = [message componentsSeparatedByString:@" has invited you to a game of "];
        message = [NSString stringWithFormat:NSLocalizedString(@"%@ has invited you to a game of %@.", nil), [splitStr objectAtIndex:0], [splitStr objectAtIndex:1]];
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
                                              title: NSLocalizedString(@"Registration success!", nil)
                                           subtitle: NSLocalizedString(@"Your device has been registered for push notifications", nil)
                                              image:nil
                                               type:TSMessageNotificationTypeSuccess
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

- (NSString *) URLEncodedString_ch: (NSString *) input{
    NSMutableString * output = [NSMutableString string];
    const unsigned char * source = (const unsigned char *)[input UTF8String];
    int sourceLen = (int) strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
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
