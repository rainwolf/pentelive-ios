//
//  SettingsViewController.m
//  test1
//
//  Created by rainwolf on 28/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "SettingsViewController.h"
#import "IASKSettingsReader.h"
#import "GamesTableViewController.h"
#import "ChangeColorViewController.h"
#import "RMStore.h"
#import "penteLive-Swift.h"
#import "MMAIViewController.h"
@import TSMessages;


#define usernameKey @"username"
#define passwordKey @"password"

@interface SettingsViewController ()

@end

@implementation SettingsViewController {
    UIImagePickerController *picker;
    BOOL subscribing;
}
@synthesize username;
@synthesize password;
@synthesize popoverView;
@synthesize progressView;
@synthesize navC;
@synthesize showAIOption;



//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
//{
//    self = [super initWithNibName:@"IASKAppSettingsViewController" bundle:nibBundleOrNil];
//    if (self) {
//        // Custom initialization
//    }
//    return self;
//}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return ((interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown)
            && (interfaceOrientation != UIInterfaceOrientationLandscapeLeft) && (interfaceOrientation != UIInterfaceOrientationLandscapeRight));
}
-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
    //    return UIInterfaceOrientationLandscapeLeft | UIInterfaceOrientationLandscapeRight | UIInterfaceOrientationPortrait;
}
- (id)initWithFile:(NSString*)file specifier:(IASKSpecifier*)specifier {
    if ((self = [super init])) {
        // custom initialization
        [self setFile:file];
        
        [self setShowDoneButton:NO];
    }
    return self;
}

- (void)viewDidLoad
{
    subscribing = NO;
	// Do any additional setup after loading the view.
    if ([self.navigationController isKindOfClass:[PenteNavigationViewController class]]) {
//        NSLog(@"kitty navigationController");
        self.navC = (PenteNavigationViewController *) self.navigationController;
    } else {
        if ([[UIApplication sharedApplication].keyWindow.rootViewController isKindOfClass:[PenteNavigationViewController class]]) {
//            NSLog(@"kitty rootViewController");
            [self setNavC:(PenteNavigationViewController *) [UIApplication sharedApplication].keyWindow.rootViewController];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"registrationSuccess"]) {
//        NSLog([[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]] textLabel] text]);
//        NSLog(NSLocalizedString(@"Username:",nil));
        if ([[[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]] textLabel] text] isEqualToString:NSLocalizedString(@"Username:",nil)]) {
            [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]].userInteractionEnabled = NO;
        }
        if ([[[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:1 inSection:1]] textLabel] text] isEqualToString:NSLocalizedString(@"Password:",nil)]) {
            [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:1 inSection:1]].userInteractionEnabled = NO;
        }
    }
    if (self.navC.showSubscribe) {
        [self showSubscribeInfo];
    } else if (showAIOption) {
        showAIOption = NO;
        [self showAIOptionDialog];
    }
//    NSLog([NSString stringWithFormat:@"kitty viewDidAppear %@",[self navC]]);
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"registrationSuccess"]) {
        if ([[[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]] textLabel] text] isEqualToString:NSLocalizedString(@"Username:",nil)]) {
            [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]].userInteractionEnabled = NO;
        }
        if ([[[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:1 inSection:1]] textLabel] text] isEqualToString:NSLocalizedString(@"Password:",nil)]) {
            [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:1 inSection:1]].userInteractionEnabled = NO;
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"registrationSuccess"]) {
        if (self.navC.player && self.navC.player.subscriber) {
            self.hiddenKeys = [NSSet setWithObjects:@"RestorePurchaseButton",@"SubscribeButton",@"SignUpButton", @"SignUpLabel", @"personalizeAds", nil];
            //            self.hiddenKeys = [NSSet setWithObjects:@"SignUpButton", @"SignUpLabel", nil];
        } else {
            self.hiddenKeys = [NSSet setWithObjects:@"SignUpButton",@"manageSubscriptions", @"SignUpLabel", nil];
        }
    } else {
        self.hiddenKeys = [NSSet setWithObjects:@"RestorePurchaseButton",@"SubscribeButton",@"manageSubscriptions", nil];
    }
    [self setShowCreditsFooter:YES];
    [self setTitle:@"Settings"];
    [self.tableView setSeparatorColor:[UIColor blueColor]];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    [self setDelegate:self];
