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
#import "SVWebViewController.h"
#import "ChangeColorViewController.h"
#import "RMStore.h"


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

- (void)viewDidLoad
{
    [super viewDidLoad];

    subscribing = NO;
	// Do any additional setup after loading the view.
    self.navC = ((PenteNavigationViewController *)self.navigationController);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"registrationSuccess"]) {
        if (self.navC.player && self.navC.player.subscriber) {
            self.hiddenKeys = [NSSet setWithObjects:@"SubscribeButton",@"SignUpButton", @"SignUpLabel", nil];
//            self.hiddenKeys = [NSSet setWithObjects:@"SignUpButton", @"SignUpLabel", nil];
        } else {
            self.hiddenKeys = [NSSet setWithObjects:@"SignUpButton",@"manageSubscriptions", @"SignUpLabel", nil];
        }
    } else {
        self.hiddenKeys = [NSSet setWithObjects:@"SubscribeButton",@"manageSubscriptions", nil];
    }
    [self setShowCreditsFooter:YES];
    [self setTitle:@"Settings"];
    [self.tableView setSeparatorColor:[UIColor blueColor]];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    [self setDelegate:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"registrationSuccess"]) {
        if ([[[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]] textLabel] text] isEqualToString:@"Username:"]) {
            [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]].userInteractionEnabled = NO;
        }
        if ([[[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:1 inSection:1]] textLabel] text] isEqualToString:@"Password:"]) {
            [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:1 inSection:1]].userInteractionEnabled = NO;
        }
    }
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"registrationSuccess"]) {
        if ([[[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]] textLabel] text] isEqualToString:@"Username:"]) {
            [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:0 inSection:1]].userInteractionEnabled = NO;
        }
        if ([[[[self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:1 inSection:1]] textLabel] text] isEqualToString:@"Password:"]) {
            [self.tableView cellForRowAtIndexPath: [NSIndexPath indexPathForRow:1 inSection:1]].userInteractionEnabled = NO;
        }
    }
}
- (void)viewWillAppear:(BOOL)animated {
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

    [super viewWillDisappear:animated];
}


- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier {
    if ([specifier.key isEqualToString:@"LoginButton"]) {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            username = [defaults objectForKey:usernameKey];
            password = [defaults objectForKey:passwordKey];
            //        NSLog(@"kittyyyyyy %@ %@", username, password);
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
                [request setURL:[NSURL URLWithString:url]];
                [request setHTTPMethod:@"POST"];
                [request setTimeoutInterval:7.0];
                responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                //            NSLog(@"kittyyyyyyString -%@-", dashboardString);
    
                if ([dashboardString isEqualToString:@""]) {
                    [self.navC setLoggedIn: NO];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"pente.org appears to be down, please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
    
                } else if ([dashboardString rangeOfString:@"Invalid name or password, please try again."].length != 0) {
                    [self.navC setLoggedIn: NO];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Wrong username or password" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
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
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please enter a username, 5 to 10 characters long and consisting of letters, digits, and underscores only." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
        if (((password == nil) || ![[password stringByTrimmingCharactersInSet:testChars] isEqualToString:@""] || ([password length] < 5) || ([password length] > 16))) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please enter a password, 5 to 16 characters long and consisting of letters, digits, and underscores only." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
        if (![passwordVerification isEqualToString:password]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Passwords don't match." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }
        if (![defaults boolForKey:@"RatedPlayPolicyAccepted"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"You have to agree to Pente.org's Rated Play Policy before signing up." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;
        }

        NSString *url = @"https://www.pente.org/join";
//        NSString *url = @"https://development.pente.org/join";
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
        
            if ([dashboardString isEqualToString:@""]) {
                [self.navC setLoggedIn: NO];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"pente.org appears to be down, please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                
            } else if ([dashboardString rangeOfString:@" is already taken, please choose another."].length != 0) {
                [self.navC setLoggedIn: NO];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"The username %@ is already taken, please choose another.",username] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
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
    if ([specifier.key isEqualToString:@"HelpButton"]) {
        if (![self.navC loggedIn]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"You need to be logged in to send a help message. Send an email instead?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Email",nil];
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
            [mailer setSubject: @"Play Pente with me?"];
//            NSArray *toRecipients = [NSArray arrayWithObjects:@"rainwolf@submanifold.be", nil];
//            [mailer setToRecipients:toRecipients];
            [mailer setMessageBody: [NSString stringWithFormat:@"<p>You can play with me on your <a href=\"https://itunes.apple.com/us/app/pente-live/id595426592?ls=1&mt=8\">iPhone</a> or <a href=\"https://play.google.com/store/apps/details?id=be.submanifold.pentelive\">Android Phone</a> <br> My username is %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"username"]] isHTML:YES];
            [self presentViewController:mailer animated:YES completion:nil];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:@"Your device is not configured to send mail"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
        return;
    }
    if ([specifier.key isEqualToString:@"GameRulesButton"]) {
        SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress: @"https://pente.org/help/playGameRulesMobile.jsp"];
        [self.navigationController pushViewController:webViewController animated:YES];
    }
    if ([specifier.key isEqualToString:@"penteOrgPreferencesButton"]) {
        SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress: @"https://pente.org/gameServer/myprofile/prefs"];
        [self.navigationController pushViewController:webViewController animated:YES];
    }
    if ([specifier.key isEqualToString:@"changeColorButton"]) {
        if (!self.navC.player.subscriber) {
            return;
        }
        ChangeColorViewController *vc = [[ChangeColorViewController alloc] initWithColor:((PenteNavigationViewController *) self.navigationController).player.myColor];
        [self.navigationController pushViewController:vc animated:YES];
    }
    if ([specifier.key isEqualToString:@"changeAvatarButton"]) {
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
        UIAlertAction *albumAction = [UIAlertAction actionWithTitle: @"Choose from library" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            [self presentViewController:picker animated:YES completion:nil];
        }];
        [keyXController addAction:cancelAction];
        [keyXController addAction:cameraAction];
        [keyXController addAction:albumAction];
        
        [self presentViewController:keyXController animated:YES completion:nil];
    }
    if ([specifier.key isEqualToString:@"SubscribeButton"]) {
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
        NSString *subscribeString = @"\u2022 remove limits on open invitations\n\u2022 participate in all King of the Hills\n\u2022 see no more ads\n\u2022 change your name color\n\u2022 upload an avatar\n\u2022 access the database at pente.org!";
        [subscribeText setText:subscribeString];
        [subscribeText sizeToFit];
        
//        UILabel *priceText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*9/10, CGFLOAT_MAX)];
        UILabel *priceText = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*9/10, 50)];
        [priceText setLineBreakMode:NSLineBreakByWordWrapping];
        [priceText setNumberOfLines:0];
        NSString *priceString = [NSString stringWithFormat:@"only %@ / year", formattedPrice];
//        [priceText setAdjustsFontSizeToFitWidth:YES];
        [priceText setText:priceString];
        [priceText setFont:[UIFont systemFontOfSize: 23]];
        [priceText setTextColor:[UIColor orangeColor]];
        [priceText sizeToFit];

        UIButton *subscribeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        subscribeButton.backgroundColor = [UIColor clearColor];
        subscribeButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        [subscribeButton setTitleColor:[UIColor colorWithRed:0 green:0.0 blue:0.9 alpha:1] forState:UIControlStateNormal];
        [subscribeButton setTitle:@"\u2606      subscribe      \u2606" forState:UIControlStateNormal];
        [subscribeButton addTarget:self action:@selector(subscribe:) forControlEvents:UIControlEventTouchUpInside];
        [subscribeButton setFrame:CGRectMake(0, 0, self.view.bounds.size.width*8/9, 60)];
//        [subscribeButton setImage:[UIImage imageNamed:@"subscribeIcon"] forState:UIControlStateNormal];
//        [subscribeButton setContentHorizontalAlignment:UIControlContentHorizontalAlignmentLeft];

        popoverView = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width/2, [self.tableView contentOffset].y) inView:self.view withTitle: @"Subscribe today and" withViewArray: @[subscribeText, priceText, subscribeButton] delegate:self];
        [popoverView setDelegate:self];
        self.progressView = [[ICDMaterialActivityIndicatorView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) activityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleLarge];
        [self.progressView setBackgroundColor:[UIColor whiteColor]];
        [self.progressView setAlpha:0.75];
        [self.progressView startAnimating];
        [self.view addSubview:self.progressView];
    }
    
    if ([[specifier type] isEqualToString:kIASKOpenURLSpecifier]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:specifier.file]];
    }
//        [[NSUserDefaults standardUserDefaults] setObject:newTitle forKey:specifier.key];
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
        
        [self.progressView stopAnimating];
        [self.progressView removeFromSuperview];
        if ([dashboardString containsString:@"success"]) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"shouldSendReceipt"];
            [TSMessage showNotificationInViewController:self.navigationController
                                                  title: @"Purchase registration successful"
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
                                                  title: @"Purchase registration failed"
                                               subtitle: @"The app will retry purchase registration at pente.org every time the app starts"
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

    } failure:^(SKPaymentTransaction *transaction, NSError *error) {
        [self.progressView stopAnimating];
        [self.progressView removeFromSuperview];
        [TSMessage showNotificationInViewController:self.navigationController
                                              title: @"Purchase failed"
                                           subtitle: [NSString stringWithFormat:@"Reason: %@", error.localizedFailureReason]
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
    }];
    
    [popoverView dismiss];
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
            
            [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
            
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
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                message:@"Your device is not configured to send mail"
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
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



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
