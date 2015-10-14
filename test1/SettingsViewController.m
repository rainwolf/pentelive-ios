//
//  SettingsViewController.m
//  test1
//
//  Created by rainwolf on 28/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "SettingsViewController.h"
#import "IASKSettingsReader.h"

#define usernameKey @"username"
#define passwordKey @"password"

@interface SettingsViewController ()

@end

@implementation SettingsViewController
@synthesize username;
@synthesize password;



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
-(NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
    //    return UIInterfaceOrientationLandscapeLeft | UIInterfaceOrientationLandscapeRight | UIInterfaceOrientationPortrait;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self setShowCreditsFooter:YES];
    [self setTitle:@"Settings"];
    [self.tableView setSeparatorColor:[UIColor blueColor]];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    [self setDelegate:self];
//    [self set]
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
    if (!navControllor.loggedIn) {
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
                NSString *url = @"http://www.pente.org/gameServer/logout";
                [request setURL:[NSURL URLWithString:url]];
                [request setHTTPMethod:@"GET"];
                [request setTimeoutInterval:7.0];
                NSURLResponse *response;
                NSError *error;
                NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
                // connect to the game server
                request = [[NSMutableURLRequest alloc] init];
                url = [NSString stringWithFormat:@"http://www.pente.org/gameServer/index.jsp?name2=%@&password2=%@",username,password];
                [request setURL:[NSURL URLWithString:url]];
                [request setHTTPMethod:@"POST"];
                [request setTimeoutInterval:7.0];
                responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                //            NSLog(@"kittyyyyyyString -%@-", dashboardString);
    
                PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                if ([dashboardString isEqualToString:@""]) {
                    [navControllor setLoggedIn: NO];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"pente.org appears to be down, please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
    
                } else if ([dashboardString rangeOfString:@"Invalid name or password, please try again."].length != 0) {
                    [navControllor setLoggedIn: NO];
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Wrong username or password" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                } else if ([dashboardString rangeOfString:@"<h2>Pente.org is undergoing maintenance.</h2>"].length != 0) {
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Maintenance" message:@"pente.org is undergoing maintenance, please try again in a few minutes." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                } else {
                    [navControllor setLoggedIn: YES];
                    [navControllor setDidMove: YES];
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

        NSString *url = @"http://www.pente.org/join";
//        NSString *url = @"http://development.pente.org/join";
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
        
            PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
            if ([dashboardString isEqualToString:@""]) {
                [navControllor setLoggedIn: NO];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"pente.org appears to be down, please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
                
            } else if ([dashboardString rangeOfString:@" is already taken, please choose another."].length != 0) {
                [navControllor setLoggedIn: NO];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"The username %@ is already taken, please choose another.",username] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            } else if ([dashboardString rangeOfString:@"<h2>Pente.org is undergoing maintenance.</h2>"].length != 0) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Maintenance" message:@"pente.org is undergoing maintenance, please try again in a few minutes." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            } else {
                [defaults removeObjectForKey:@"emailAddress"];
                [defaults removeObjectForKey:@"passwordVerification"];
                [defaults setBool:NO forKey:@"RatedPlayPolicyAccepted"];
                [navControllor setLoggedIn: YES];
                [navControllor setDidMove: YES];
                [self.navigationController popToRootViewControllerAnimated:YES];
            }
    }
    if ([[specifier type] isEqualToString:kIASKOpenURLSpecifier]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:specifier.file]];
    }
//        [[NSUserDefaults standardUserDefaults] setObject:newTitle forKey:specifier.key];
}


//-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
//    [tableView deselectRowAtIndexPath:indexPath animated:NO];
//}

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