//    NSLog([NSString stringWithFormat:@"kitty1 %@",[self navC]]);
//    NSLog([NSString stringWithFormat:@"kitty2 %@",self.navigationController]);
//    NSLog([NSString stringWithFormat:@"kitty4 %@",self.parentViewController]);
    [super viewDidLoad];
//    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"shouldSendReceipt"];
//    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
//    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
//    
//    NSString *url = @"https://www.pente.org/gameServer/iOSReceiptValidation";
//    NSString *postString = [NSString stringWithFormat:@"name=%@&receipt=%@", [[NSUserDefaults standardUserDefaults] stringForKey:usernameKey], [self URLEncodedString_ch:[receipt base64EncodedStringWithOptions:0]]];
//    
//    NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
//    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
//    
//    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
//    [request setURL:[NSURL URLWithString:url]];
//    [request setHTTPMethod:@"POST"];
//    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
//    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
//    [request setHTTPBody:postData];
//    [request setTimeoutInterval:20.0];
//    
//    //    [request setHTTPShouldUsePipelining: YES];
//    
//    NSURLResponse *response;
//    NSError *error;
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//    NSLog(dashboardString);
//    
//    [progressView stopAnimating];
//    [progressView removeFromSuperview];
//    if ([dashboardString containsString:@"success"]) {
//        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"shouldSendReceipt"];
//        [TSMessage showNotificationInViewController:self.navigationController
//                                              title: @"Purchase registration successful"
//                                           subtitle: nil
//                                              image:nil
//                                               type: TSMessageNotificationTypeSuccess
//                                           duration:TSMessageNotificationDurationAutomatic
//                                           callback: ^{
//                                               [TSMessage dismissActiveNotification];
//                                           }
//                                        buttonTitle: nil
//                                     buttonCallback:nil
//                                         atPosition:TSMessageNotificationPositionBottom
//                               canBeDismissedByUser:YES];
//    } else {
//        [TSMessage showNotificationInViewController:self.navigationController
//                                              title: @"Purchase registration failed"
//                                           subtitle: @"The app will retry purchase registration at pente.org every time the app starts"
//                                              image:nil
//                                               type: TSMessageNotificationTypeWarning
//                                           duration:TSMessageNotificationDurationAutomatic
//                                           callback: ^{
//                                               [TSMessage dismissActiveNotification];
//                                           }
//                                        buttonTitle: nil
//                                     buttonCallback:nil
//                                         atPosition:TSMessageNotificationPositionBottom
//                               canBeDismissedByUser:YES];
//    }
//
    
    [super viewWillAppear:animated];
    
    if (!self.navC.loggedIn) {
//        self.navigationItem.hidesBackButton = YES;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    username = [defaults objectForKey:usernameKey];
    password = [defaults objectForKey:passwordKey];
//    [self.tableView setScrollEnabled:NO];
//    NSLog(@"kittyyyyyy %@", self.settingsReader.settingsBundle);
}

- (void)viewWillDisappear:(BOOL)animated {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject: username forKey:usernameKey];
    [defaults setObject: password forKey:passwordKey];

    [self checkAndUpdateSettings];
    [super viewWillDisappear:animated];
}


- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    if ([specifier.key isEqualToString:@"LoginButton"]) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            username = [defaults objectForKey:usernameKey];
            password = [defaults objectForKey:passwordKey];
//                    NSLog(@"kittyyyyyy %@ %@", username, password);
            if (!((username == nil) || (password == nil) || [username isEqualToString:@""] || [password isEqualToString:@""])) {
                NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                NSString *url = @"https://www.pente.org/gameServer/logout";
                [request setURL:[NSURL URLWithString:url]];
                [request setHTTPMethod:@"GET"];
                [request setTimeoutInterval:7.0];
                NSURLResponse *response;
                NSError *error;
                NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
                // connect to the game server
                request = [[NSMutableURLRequest alloc] init];
                url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/index.jsp?name2=%@&password2=%@",username,password];
                if (development) {
                    url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/index.jsp?name2=%@&password2=%@",username,password];
                }
                [request setURL:[NSURL URLWithString:url]];
                [request setHTTPMethod:@"POST"];
                [request setTimeoutInterval:7.0];
                responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                //            NSLog(@"kittyyyyyyString -%@-", dashboardString);
    
                if (error) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat: NSLocalizedString(@"Trouble connecting to pente.org, please try again in a bit.\nReason: %@", nil),  error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                } else if ([dashboardString isEqualToString:@""]) {
                    [self.navC setLoggedIn: NO];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"pente.org appears to be down, please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
    
                } else if ([dashboardString rangeOfString:@"Invalid name or password, please try again."].length != 0) {
                    [self.navC setLoggedIn: NO];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Wrong username or password", nil) message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                } else if ([dashboardString rangeOfString:@"<h2>Pente.org is undergoing maintenance.</h2>"].length != 0) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Maintenance" message:@"pente.org is undergoing maintenance, please try again in a few minutes." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                } else {
                    [self.navC setLoggedIn: YES];
                    [self.navC setDidMove: YES];
//                    [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
                    [self.navigationController popToRootViewControllerAnimated:YES];
                }
            }
    }
    if ([specifier.key isEqualToString:@"SignupButton"]) {
        NSCharacterSet *testChars = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        username = [defaults objectForKey:usernameKey];
        password = [defaults objectForKey:passwordKey];
        NSString *emailAddress = [defaults objectForKey:@"emailAddress"];
        NSString *passwordVerification = [defaults objectForKey:@"passwordVerification"];
//        NSLog(@"kitty %@", username);
        if (((username == nil) || ![[username stringByTrimmingCharactersInSet:testChars] isEqualToString:@""] || ([username length] < 5) || ([username length] > 10))) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:NSLocalizedString(@"Please enter a username, 5 to 10 characters long and consisting of letters, digits, and underscores only.",nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
        if (((password == nil) || ![[password stringByTrimmingCharactersInSet:testChars] isEqualToString:@""] || ([password length] < 5) || ([password length] > 16))) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:NSLocalizedString(@"Please enter a password, 5 to 16 characters long and consisting of letters, digits, and underscores only.", nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
        if (![passwordVerification isEqualToString:password]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:NSLocalizedString(@"Passwords don't match.", nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
        if (emailAddress.length == 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:NSLocalizedString(@"No email address provided.", nil) delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
        if (![defaults boolForKey:@"RatedPlayPolicyAccepted"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"You have to agree to Pente.org's Rated Play Policy before signing up." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }

        NSString *url = @"https://www.pente.org/join";
        if (development) {
            url = @"https://development.pente.org/join";
        }
        NSString *postString = [NSString stringWithFormat:@"name=%@&registerPassword=%@&registerPasswordConfirm=%@&registerEmail=%@&agreePolicy=Y",username, password, passwordVerification, [self URLEncodedString_ch:emailAddress]];
        
        NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        
        [request setHTTPShouldUsePipelining: YES];
        
        NSURLResponse *response;
        NSError *error;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

//                        NSLog(@"kittyyyyyyString -%@-", dashboardString);
        
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:@"Reason: %@", error.localizedDescription] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
            //        [alert show];
            [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
            return;
        } else if ([dashboardString isEqualToString:@""]) {
                [self.navC setLoggedIn: NO];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:@"pente.org appears to be down, please try again later." delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
                [alert show];
                
            } else if ([dashboardString rangeOfString:@" is already taken, please choose another."].length != 0) {
                [self.navC setLoggedIn: NO];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"The username %@ is already taken, please choose another.", nil),username] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
                [alert show];
            } else if ([dashboardString rangeOfString:@"<h2>Pente.org is undergoing maintenance.</h2>"].length != 0) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Maintenance" message:@"pente.org is undergoing maintenance, please try again in a few minutes." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            } else {
                [defaults removeObjectForKey:@"emailAddress"];
                [defaults removeObjectForKey:@"passwordVerification"];
                [defaults setBool:NO forKey:@"RatedPlayPolicyAccepted"];
                [self.navC setLoggedIn: YES];
                [self.navC setDidMove: YES];
                [self.navigationController popToRootViewControllerAnimated:YES];
            }
    }
//    if ([specifier.key isEqualToString:@"MoreSettingsButton"]) {
//        NSLog(@"kittyyyyyy");
//        SettingsViewController *vc = [[SettingsViewController alloc] initWithFile:@"MoreSettings" specifier: specifier];
//        [self.navC pushViewController:vc animated:YES];
//    }
    if ([specifier.key isEqualToString:@"HelpButton"]) {
        if (![self.navC loggedIn]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:NSLocalizedString(@"You need to be logged in to send a help message. Send an email instead?", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", nil) otherButtonTitles:NSLocalizedString(@"Email",nil),nil];
            [alert setTag:1];
            [alert show];
            return;
        }
        
        [self.navC setNeedHelp:YES];
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
    if ([specifier.key isEqualToString:@"inviteFriendsButton"]) {
        if ([MFMailComposeViewController canSendMail]) {
            MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
            mailer.mailComposeDelegate = self;
            [mailer setSubject: NSLocalizedString(@"Play Pente with me?", nil)];
//            NSArray *toRecipients = [NSArray arrayWithObjects:@"rainwolf@submanifold.be", nil];
//            [mailer setToRecipients:toRecipients];
            [mailer setMessageBody: [NSString stringWithFormat:NSLocalizedString(@"<p>You can play with me on your <a href=\"https://itunes.apple.com/us/app/pente-live/id595426592?ls=1&mt=8\">iPhone</a> or <a href=\"https://play.google.com/store/apps/details?id=be.submanifold.pentelive\">Android Phone</a> <br> My username is %@",nil), [[NSUserDefaults standardUserDefaults] objectForKey:@"username"]] isHTML:YES];
            [self presentViewController:mailer animated:YES completion:nil];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                            message:NSLocalizedString(@"Your device is not configured to send mail", nil)
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                  otherButtonTitles:nil];
            [alert show];
        }
        return;
    }
    if ([specifier.key isEqualToString:@"GameRulesButton"]) {
        PenteWebViewController *webViewController = [[PenteWebViewController alloc] initWithAddress: @"https://www.pente.org/help/playGameRulesMobile.jsp"];
        [self.navigationController pushViewController:webViewController animated:YES];
    }
    if ([specifier.key isEqualToString:@"penteOrgPreferencesButton"]) {
        PenteWebViewController *webViewController = [[PenteWebViewController alloc] initWithAddress: @"https://www.pente.org/gameServer/myprofile/prefs"];
        [self.navigationController pushViewController:webViewController animated:YES];
    }
    if ([specifier.key isEqualToString:@"penteOrgPrivacyPolicyButton"]) {
        PenteWebViewController *webViewController = [[PenteWebViewController alloc] initWithAddress: @"https://www.pente.org/help/helpWindow.jsp?file=privacyPolicy"];
        [self.navigationController pushViewController:webViewController animated:YES];
    }
    if ([specifier.key isEqualToString:@"changeColorButton"]) {
//        NSLog([NSString stringWithFormat:@"kitty wth %@", self.navC]);
        if (!self.navC.player.subscriber) {
            return;
        }
        ChangeColorViewController *vc = [[ChangeColorViewController alloc] initWithColor:((PenteNavigationViewController *) self.navigationController).player.myColor];
        [self.navigationController pushViewController:vc animated:YES];
    }
    if ([specifier.key isEqualToString:@"changeAvatarButton"]) {
//        NSLog([NSString stringWithFormat:@"kitty wth %@", self.navC]);
        if (!self.navC.player.subscriber) {
            return;
        }
        picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        
        UIAlertController *keyXController = [UIAlertController
                                             alertControllerWithTitle:nil
                                             message: nil
                                             preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            NSLog(@"Cancel action");
            
        }];
        UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Take a picture", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            picker.sourceType = UIImagePickerControllerSourceTypeCamera;
            [self presentViewController:picker animated:YES completion:nil];
        }];
        UIAlertAction *albumAction = [UIAlertAction actionWithTitle: NSLocalizedString(@"Choose from library", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            [self presentViewController:picker animated:YES completion:nil];
        }];
        [keyXController addAction:cancelAction];
        [keyXController addAction:cameraAction];
        [keyXController addAction:albumAction];
        
        [self presentViewController:keyXController animated:YES completion:nil];
    }
    if ([specifier.key isEqualToString:@"SubscribeButton"]) {
        [self showSubscribeInfo];
    }
    if ([specifier.key isEqualToString:@"RestorePurchaseButton"]) {
        [self restorePurchase];
    }
    
    if ([[specifier type] isEqualToString:kIASKOpenURLSpecifier]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:specifier.file]];
    }
}

-(void) showSubscribeInfo {
    ((PenteNavigationViewController *) self.navigationController).showSubscribe = NO;
    if (self.navC.subscription == nil) {
        return;
    }
    SKProduct *product = self.navC.subscription;
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString *formattedPrice = [numberFormatter stringFromNumber:product.price];
    
    UILabel *subscribeText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*9/10, CGFLOAT_MAX)];
    [subscribeText setLineBreakMode:NSLineBreakByWordWrapping];
    [subscribeText setNumberOfLines:0];
    NSString *subscribeString = NSLocalizedString(@"\u2022 remove play limits\n\u2022 request undo in turn-based games\n\u2022 see no more ads\n\u2022 change your name color or avatar\n\u2022 access the database!", nil);
    [subscribeText setText:subscribeString];
    [subscribeText sizeToFit];
    
    //        UILabel *priceText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*9/10, CGFLOAT_MAX)];
    UILabel *priceText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*9/10, 50)];
    [priceText setLineBreakMode:NSLineBreakByWordWrapping];
    [priceText setNumberOfLines:0];
    NSString *priceString = [NSString stringWithFormat:NSLocalizedString(@"only %@ / year", nil), formattedPrice];
    //        [priceText setAdjustsFontSizeToFitWidth:YES];
    [priceText setText:priceString];
    [priceText setFont:[UIFont systemFontOfSize: 23]];
    [priceText setTextColor:[UIColor orangeColor]];
    [priceText sizeToFit];
    
    UILabel *clearInfoText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*9/10, CGFLOAT_MAX)];
    [clearInfoText setLineBreakMode:NSLineBreakByWordWrapping];
    [clearInfoText setNumberOfLines:0];
    NSString *clearInfoString = NSLocalizedString(@"(This subscription auto-renews every year and can be canceled up to 24hrs before renewal. Payment will be charged on your iTunes account. Renewal will occur 24hrs before the end of the subscription period at the same cost. Subscriptions can be canceled in the settings with \"Manage Subscription\".)", nil);
    [clearInfoText setText:clearInfoString];
    [clearInfoText setFont:[UIFont systemFontOfSize: 12]];
    [clearInfoText sizeToFit];
    
    UILabel *privacyPolicyAndTOSText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*9/10, CGFLOAT_MAX)];
    [privacyPolicyAndTOSText setLineBreakMode:NSLineBreakByTruncatingTail];
    [privacyPolicyAndTOSText setNumberOfLines:1];
    NSString *privacyPolicyAndTOSString = NSLocalizedString(@"View our Privacy Policy and TOS", nil);
    NSMutableAttributedString *attStr = [[NSMutableAttributedString alloc] initWithString:privacyPolicyAndTOSString];
    [attStr addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(0, privacyPolicyAndTOSString.length)];
    [attStr addAttribute:NSUnderlineStyleAttributeName value: @(NSUnderlineStyleSingle) range:NSMakeRange(0, privacyPolicyAndTOSString.length)];
    [privacyPolicyAndTOSText setAttributedText:attStr];
    [privacyPolicyAndTOSText setFont:[UIFont systemFontOfSize: 16]];
    [privacyPolicyAndTOSText sizeToFit];
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPrivacyPolicyAndTOS)];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    [privacyPolicyAndTOSText addGestureRecognizer:tapGestureRecognizer];
    privacyPolicyAndTOSText.userInteractionEnabled = YES;
    
    UIButton *subscribeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    subscribeButton.backgroundColor = [UIColor clearColor];
    subscribeButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [subscribeButton setTitleColor:[UIColor colorWithRed:0 green:0.0 blue:0.9 alpha:1] forState:UIControlStateNormal];
    [subscribeButton setTitle:NSLocalizedString(@"\u2606      subscribe      \u2606",nil) forState:UIControlStateNormal];
    [subscribeButton addTarget:self action:@selector(subscribe:) forControlEvents:UIControlEventTouchUpInside];
    [subscribeButton setFrame:CGRectMake(0, 0, self.view.bounds.size.width*8/9, 60)];
    //        [subscribeButton setImage:[UIImage imageNamed:@"subscribeIcon"] forState:UIControlStateNormal];
    //        [subscribeButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];
    
    self.progressView = [[ICDMaterialActivityIndicatorView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) activityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleLarge];
    [self.progressView setBackgroundColor:[UIColor whiteColor]];
    [self.progressView setAlpha:0.75];
    [self.progressView startAnimating];
    [self.view addSubview:self.progressView];
    popoverView = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width/2, [self.tableView contentOffset].y) inView:self.view withTitle: NSLocalizedString(@"Subscribe today and",nil) withViewArray: @[subscribeText, priceText, clearInfoText, privacyPolicyAndTOSText, subscribeButton] delegate:self];
    [popoverView setDelegate:self];
}

-(void) openPrivacyPolicyAndTOS {
    PenteWebViewController *webViewController = [[PenteWebViewController alloc] initWithAddress: @"https://www.pente.org/help/helpWindow.jsp?file=privacyPolicy"];
    [self.navigationController pushViewController:webViewController animated:YES];
    [navC setShowSubscribe:YES];
    [popoverView dismiss];
}
-(void) subscribe: (UIButton *) sender {
    subscribing = YES;
    [[RMStore defaultStore] addPayment:self.navC.subscription.productIdentifier success:^(SKPaymentTransaction *transaction) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"shouldSendReceipt"];
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
        
        NSString *url = @"https://www.pente.org/gameServer/iOSReceiptValidation";
        NSString *postString = [NSString stringWithFormat:@"name=%@&receipt=%@", [[NSUserDefaults standardUserDefaults] stringForKey: usernameKey], [self URLEncodedString_ch:[receipt base64EncodedStringWithOptions:0]]];
        
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressView stopAnimating];
            [self.progressView removeFromSuperview];
            if ([dashboardString containsString:@"success"]) {
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"shouldSendReceipt"];
                [TSMessage showNotificationInViewController:self.navigationController
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
                [TSMessage showNotificationInViewController:self.navigationController
                                                      title: NSLocalizedString(@"Purchase registration failed", nil)
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
        });
        
    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressView stopAnimating];
            [self.progressView removeFromSuperview];
            [TSMessage showNotificationInViewController:self.navigationController
                                                  title: NSLocalizedString(@"Purchase failed",nil)
                                               subtitle: [NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedFailureReason]
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
            NSLog(@"Something went wrong, %@", error.localizedFailureReason);
        });
    }];
    
    [popoverView dismiss];
}

-(void) restorePurchase {
    if (!self.navC.loggedIn) {
        [TSMessage showNotificationInViewController:self.navigationController
                                              title: NSLocalizedString(@"Purchase restore failed", nil)
                                           subtitle: NSLocalizedString(@"You need to be logged in first",nil)
                                              image:nil
                                               type: TSMessageNotificationTypeError
                                           duration:TSMessageNotificationDurationAutomatic
                                           callback: ^{
                                               [TSMessage dismissActiveNotification];
                                           }
                                        buttonTitle: nil
                                     buttonCallback:nil
                                         atPosition:TSMessageNotificationPositionBottom
                               canBeDismissedByUser:YES];
        return;
    }
    
    
    self.progressView = [[ICDMaterialActivityIndicatorView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) activityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleLarge];
    [self.progressView setBackgroundColor:[UIColor whiteColor]];
    [self.progressView setAlpha:0.75];
    [self.progressView startAnimating];
    [self.view addSubview:self.progressView];
    subscribing = YES;

    NSLog(@"start restore");
    
    [[RMStore defaultStore] restoreTransactionsOnSuccess:^(NSArray *transactions) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"shouldSendReceipt"];
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
        
        NSString *url = @"https://www.pente.org/gameServer/iOSReceiptValidation";
        NSString *postString = [NSString stringWithFormat:@"name=%@&receipt=%@", [[NSUserDefaults standardUserDefaults] stringForKey: usernameKey], [self URLEncodedString_ch:[receipt base64EncodedStringWithOptions:0]]];
        
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
        NSLog(@"before sending to server");
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        //        NSLog(dashboardString);
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressView stopAnimating];
            [self.progressView removeFromSuperview];
            if ([dashboardString containsString:@"success"]) {
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"shouldSendReceipt"];
                [TSMessage showNotificationInViewController:self.navigationController
                                                      title: NSLocalizedString(@"Purchase restore successful",nil)
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
            } else if ([dashboardString containsString:@"invalid receipt"]) {
                [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"shouldSendReceipt"];
                [TSMessage showNotificationInViewController:self.navigationController
                                                      title: NSLocalizedString(@"Purchase restore failed",nil)
                                                   subtitle: NSLocalizedString(@"No valid purchase to restore",nil)
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
                [TSMessage showNotificationInViewController:self.navigationController
                                                      title: NSLocalizedString(@"Purchase restore failed", nil)
                                                   subtitle: NSLocalizedString(@"The app will retry purchase restore at pente.org every time the app starts",nil)
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
        });
        
    } failure:^(NSError *error) {
        NSLog(@"Something went wrong, %@", error.localizedFailureReason);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressView stopAnimating];
            [self.progressView removeFromSuperview];
            [TSMessage showNotificationInViewController:self.navigationController
                                                  title: NSLocalizedString(@"Purchase failed",nil)
                                               subtitle: [NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedFailureReason]
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
            NSLog(@"Something went wrong, %@", error.localizedFailureReason);
        });
    }];
}

- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    if (!subscribing) {
        [self.progressView stopAnimating];
        [self.progressView removeFromSuperview];
    }
}

- (void)imagePickerController:(UIImagePickerController *)pickr didFinishPickingMediaWithInfo:(NSDictionary *)info {
//    NSLog(@"kitten");
    [pickr dismissViewControllerAnimated:NO completion:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
        if(image==nil) {
            image = [info objectForKey:UIImagePickerControllerOriginalImage];
        }
        if(image==nil) {
            image = [info objectForKey:UIImagePickerControllerCropRect];
        }
        CGFloat scaleSize = 300.0f;
        if (image) {
            UIImage *newImg = [self imageWithImage:image scaledToSize: scaleSize];
            NSData *imageData = UIImageJPEGRepresentation(newImg, 0.75f);
//            NSLog(@"kitty %f and size %lu", scaleSize(unsigned long), [imageData length]);
            while ([imageData length] > 65535) {
                scaleSize -= 10.0f;
                newImg = [self imageWithImage:image scaledToSize: scaleSize];
                imageData = UIImageJPEGRepresentation(newImg, 0.75f);
//                NSLog(@"kitty %f and size %lu", scaleSize(unsigned long), [imageData length]);
            }

            NSString *urlString = @"https://www.pente.org/gameServer/changeAvatar";
            if (development) {
                urlString = @"https://development.pente.org/gameServer/changeAvatar";
            }
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
            [request setURL:[NSURL URLWithString:urlString]];
            [request setHTTPMethod:@"POST"];
            
            NSString *boundary = @"---------------------------14737809831466499882746641449";
            NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",boundary];
//            contentType = @"image/png";
            [request addValue:contentType forHTTPHeaderField: @"Content-Type"];
            
            NSMutableData *body = [NSMutableData data];
            [body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[[NSString stringWithString:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"avatar\"; filename=\"%d\"\r\n", 1]] dataUsingEncoding:NSUTF8StringEncoding]];
//            [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[@"Content-Type: image/jpg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
            [body appendData:[NSData dataWithData:imageData]];
            [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [request setHTTPBody:body];
            
            NSError *error = nil;
            [NSURLConnection sendSynchronousRequest:request returningResponse:nil error: &error];
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                //        [alert show];
                [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
                return;
            }

        }
    });
}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGFloat)newMaxSize {
    CGFloat ratio;
    
    if (image.size.width > image.size.height) {
        if (newMaxSize > image.size.width) {
            return image;
        } else {
            ratio = newMaxSize/image.size.width;
        }
    } else {
        if (newMaxSize > image.size.height) {
            return image;
        } else {
            ratio = newMaxSize/image.size.height;
        }
    }
    
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(image.size.width*ratio, image.size.height*ratio), NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, image.size.width*ratio, image.size.height*ratio)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1) {
        if (buttonIndex == 1) {
            if ([MFMailComposeViewController canSendMail]) {
                MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
                mailer.mailComposeDelegate = self;
                [mailer setSubject:[NSString stringWithFormat:@"iOS penteLive help for %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"username"]]];
                NSArray *toRecipients = [NSArray arrayWithObjects:@"rainwolf@submanifold.be", nil];
                [mailer setToRecipients:toRecipients];
                
                
                [self presentViewController:mailer animated:YES completion:nil];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil)
                                                                message:NSLocalizedString(@"Your device is not configured to send mail",nil)
                                                               delegate:nil
                                                      cancelButtonTitle:NSLocalizedString(@"OK",nil)
                                                      otherButtonTitles:nil];
                [alert show];
            }
        }
    }

}




-(void) checkAndUpdateSettings {
    if (self.navC.player && self.navC.player.emailMe != [[NSUserDefaults standardUserDefaults] boolForKey:@"emailMe"]) {
        NSString *url = @"https://www.pente.org/gameServer/changeEmailPreference";
        if (development) {
            url = @"https://development.pente.org/gameServer/changeEmailPreference";
        }
        [self.navC.player setEmailMe: [[NSUserDefaults standardUserDefaults] boolForKey:@"emailMe"]];
        NSString *postString = [NSString stringWithFormat:@"emailMe=%@",(self.navC.player.emailMe?@"Y":@"N")];
        
        NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        
        [request setHTTPShouldUsePipelining: YES];
        
        NSURLResponse *response;
        NSError *error;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:@"Reason: %@", error.localizedDescription] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
            [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
        }
    }
    if (self.navC.player && self.navC.player.personalizeAds != [[NSUserDefaults standardUserDefaults] boolForKey:PERSONALIZEADSKEY]) {
        NSString *url = @"https://www.pente.org/gameServer/changeAdsPreference";
        if (development) {
            url = @"https://development.pente.org/gameServer/changeAdsPreference";
        }
        [self.navC.player setPersonalizeAds: [[NSUserDefaults standardUserDefaults] boolForKey:PERSONALIZEADSKEY]];
        NSString *postString = [NSString stringWithFormat:@"personalizeAds=%@",(self.navC.player.personalizeAds?@"Y":@"N")];
        
        NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        
        [request setHTTPShouldUsePipelining: YES];
        
        NSURLResponse *response;
        NSError *error;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:@"Reason: %@", error.localizedDescription] delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
            [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
            return;
        }
    }
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


- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    // your code here to reconfigure the app for changed settings
}

-(void) showAIOptionDialog {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Login failed or no Internet?", nil)
                                                                   message:NSLocalizedString(@"Do you just want to play the onboard AI?", nil)
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* dismissAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil) style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {
                                                          }];
    UIAlertAction* yesAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"yes please", nil) style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              UIStoryboard *sb = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
                                                              MMAIViewController * vc = (MMAIViewController *)[sb instantiateViewControllerWithIdentifier:@"mmaiViewController"];
                                                              [vc setShowAds: YES];
                                                              [self.navigationController pushViewController:vc animated:YES];
                                                          }];
    [alert addAction:dismissAction];
    [alert addAction:yesAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setBarButtonItem:self.navigationItem.rightBarButtonItem];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) strings {
    NSLocalizedString(@"Username:", nil);
}

@end
