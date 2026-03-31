//
//  GamesTableViewController.m
//  test1
//
//  Created by rainwolf on 12/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "GamesTableViewController.h"
#import "PenteGame.h"
#import "PentePlayer.h"

#import "BoardView.h"
#import "BoardViewController.h"
#import "DatabaseViewController.h"
#import "KOTHTableViewController.h"
#import "MMAIViewController.h"
#import "RatingStatsView.h"
#import "SettingsViewController.h"
#import "WhosOnlineView.h"
#import <QuartzCore/QuartzCore.h>
@import TSMessages;
#import "UIBarButtonItem+Badge.h"
#import "UIButton+Badge.h"

#import "penteLive-Swift.h"

#define usernameKey @"username"
#define passwordKey @"password"

#define MESSAGESSECTION 0
#define INVITATIONSSECTION 1
#define ACTIVEGAMESSECTION 2
#define PUBLICINVITATIONSSECTION 3
#define SENTINVITATIONSSECTION 6
#define NONACTIVEGAMESSECTION 7
#define TOURNAMENTSSECTION 5
#define KOTHSECTION 4

@interface GamesTableViewController ()

@end

@implementation GamesTableViewController
@synthesize player;
@synthesize selectedGame;
@synthesize boardController;
@synthesize messagesViewController;
@synthesize invitationsViewController;
@synthesize username;
@synthesize password;
@synthesize selectedInvitationIndexPath, selectedPublicInvitationIndexPath;
@synthesize acceptButton;
@synthesize rejectButton;
@synthesize cancelButton;
@synthesize messagesCollapsed, invitationsReceivedCollapsed,
    activeGamesCollapsed, publicInvitationsCollapsed, sentInvitationsCollapsed,
    nonActiveGamesCollapsed, alreadyAskedAboutInvitations, tournamentsCollapsed,
    kothCollapsed;
@synthesize selectedInvitationCell, selectedPublicInvitationCell;
@synthesize gamesLimit;
@synthesize actionPopoverView;
@synthesize progressView;
@synthesize settingsViewController;

UIBarButtonItem *inviteButton, *moreButton;
NSString *livePlayers, *onlineFollowing;
CGFloat bottomOffset = 0;

//- (void)adViewWillLeaveApplication:(GADBannerView *)bannerView {
//    NSLog(@"... leaving penteLive for an ad");
//    NSLog(@"The ad's adNetworkClassName: %@",
//    self.bannerView.adNetworkClassName);
//}

- (BOOL)shouldAutorotate {
    //    UIInterfaceOrientation interfaceOrientation = [[UIApplication
    //    sharedApplication] statusBarOrientation]; return
    //    ((interfaceOrientation
    //    != UIInterfaceOrientationPortraitUpsideDown) && (interfaceOrientation
    //    != UIInterfaceOrientationLandscapeLeft) && (interfaceOrientation !=
    //    UIInterfaceOrientationLandscapeRight));
    return YES;
    //    if (((1 << interfaceOrientation) & [self
    //    supportedInterfaceOrientations]) == 0) {
    //        return YES;
    //    } else {
    //        return NO;
    //    }
    //    return (interfaceOrientation != UIInterfaceOrientationPortrait);
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
    //    return UIInterfaceOrientationLandscapeLeft |
    //    UIInterfaceOrientationLandscapeRight | UIInterfaceOrientationPortrait;
}

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    bottomOffset = 0;
    player = [[PentePlayer alloc] init];
    ((PenteNavigationViewController *)self.navigationController).player =
        player;
    [super viewDidLoad];
    [self setTitle:NSLocalizedString(@"home", nil)];

    selectedInvitationCell = nil;
    selectedPublicInvitationCell = nil;

    inviteButton = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                             target:self
                             action:@selector(showInvitationActions)];
    moreButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage imageNamed:@"showpopup.png"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(showActions)];
    [self.navigationItem setRightBarButtonItem:nil];
    [self.navigationItem
        setRightBarButtonItems:[NSArray arrayWithObjects:moreButton,
                                                         inviteButton, nil]];

    UIBarButtonItem *leftBarButton = [self.navigationItem leftBarButtonItem];
    [leftBarButton setImage:[UIImage imageNamed:@"settings.png"]];
    [leftBarButton setTitle:nil];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    messagesCollapsed = [defaults boolForKey:@"messagesCollapsed"];
    invitationsReceivedCollapsed =
        [defaults boolForKey:@"invitationsReceivedCollapsed"];
    activeGamesCollapsed = [defaults boolForKey:@"activeGamesCollapsed"];
    publicInvitationsCollapsed =
        [defaults boolForKey:@"publicInvitationsCollapsed"];
    sentInvitationsCollapsed =
        [defaults boolForKey:@"sentInvitationsCollapsed"];
    nonActiveGamesCollapsed = [defaults boolForKey:@"nonActiveGamesCollapsed"];
    tournamentsCollapsed = [defaults boolForKey:@"tournamentsCollapsed"];
    kothCollapsed = [defaults boolForKey:@"kothCollapsed"];
    self.tableView.layer.borderColor = [UIColor redColor].CGColor;

    alreadyAskedAboutInvitations = NO;

    gamesLimit = 200;

    long openInvitationsLimit = [[NSUserDefaults standardUserDefaults]
        integerForKey:@"openInvitationsLimit"];
    if (openInvitationsLimit == 0) {
        [[NSUserDefaults standardUserDefaults]
            setInteger:3
                forKey:@"openInvitationsLimit"];
    }
    self.progressView = [[ICDMaterialActivityIndicatorView alloc]
                 initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,
                                          self.view.frame.size.height)
        activityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleLarge];
    [self.progressView setBackgroundColor:[UIColor whiteColor]];
    [self.progressView setAlpha:0.75];

    if ([[UIDevice currentDevice] userInterfaceIdiom] ==
        UIUserInterfaceIdiomPhone) {
        if ((int)[[UIScreen mainScreen] nativeBounds].size.height == 2436) {
            bottomOffset = 34;
        }
    }

    //    [self toLive];
}

//-(void) toSettings {
//    NSLog(@"toSettings");
//    SettingsViewController *vc = [[SettingsViewController alloc]
//    initWithFile:@"Root.inApp" specifier:nil andNavigationController:
//    (PenteNavigationViewController *)self.navigationController];
//    [self.navigationController pushViewController:vc animated:YES];
//}

- (void)viewDidAppear:(BOOL)animated {
    PenteNavigationViewController *navController =
        (PenteNavigationViewController *)self.navigationController;
    if (!navController.loggedIn) {
        self.tableView.layer.borderWidth = 1.5;
        [self login];
    } else if (navController.showSubscribe) {
        [self performSegueWithIdentifier:@"settingsTap" sender:self];
    }

    //    bannerView = navController.bannerView;
    [navController setChallengeCancelled:NO];
    //    bannerView.rootViewController = self;
    //    [bannerView setDelegate: self];
    //    if (player.showAds) {
    //        CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    //        CGFloat newOriginY = screenHeight -
    //        navController.navigationBar.frame.size.height - [UIApplication
    //        sharedApplication].statusBarFrame.size.height -
    //        bannerView.frame.size.height; CGRect newBannerViewFrame =
    //        CGRectMake(bannerView.frame.origin.x, newOriginY,
    //        bannerView.frame.size.width, bannerView.frame.size.height);
    //        bannerView.frame = newBannerViewFrame;
    //        [self.tableView setTableFooterView:bannerView];
    //        [self.tableView bringSubviewToFront:bannerView];
    //        [self scrollViewDidScroll: self.tableView];
    //    }

    //    [self performSelector:@selector(scrollViewDidScroll:) withObject:
    //    self.tableView afterDelay:.05f];
    [super viewDidAppear:animated];
    //    [self toLive];
}

- (void)viewWillAppear:(BOOL)animated {
    PenteNavigationViewController *navControllor =
        (PenteNavigationViewController *)self.navigationController;
    if (navControllor.needHelp) {
        [self performSegueWithIdentifier:@"messagesTap" sender:self];
        [messagesViewController setPlayer:player];
        [messagesViewController setGamesLimit:gamesLimit];
        return;
    }
    if (navControllor.didMove) {
        [navControllor setDidMove:NO];
        //        if (!activeGamesCollapsed) {
        //            for( int i = 0; i < [[self.player activeGames] count];
        //            ++i) {
        //                if ([navControllor.activeGameToRemove
        //                isEqualToString:[[[self.player activeGames]
        //                objectAtIndex:i] gameID]]) {
        //                    [[self.player activeGames] removeObjectAtIndex:i];
        //                    [self.tableView deleteRowsAtIndexPaths:[NSArray
        //                    arrayWithObject:[NSIndexPath indexPathForRow:i
        //                    inSection:2]]
        //                    withRowAnimation:UITableViewRowAnimationFade];
        //                    break;
        //                }
        //            }
        //        }
        //        if ([[NSUserDefaults standardUserDefaults] boolForKey:
        //        @"registrationSuccess"]) {
        [self dashboardParse];
        //        }
    } else if (navControllor.messageDeleted) {
        [navControllor setMessageDeleted:NO];
        [self.player.messages
            removeObjectAtIndex:navControllor.deletedMessageRow];
        [UIView animateWithDuration:0.3
            animations:^{
                if (!messagesCollapsed) {
                    [self.tableView
                        deleteRowsAtIndexPaths:
                            [NSArray
                                arrayWithObject:
                                    [NSIndexPath
                                        indexPathForRow:navControllor
                                                            .deletedMessageRow
                                              inSection:0]]
                              withRowAnimation:UITableViewRowAnimationFade];
                } else {
                    [self.tableView reloadData];
                }
            }
            completion:^(BOOL finished) {
                [self dashboardParse];
                //                [self
                //                performSelector:@selector(scrollViewDidScroll:)
                //                withObject: self.tableView];
            }];
    }

    selectedInvitationIndexPath = nil;
    selectedInvitationCell = nil;
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    //    [bannerView removeFromSuperview];
    //    [self.tableView setTableFooterView:nil];
    [super viewWillDisappear:animated];
}

- (void)login {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    username = [defaults objectForKey:usernameKey];
    password = [defaults objectForKey:passwordKey];
    //    if (development) {
    //        username = @"iostest";
    ////        username = @"harveyjoe";
    //        password = @"tsetsoi";
    //    }
    if (!((username == nil) || (password == nil) ||
          [username isEqualToString:@""] || [password isEqualToString:@""])) {
        player.playerName = username.lowercaseString;
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        NSString *url = @"https://www.pente.org/gameServer/logout";
        if (development) {
            url = @"https://localhost/gameServer/logout";
        }
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"GET"];
        [request setTimeoutInterval:7.0];
        __weak typeof(self) weakSelf = self;
        [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
            // connect to the game server
            NSMutableURLRequest *loginRequest = [[NSMutableURLRequest alloc] init];
            NSString *loginUrl = [NSString
                stringWithFormat:@"https://www.pente.org/gameServer/"
                                 @"login.jsp?mobile=&name2=%@&password2=%@",
                                 username, password];
            if (development) {
                loginUrl = [NSString
                    stringWithFormat:@"https://localhost/gameServer/"
                                     @"login.jsp?mobile=&name2=%@&password2=%@",
                                     username, password];
            }
            [loginRequest setURL:[NSURL URLWithString:loginUrl]];
            [loginRequest setHTTPMethod:@"POST"];
            [loginRequest setTimeoutInterval:3.0];
            __weak typeof(self) weakSelf2 = weakSelf;
            [PenteHTTPClient sendRequest:loginRequest completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
                NSString *dashboardString =
                    [[NSString alloc] initWithData:responseData
                                          encoding:NSUTF8StringEncoding];

                if (error && error.code == NSURLErrorTimedOut) {
                    [loginRequest setTimeoutInterval:10.0];
                    __weak typeof(self) weakSelf3 = weakSelf2;
                    [PenteHTTPClient sendRequest:loginRequest completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
                        NSString *dashboardString =
                            [[NSString alloc] initWithData:responseData
                                                  encoding:NSUTF8StringEncoding];
                        if (error) {
                            [weakSelf3 noInternet:[NSString
                                                 stringWithFormat:
                                                     @"Trouble connecting to pente.org, please "
                                                     @"try again in a bit.\nReason: %@",
                                                     error.localizedDescription]];
                            return;
                        } else if ([dashboardString isEqualToString:@""] ||
                                   ([dashboardString rangeOfString:@"HTTP Error"].length !=
                                    0)) {
                            [weakSelf3 noInternet:
                                      @"pente.org appears to be down, please try again later."];
                            return;
                        } else if ([dashboardString
                                       rangeOfString:
                                           @"<h2>Pente.org is undergoing maintenance.</h2>"]
                                       .length != 0) {
                            UIAlertView *alert =
                                [[UIAlertView alloc] initWithTitle:@"Maintenance"
                                                           message:@"pente.org is undergoing "
                                                                   @"maintenance, please try "
                                                                   @"again in a few minutes."
                                                          delegate:nil
                                                 cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                 otherButtonTitles:nil];
                            [alert show];
                            //            [self performSegueWithIdentifier:@"settingsTap"
                            //            sender:self]; settingsViewController.showAIOption =
                            //            YES;
                            return;
                        } else if ([dashboardString
                                       rangeOfString:
                                           @"Invalid name or password, please try again."]
                                       .length != 0) {
                            [weakSelf3 performSegueWithIdentifier:@"settingsTap" sender:weakSelf3];
                            //            settingsViewController.showAIOption = YES;
                            return;
                        } else {
                            PenteNavigationViewController *navControllor =
                                (PenteNavigationViewController *)weakSelf3.navigationController;
                            [navControllor setLoggedIn:YES];
                            [NSThread detachNewThreadSelector:@selector(handleDeviceToken)
                                                     toTarget:weakSelf3
                                                   withObject:nil];
                            [weakSelf3 dashboardParse];
                        }
                    }];
                    return;
                }
                if (error) {
                    [weakSelf2 noInternet:[NSString
                                         stringWithFormat:
                                             @"Trouble connecting to pente.org, please "
                                             @"try again in a bit.\nReason: %@",
                                             error.localizedDescription]];
                    return;
                } else if ([dashboardString isEqualToString:@""] ||
                           ([dashboardString rangeOfString:@"HTTP Error"].length !=
                            0)) {
                    [weakSelf2 noInternet:
                              @"pente.org appears to be down, please try again later."];
                    return;
                } else if ([dashboardString
                               rangeOfString:
                                   @"<h2>Pente.org is undergoing maintenance.</h2>"]
                               .length != 0) {
                    UIAlertView *alert =
                        [[UIAlertView alloc] initWithTitle:@"Maintenance"
                                                   message:@"pente.org is undergoing "
                                                           @"maintenance, please try "
                                                           @"again in a few minutes."
                                                  delegate:nil
                                         cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                         otherButtonTitles:nil];
                    [alert show];
                    //            [self performSegueWithIdentifier:@"settingsTap"
                    //            sender:self]; settingsViewController.showAIOption =
                    //            YES;
                    return;
                } else if ([dashboardString
                               rangeOfString:
                                   @"Invalid name or password, please try again."]
                               .length != 0) {
                    [weakSelf2 performSegueWithIdentifier:@"settingsTap" sender:weakSelf2];
                    //            settingsViewController.showAIOption = YES;
                    return;
                } else {
                    PenteNavigationViewController *navControllor =
                        (PenteNavigationViewController *)weakSelf2.navigationController;
                    [navControllor setLoggedIn:YES];
                    [NSThread detachNewThreadSelector:@selector(handleDeviceToken)
                                             toTarget:weakSelf2
                                           withObject:nil];
                    [weakSelf2 dashboardParse];
                }
            }];
        }];
    } else {
        [self notRegisteredYet];
        //        [self performSegueWithIdentifier:@"settingsTap" sender:self];
        //        settingsViewController.showAIOption = YES;
        return;
    }
}

- (void)noInternet:(NSString *)message {
    UIAlertController *anonymousOrAIController = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"Error", nil)
                         message:message
                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *aiAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"play the onboard AI", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    [self performSegueWithIdentifier:@"MMAItap" sender:self];
                }];
    UIAlertAction *cancelAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"dismiss", nil)
                  style:UIAlertActionStyleCancel
                handler:^(UIAlertAction *action) {
                    [self performSegueWithIdentifier:@"settingsTap"
                                              sender:self];
                }];
    [anonymousOrAIController addAction:aiAction];
    [anonymousOrAIController addAction:cancelAction];

    if (anonymousOrAIController.popoverPresentationController != nil) {
        anonymousOrAIController.popoverPresentationController.barButtonItem =
            self.navigationItem.rightBarButtonItems[1];
        //        [anonymousOrAIController.popoverPresentationController
        //        setSourceView: self.navigationItem.titleView];
        //        [anonymousOrAIController.popoverPresentationController
        //        setSourceRect: self.navigationItem.titleView.bounds];
    }

    [self presentViewController:anonymousOrAIController
                       animated:YES
                     completion:nil];
}
- (void)notRegisteredYet {
    UIAlertController *anonymousOrAIController = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"Not yet registered", nil)
                         message:
                             NSLocalizedString(
                                 @"Registration is needed to play turn-based "
                                 @"games and maintain a rating. You can, "
                                 @"however, play the onboard AI or play live "
                                 @"games as a guest if you choose not to "
                                 @"register now.",
                                 nil)
                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *registerAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"register now", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    [self performSegueWithIdentifier:@"settingsTap"
                                              sender:self];
                }];
    UIAlertAction *aiAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"play the onboard AI", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    [self performSegueWithIdentifier:@"MMAItap" sender:self];
                }];
    UIAlertAction *liveGuestAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"play live as guest", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    RoomViewController *vc = [[RoomViewController alloc] init];
                    //        NSLog(@"kitty %@", ((PenteNavigationViewController
                    //        *) self.navigationController).player.playerName);
                    vc.pentePlayer = ((PenteNavigationViewController *)
                                          self.navigationController)
                                         .player;
                    [self.navigationController pushViewController:vc
                                                         animated:YES];
                }];
    [anonymousOrAIController addAction:registerAction];
    [anonymousOrAIController addAction:aiAction];
    [anonymousOrAIController addAction:liveGuestAction];

    if (anonymousOrAIController.popoverPresentationController != nil) {
        anonymousOrAIController.popoverPresentationController.barButtonItem =
            self.navigationItem.rightBarButtonItems[1];
        //        [anonymousOrAIController.popoverPresentationController
        //        setSourceView: self.navigationItem.v];
        //        [anonymousOrAIController.popoverPresentationController
        //        setSourceRect: self.navigationItem.titleView.bounds];
    }

    [self presentViewController:anonymousOrAIController
                       animated:YES
                     completion:nil];
}

- (void)handleDeviceToken {
    //    NSLog(@"kittnnn");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *storedTokenString = [defaults objectForKey:@"deviceToken"];
    //    NSLog(@"kittnnn %@", storedTokenString);
    //    NSDate *dateOfLastPing = [defaults objectForKey:@"lastPing"];
    //    NSLog(@"kitty date: %@", [NSDateFormatter
    //    localizedStringFromDate:dateOfLastPing
    //    dateStyle:NSDateFormatterShortStyle
    //    timeStyle:NSDateFormatterFullStyle]);
    if (storedTokenString) {
        NSLog(@"got token string %@", storedTokenString);
        NSDate *dateOfLastPing = [defaults objectForKey:@"lastPing"];
        if (dateOfLastPing) {
            double daysPassed =
                [dateOfLastPing timeIntervalSinceNow] / -86400.0;
            //            NSLog(@"daysPassed : %f", daysPassed);
            NSLog(@"days passed %f", daysPassed);
            if (daysPassed < 1) {
                return;
            }
        }

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        NSString *url =
            [NSString stringWithFormat:@"https://www.pente.org/gameServer/"
                                       @"notification?device=iOS&token=%@",
                                       storedTokenString];
        if (development) {
            url =
                [NSString stringWithFormat:@"https://localhost/gameServer/"
                                           @"notification?device=iOS&token=%@",
                                           storedTokenString];
        }
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"GET"];
        [request setTimeoutInterval:7.0];
        [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"wth \n %@", error.localizedDescription);
            }
            NSString *replyString =
                [[NSString alloc] initWithData:responseData
                                      encoding:NSUTF8StringEncoding];

            //        NSLog(@"wth \n %@", replyString);
            if ([replyString containsString:@"It seems to have worked"]) {
                [defaults setObject:[NSDate date] forKey:@"lastPing"];
            }
        }];
    } else {
        NSLog(@"No Device Token stored");
    }
}

//-(void) handleGDPR {
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    if (![defaults boolForKey:GDPRTERMSKEY]) {
//        NSString *message =
//        NSLocalizedString(@"This app delivers ads to non-subscribers,
//        delivered by Google's Adsense network, you may opt for personalized or
//        non-personalized ads, and can change your choice at any time in the
//        settings. Please check our privacy policy for an overview of the data
//        that is collected and what we do with it, you can find a link in the
//        settings of this app. By proceeding to use this app, you consent to
//        our privacy policy. You must be at least 16 years old to consent to
//        this, otherwise consent from a parent or guardian is required.",nil);
//        UIAlertController *gdprController = [UIAlertController
//                                           alertControllerWithTitle:NSLocalizedString(@"GDPR",
//                                           nil) message: message
//                                           preferredStyle:UIAlertControllerStyleActionSheet];
//        UIAlertAction *viewPolicyAction = [UIAlertAction
//        actionWithTitle:NSLocalizedString(@"privacy policy", nil)
//        style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
//          PenteWebViewController *webViewController = [[PenteWebViewController
//          alloc] initWithAddress:
//          @"https://www.pente.org/help/helpWindow.jsp?file=privacyPolicy"];
//          [(PenteNavigationViewController *)self.navigationController
//          pushViewController:webViewController animated:YES];
//        }];
//        UIAlertAction *personalizeAction = [UIAlertAction
//        actionWithTitle:NSLocalizedString(@"Personalise ads", nil)
//        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//            [defaults setBool:YES forKey:PERSONALIZEADSKEY];
//            [defaults setBool:YES forKey:GDPRTERMSKEY];
//            NSString *url =
//            @"https://www.pente.org/gameServer/changeAdsPreference"; if
//            (development) {
//                url = @"https://localhost/gameServer/changeAdsPreference";
//            }
//            [((PenteNavigationViewController
//            *)self.navigationController).player setPersonalizeAds:
//            [[NSUserDefaults standardUserDefaults]
//            boolForKey:PERSONALIZEADSKEY]]; NSString *postString =
//            @"personalizeAds=Y";
//
//            NSData *postData = [postString
//            dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
//            NSString *postLength = [NSString stringWithFormat:@"%lu",
//            (unsigned long)[postData length]];
//
//            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
//            [request setURL:[NSURL URLWithString:url]];
//            [request setHTTPMethod:@"POST"];
//            [request setValue:postLength
//            forHTTPHeaderField:@"Content-Length"]; [request
//            setValue:@"application/x-www-form-urlencoded"
//            forHTTPHeaderField:@"Content-Type"]; [request
//            setHTTPBody:postData]; [request setTimeoutInterval:7.0];
//
//            [request setHTTPShouldUsePipelining: YES];
//
//            NSURLResponse *response;
//            NSError *error;
//            [PenteHTTPClient sendSynchronousRequest:request
//            returningResponse:&response error:&error];
//
//            if (error) {
//                UIAlertView *alert = [[UIAlertView alloc]
//                initWithTitle:NSLocalizedString(@"Error", nil)
//                message:[NSString stringWithFormat:@"Reason: %@",
//                error.localizedDescription] delegate:nil
//                cancelButtonTitle:NSLocalizedString(@"OK",nil)
//                otherButtonTitles:nil]; [alert
//                performSelectorOnMainThread:@selector(show) withObject:nil
//                waitUntilDone:YES]; return;
//            }
//        }];
//        UIAlertAction *anonymizeAction = [UIAlertAction
//        actionWithTitle:NSLocalizedString(@"Anonymise ads", nil)
//        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//            [defaults setBool:NO forKey:PERSONALIZEADSKEY];
//            [defaults setBool:YES forKey:GDPRTERMSKEY];
//            NSString *url =
//            @"https://www.pente.org/gameServer/changeAdsPreference"; if
//            (development) {
//                url = @"https://localhost/gameServer/changeAdsPreference";
//            }
//            [((PenteNavigationViewController
//            *)self.navigationController).player setPersonalizeAds:
//            [[NSUserDefaults standardUserDefaults]
//            boolForKey:PERSONALIZEADSKEY]]; NSString *postString =
//            @"personalizeAds=N";
//
//            NSData *postData = [postString
//            dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
//            NSString *postLength = [NSString stringWithFormat:@"%lu",
//            (unsigned long)[postData length]];
//
//            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
//            [request setURL:[NSURL URLWithString:url]];
//            [request setHTTPMethod:@"POST"];
//            [request setValue:postLength
//            forHTTPHeaderField:@"Content-Length"]; [request
//            setValue:@"application/x-www-form-urlencoded"
//            forHTTPHeaderField:@"Content-Type"]; [request
//            setHTTPBody:postData]; [request setTimeoutInterval:7.0];
//
//            [request setHTTPShouldUsePipelining: YES];
//
//            NSURLResponse *response;
//            NSError *error;
//            [PenteHTTPClient sendSynchronousRequest:request
//            returningResponse:&response error:&error];
//
//            if (error) {
//                UIAlertView *alert = [[UIAlertView alloc]
//                initWithTitle:NSLocalizedString(@"Error", nil)
//                message:[NSString stringWithFormat:@"Reason: %@",
//                error.localizedDescription] delegate:nil
//                cancelButtonTitle:NSLocalizedString(@"OK",nil)
//                otherButtonTitles:nil]; [alert
//                performSelectorOnMainThread:@selector(show) withObject:nil
//                waitUntilDone:YES]; return;
//            }
//        }];
//        UIAlertAction *acceptAction = [UIAlertAction
//        actionWithTitle:NSLocalizedString(@"Anonymise ads", nil)
//        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
//            [defaults setBool:YES forKey:GDPRTERMSKEY];
//        }];
//        if (player.subscriber) {
//            [gdprController addAction:acceptAction];
//        } else {
//            [gdprController addAction:anonymizeAction];
//            [gdprController addAction:personalizeAction];
//        }
//        [gdprController addAction:viewPolicyAction];
//
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            if (gdprController.popoverPresentationController != nil) {
//                gdprController.popoverPresentationController.barButtonItem =
//                self.navigationItem.rightBarButtonItems[1];
//            }
//            [self presentViewController:gdprController animated:NO
//            completion:nil];
//        });
//    }
//}

- (void)pullDownToReloadAction {
    if (selectedInvitationIndexPath) {
        [self removeButtonsFromCell];
        [self.tableView beginUpdates];
        selectedInvitationIndexPath = nil;
        selectedInvitationCell = nil;
        [self.tableView endUpdates];
        [[self.tableView cellForRowAtIndexPath:selectedInvitationIndexPath]
            setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
    //    [self.tableView setUserInteractionEnabled: NO];
    self.tableView.layer.borderWidth = 1.5;
    [self performSelector:@selector(scrollViewDidScroll:)
               withObject:self.tableView
               afterDelay:0.05];
    //    [self performSelector:@selector(pullDownToReloadActionFinished)
    //    withObject:nil afterDelay: 0.5f];
    [self performSelectorOnMainThread:@selector(dashboardParse)
                           withObject:nil
                        waitUntilDone:NO];
}

- (void)pullDownToReloadActionFinished {
    [self.pullToReloadHeaderView setLastUpdatedDate:[NSDate date]];
    [self.pullToReloadHeaderView finishReloading:self.tableView animated:YES];
    [self.tableView reloadData];
    //    [self performSelector:@selector(scrollViewDidScroll:) withObject:
    //    self.tableView afterDelay:0.25];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // #warning Potentially incomplete method implementation.
    //  Return the number of sections.
    return 8;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
    // warning Incomplete method implementation.
    //  Return the number of rows in the section.
    if (!player) {
        return 0;
    }
    switch (section) {
    case MESSAGESSECTION:
        if (messagesCollapsed) {
            return 0;
        }
        return [[self.player messages] count];
        break;
    case INVITATIONSSECTION:
        if (invitationsReceivedCollapsed) {
            return 0;
        }
        return [[self.player invitations] count];
        break;
    case ACTIVEGAMESSECTION:
        if (activeGamesCollapsed) {
            return 0;
        }
        return [[self.player activeGames] count];
        break;
    case PUBLICINVITATIONSSECTION:
        if (publicInvitationsCollapsed) {
            return 0;
        }
        return [[self.player publicInvitations] count];
        break;
    case SENTINVITATIONSSECTION:
        if (sentInvitationsCollapsed) {
            return 0;
        }
        return [[self.player sentInvitations] count];
        break;
    case NONACTIVEGAMESSECTION:
        if (nonActiveGamesCollapsed) {
            return 0;
        }
        return [[self.player nonActiveGames] count];
        break;
    case TOURNAMENTSSECTION:
        if (tournamentsCollapsed) {
            return 0;
        }
        return [[self.player tournaments] count];
        break;
    case KOTHSECTION:
        if (kothCollapsed) {
            return 0;
        }
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"showOnlyTB"]) {
            return player.tbHills;
        } else {
            return [[self.player hills] count];
        }
        break;
    default:
        return 0;
        break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (selectedInvitationIndexPath &&
        (indexPath.section == INVITATIONSSECTION)) {
        if ((selectedInvitationIndexPath.section == INVITATIONSSECTION) &&
            (indexPath.row == selectedInvitationIndexPath.row)) {
            return 88;
        }
    }
    if (selectedPublicInvitationIndexPath &&
        (indexPath.section == PUBLICINVITATIONSSECTION)) {
        if ((selectedPublicInvitationIndexPath.section ==
             PUBLICINVITATIONSSECTION) &&
            (indexPath.row == selectedPublicInvitationIndexPath.row)) {
            return 88;
        }
    }
    return 44;
}

//-(void) addColorOfRating: (NSString *) rating toString:
//(NSMutableAttributedString *) str {
//    int ratingInt = [rating intValue];
//    UIColor *ratingColor;
//    if (ratingInt >= 1900) {
//        ratingColor = [UIColor redColor];
//    } else if (ratingInt >= 1700) {
//        ratingColor = [UIColor colorWithRed:0.98 green:0.96 blue:0.03
//        alpha:1.0];
//    } else if (ratingInt >= 1400) {
//        ratingColor = [UIColor blueColor];
//    } else if (ratingInt >= 1000) {
//        ratingColor = [UIColor colorWithRed:30.0/255 green: 130.0/255
//        blue:76.0/255 alpha:1.0];
//    } else {
//        ratingColor = [UIColor grayColor];
//    }
//    NSString *strString = [str string];
//    [str addAttribute:NSForegroundColorAttributeName value: ratingColor range:
//    [strString rangeOfString: @"\u25A0"]]; [str
//    addAttribute:NSFontAttributeName value:[UIFont
//    fontWithName:@"HelveticaNeue-Bold" size:12.f] range: [strString
//    rangeOfString: @"\u25A0"]];
//}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"CellIdentifier";
    static NSString *CellWithWhiteStoneImageIdentifier =
        @"CellWithWhiteStoneImage";
    static NSString *CellWithBlackStoneImageIdentifier =
        @"CellWithBlackStoneImage";
    static NSString *CellWithUnreadImageIdentifier = @"CellWithUnreadImage";
    static NSString *CellWithAvatarIdentifier = @"CellWithAvatar";

    NSString *tmpIdentifier;
    //    NSLog(@"here kitty");
    //    GameTableViewCell *cell = (GameTableViewCell *) [tableView
    //    dequeueReusableCellWithIdentifier:CellIdentifier];
    GameTableViewCell *cell;
    NSMutableAttributedString *tmpStr;
    NSMutableString *txtStr;

    if (indexPath.section == MESSAGESSECTION) {
        Message *message = [[self.player messages] objectAtIndex:indexPath.row];
        UIImage *imgV = nil;
        if ([[message unread] isEqualToString:@"unread"]) {
            cell = (GameTableViewCell *)[tableView
                dequeueReusableCellWithIdentifier:
                    CellWithUnreadImageIdentifier];
            if (!cell) {
                cell = [[GameTableViewCell alloc]
                      initWithStyle:UITableViewCellStyleSubtitle
                    reuseIdentifier:CellWithUnreadImageIdentifier];
            }
            imgV = [UIImage imageNamed:@"unread.png"];
            cell.backgroundColor = [UIColor colorWithRed:222.0 / 256
                                                   green:236.0 / 256
                                                    blue:222.0 / 256
                                                   alpha:1];
        } else {
            NSString *opponent = [message author];
            imgV = [self.player.avatars objectForKey:opponent];
            if (imgV) {
                tmpIdentifier = CellWithAvatarIdentifier;
            } else {
                tmpIdentifier = CellIdentifier;
            }
            cell = (GameTableViewCell *)[tableView
                dequeueReusableCellWithIdentifier:tmpIdentifier];
            if (!cell) {
                cell = [[GameTableViewCell alloc]
                      initWithStyle:UITableViewCellStyleSubtitle
                    reuseIdentifier:tmpIdentifier];
            }
            cell.backgroundColor = [UIColor systemBackgroundColor];
        }
        cell.ratingLabel.text = @"";
        cell.ratingLabel.text = [message timeStamp];
        cell.textLabel.attributedText =
            [self.player markIfOnline:[message author]
                    andAttributedName:[message attributedName]];
        if ([[message unread] isEqualToString:@"unread"]) {
            NSMutableAttributedString *str = [[NSMutableAttributedString alloc]
                initWithString:[message subject]];
            [str addAttribute:NSForegroundColorAttributeName
                        value:[UIColor blackColor]
                        range:NSMakeRange(0, [str length])];
            cell.detailTextLabel.attributedText = str;
            if ([message.nameColor isEqual:UIColorFromRGB(0)]) {
                str = [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.textLabel.attributedText];
                long len = [str length];
                if ([str.string containsString:@" "]) {
                    len--;
                }
                [str addAttribute:NSForegroundColorAttributeName
                            value:[UIColor blackColor]
                            range:NSMakeRange(0, len)];
                cell.textLabel.attributedText = str;
            }
            str = [[NSMutableAttributedString alloc]
                initWithAttributedString:cell.ratingLabel.attributedText];
            [str addAttribute:NSForegroundColorAttributeName
                        value:[UIColor blackColor]
                        range:NSMakeRange(0, [str length])];
            cell.ratingLabel.attributedText = str;
        } else {
            cell.detailTextLabel.text = [message subject];
        }
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell setUserInteractionEnabled:YES];
        cell.imageView.image = imgV;
    }
    if (indexPath.section == INVITATIONSSECTION) {
        if (selectedInvitationIndexPath) {
            if ((selectedInvitationIndexPath.section == INVITATIONSSECTION) &&
                (indexPath.row == selectedInvitationIndexPath.row)) {
                return selectedInvitationCell;
            }
        }
        Game *game = [[self.player invitations] objectAtIndex:indexPath.row];
        NSString *opponent = [game opponentName];
        UIImage *imgV = [self.player.avatars objectForKey:opponent];
        if (imgV) {
            tmpIdentifier = CellWithAvatarIdentifier;
        } else {
            tmpIdentifier = CellIdentifier;
        }
        cell = (GameTableViewCell *)[tableView
            dequeueReusableCellWithIdentifier:tmpIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc]
                  initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:tmpIdentifier];
        }
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell.imageView removeFromSuperview];
        cell.ratingLabel.attributedText = [game ratingString];
        cell.textLabel.attributedText =
            [self.player markIfOnline:[game opponentName]
                    andAttributedName:[game attributedName]];
        if (![[game ratedNot] isEqualToString:@"Not Rated"]) {
            txtStr = (NSMutableString *)[NSString
                stringWithFormat:@"%@ (%@) - %@", [game gameType],
                                 [game localizedRatedNot],
                                 [game localizedTimeString]];
        } else {
            txtStr = (NSMutableString *)[NSString
                stringWithFormat:@"%@ (%@, %@) - %@", [game gameType],
                                 [game localizedRatedNot], [game myColor],
                                 [game localizedTimeString]];
        }
        cell.detailTextLabel.text = txtStr;
        [cell setUserInteractionEnabled:YES];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        cell.imageView.image = imgV;
        if ([[game ratedNot] rangeOfString:@"KotH"].location != NSNotFound) {
            cell.backgroundColor = [UIColor colorWithRed:222.0 / 256
                                                   green:236.0 / 256
                                                    blue:222.0 / 256
                                                   alpha:1];
        } else {
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor systemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor whiteColor];
            }
        }
        if ([[game ratedNot] containsString:@"KotH"]) {
            NSMutableAttributedString *attStr =
                [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.ratingLabel.attributedText];
            [attStr addAttribute:NSForegroundColorAttributeName
                           value:[UIColor blackColor]
                           range:NSMakeRange(2, [attStr length] - 2)];
            cell.ratingLabel.attributedText = attStr;
            attStr = [[NSMutableAttributedString alloc]
                initWithAttributedString:cell.textLabel.attributedText];
            long len = [attStr length];
            if ([attStr.string containsString:@" "]) {
                len--;
            }
            [attStr addAttribute:NSForegroundColorAttributeName
                           value:[UIColor blackColor]
                           range:NSMakeRange(0, len)];
            cell.textLabel.attributedText = attStr;
        }
    }
    if (indexPath.section == ACTIVEGAMESSECTION) {
        Game *game = [[self.player activeGames] objectAtIndex:indexPath.row];
        NSString *opponent = [game opponentName];
        UIImage *imgV = [self.player.avatars objectForKey:opponent];
        if (imgV) {
            tmpIdentifier = CellWithAvatarIdentifier;
        } else {
            tmpIdentifier = [[game myColor] isEqualToString:@"white"]
                                ? CellWithWhiteStoneImageIdentifier
                                : CellWithBlackStoneImageIdentifier;
        }
        cell = (GameTableViewCell *)[tableView
            dequeueReusableCellWithIdentifier:tmpIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc]
                  initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:tmpIdentifier];
        }

        cell.ratingLabel.attributedText = [game ratingString];

        cell.textLabel.attributedText =
            [self.player markIfOnline:[game opponentName]
                    andAttributedName:[game attributedName]];
        txtStr = [[NSMutableString alloc] initWithString:[game gameType]];
        [txtStr appendString:@" ("];
        [txtStr appendString:[game localizedRatedNot]];
        [txtStr appendString:@") - "];
        [txtStr appendString:[game localizedTimeString]];
        cell.detailTextLabel.text = txtStr;
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell setUserInteractionEnabled:YES];
        cell.backgroundColor = [UIColor whiteColor];
        if (imgV) {
            cell.imageView.image = imgV;
        } else {
            cell.imageView.image =
                [UIImage imageNamed:[NSString stringWithFormat:@"%@Stone.png",
                                                               [game myColor]]];
        }
        if ([[game ratedNot] containsString:@"Tournament"]) {
            cell.backgroundColor = [UIColor colorWithRed:222.0 / 256
                                                   green:236.0 / 256
                                                    blue:222.0 / 256
                                                   alpha:1];
            NSMutableAttributedString *attStr =
                [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.ratingLabel.attributedText];
            [attStr addAttribute:NSForegroundColorAttributeName
                           value:[UIColor blackColor]
                           range:NSMakeRange(2, [attStr length] - 2)];
            cell.ratingLabel.attributedText = attStr;
            if ([game.nameColor isEqual:UIColorFromRGB(0)]) {
                attStr = [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.textLabel.attributedText];
                long len = [attStr length];
                if ([attStr.string containsString:@" "]) {
                    len--;
                }
                [attStr addAttribute:NSForegroundColorAttributeName
                               value:[UIColor blackColor]
                               range:NSMakeRange(0, len)];
                cell.textLabel.attributedText = attStr;
            }
        } else {
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor systemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor whiteColor];
            }
        }
    }
    if (indexPath.section == PUBLICINVITATIONSSECTION) {
        Game *game =
            [[self.player publicInvitations] objectAtIndex:indexPath.row];
        if (selectedPublicInvitationIndexPath) {
            if ((selectedPublicInvitationIndexPath.section ==
                 PUBLICINVITATIONSSECTION) &&
                (indexPath.row == selectedPublicInvitationIndexPath.row)) {
                return selectedPublicInvitationCell;
            }
        }
        NSString *opponent = [game opponentName];
        UIImage *imgV = [self.player.avatars objectForKey:opponent];
        if (imgV) {
            tmpIdentifier = CellWithAvatarIdentifier;
        } else {
            tmpIdentifier = CellIdentifier;
        }
        cell = (GameTableViewCell *)[tableView
            dequeueReusableCellWithIdentifier:tmpIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc]
                  initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:tmpIdentifier];
        }
        cell.ratingLabel.attributedText = [game ratingString];

        cell.textLabel.attributedText =
            [self.player markIfOnline:[game opponentName]
                    andAttributedName:[game attributedName]];
        if (![[game ratedNot] isEqualToString:@"Not Rated"]) {
            txtStr = (NSMutableString *)[NSString
                stringWithFormat:@"%@ (%@) - %@", [game gameType],
                                 [game localizedRatedNot],
                                 [game localizedTimeString]];
        } else {
            txtStr = (NSMutableString *)[NSString
                stringWithFormat:@"%@ (%@, %@) - %@", [game gameType],
                                 [game localizedRatedNot], [game myColor],
                                 [game localizedTimeString]];
        }
        cell.detailTextLabel.text = txtStr;
        [cell setUserInteractionEnabled:YES];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        cell.imageView.image = imgV;
        if ([[game ratedNot] containsString:@"KotH"]) {
            cell.backgroundColor = [UIColor colorWithRed:222.0 / 256
                                                   green:236.0 / 256
                                                    blue:222.0 / 256
                                                   alpha:1];
        } else if ([[game ratedNot] containsString:@", beginner"]) {
            cell.backgroundColor = [UIColor colorWithRed:242.0 / 256
                                                   green:249.0 / 256
                                                    blue:222.0 / 256
                                                   alpha:1];
        } else {
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor systemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor whiteColor];
            }
        }
        if ([[game ratedNot] containsString:@"KotH"] ||
            [[game ratedNot] containsString:@", beginner"]) {
            NSMutableAttributedString *attStr =
                [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.ratingLabel.attributedText];
            [attStr addAttribute:NSForegroundColorAttributeName
                           value:[UIColor blackColor]
                           range:NSMakeRange(2, [attStr length] - 2)];
            cell.ratingLabel.attributedText = attStr;
            if ([game.nameColor isEqual:UIColorFromRGB(0)]) {
                attStr = [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.textLabel.attributedText];
                long len = [attStr length];
                if ([attStr.string containsString:@" "]) {
                    len--;
                }
                [attStr addAttribute:NSForegroundColorAttributeName
                               value:[UIColor blackColor]
                               range:NSMakeRange(0, len)];
                cell.textLabel.attributedText = attStr;
            }
        }
    }
    if (indexPath.section == SENTINVITATIONSSECTION) {
        Game *game =
            [[self.player sentInvitations] objectAtIndex:indexPath.row];
        NSString *opponent = [game opponentName];
        UIImage *imgV = [self.player.avatars objectForKey:opponent];
        if (imgV) {
            tmpIdentifier = CellWithAvatarIdentifier;
        } else {
            tmpIdentifier = CellIdentifier;
        }
        cell = (GameTableViewCell *)[tableView
            dequeueReusableCellWithIdentifier:tmpIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc]
                  initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:tmpIdentifier];
        }
        if ([game.opponentName rangeOfString:@"Anyone"].location == 0) {
            cell.ratingLabel.text = @"";
        } else {
            cell.ratingLabel.attributedText = [game ratingString];
        }

        cell.textLabel.attributedText =
            [self.player markIfOnline:[game opponentName]
                    andAttributedName:[game attributedName]];
        txtStr = [[NSMutableString alloc] initWithString:[game gameType]];
        [txtStr appendString:@" ("];
        [txtStr appendString:[game localizedRatedNot]];
        [txtStr appendString:@") - "];
        [txtStr appendString:[game localizedTimeString]];
        cell.detailTextLabel.text = txtStr;
        [cell setUserInteractionEnabled:YES];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        if ([[game ratedNot] rangeOfString:@"KotH"].location != NSNotFound) {
            cell.backgroundColor = [UIColor colorWithRed:222.0 / 256
                                                   green:236.0 / 256
                                                    blue:222.0 / 256
                                                   alpha:1];
        } else {
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor systemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor whiteColor];
            }
        }
        if ([[game ratedNot] containsString:@"KotH"] ||
            [[game ratedNot] containsString:@", beginner"]) {
            NSMutableAttributedString *attStr =
                [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.ratingLabel.attributedText];
            if (attStr.length > 2) {
                [attStr addAttribute:NSForegroundColorAttributeName
                               value:[UIColor blackColor]
                               range:NSMakeRange(2, [attStr length] - 2)];
                cell.ratingLabel.attributedText = attStr;
            }
            attStr = [[NSMutableAttributedString alloc]
                initWithAttributedString:cell.textLabel.attributedText];
            [attStr addAttribute:NSForegroundColorAttributeName
                           value:[UIColor blackColor]
                           range:NSMakeRange(0, [attStr length])];
            cell.textLabel.attributedText = attStr;
        }
        cell.imageView.image = imgV;
    }
    if (indexPath.section == NONACTIVEGAMESSECTION) {
        Game *game = [[self.player nonActiveGames] objectAtIndex:indexPath.row];
        NSString *opponent = [game opponentName];
        UIImage *imgV = [self.player.avatars objectForKey:opponent];
        if (imgV) {
            tmpIdentifier = CellWithAvatarIdentifier;
        } else {
            tmpIdentifier = [[game myColor] isEqualToString:@"white"]
                                ? CellWithWhiteStoneImageIdentifier
                                : CellWithBlackStoneImageIdentifier;
        }
        cell = (GameTableViewCell *)[tableView
            dequeueReusableCellWithIdentifier:tmpIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc]
                  initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:tmpIdentifier];
        }
        cell.ratingLabel.attributedText = [game ratingString];
        cell.textLabel.attributedText =
            [self.player markIfOnline:[game opponentName]
                    andAttributedName:[game attributedName]];
        txtStr = [[NSMutableString alloc] initWithString:[game gameType]];
        if (![[game ratedNot] isEqualToString:@"Not Rated"]) {
            txtStr = (NSMutableString *)[NSString
                stringWithFormat:@"%@ (%@) - %@", [game gameType],
                                 [game localizedRatedNot],
                                 [game localizedTimeString]];
        } else {
            txtStr = (NSMutableString *)[NSString
                stringWithFormat:@"%@ (%@, %@) - %@", [game gameType],
                                 [game localizedRatedNot], [game myColor],
                                 [game localizedTimeString]];
        }

        cell.detailTextLabel.text = txtStr;
        [cell setUserInteractionEnabled:YES];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        cell.backgroundColor = [UIColor whiteColor];
        if (imgV) {
            //            [cell.imageView setBounds:CGRectMake(0,0,
            //            cell.contentView.bounds.size.height,
            //            cell.contentView.bounds.size.height)];
            cell.imageView.image = imgV;
            [cell setNeedsDisplay];
        } else {
            cell.imageView.image =
                [UIImage imageNamed:[NSString stringWithFormat:@"%@Stone.png",
                                                               [game myColor]]];
        }
        if ([[game ratedNot] containsString:@"Tournament"]) {
            cell.backgroundColor = [UIColor colorWithRed:222.0 / 256
                                                   green:236.0 / 256
                                                    blue:222.0 / 256
                                                   alpha:1];
            NSMutableAttributedString *attStr =
                [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.ratingLabel.attributedText];
            [attStr addAttribute:NSForegroundColorAttributeName
                           value:[UIColor blackColor]
                           range:NSMakeRange(2, [attStr length] - 2)];
            cell.ratingLabel.attributedText = attStr;
            if ([game.nameColor isEqual:UIColorFromRGB(0)]) {
                attStr = [[NSMutableAttributedString alloc]
                    initWithAttributedString:cell.textLabel.attributedText];
                long len = [attStr length];
                if ([attStr.string containsString:@" "]) {
                    len--;
                }
                [attStr addAttribute:NSForegroundColorAttributeName
                               value:[UIColor blackColor]
                               range:NSMakeRange(0, len)];
                cell.textLabel.attributedText = attStr;
            }
        } else {
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor systemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor whiteColor];
            }
        }
    }
    if (indexPath.section == TOURNAMENTSSECTION) {
        Tournament *tourney =
            [[self.player tournaments] objectAtIndex:indexPath.row];
        cell = [tableView dequeueReusableCellWithIdentifier:@"tournament"];
        if (!cell) {
            cell = [[GameTableViewCell alloc]
                  initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:@"tournament"];
        }
        tmpStr = [[NSMutableAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"\u25CF  %@ - (%@)",
                                                      [tourney name],
                                                      [tourney game]]];
        [tmpStr addAttribute:NSFontAttributeName
                       value:[UIFont fontWithName:@"HelveticaNeue-Bold" size:18]
                       range:NSMakeRange(0, 1)];
        long len = [[tourney game] length];
        [tmpStr addAttribute:NSFontAttributeName
                       value:[UIFont fontWithName:@"HelveticaNeue" size:14]
                       range:NSMakeRange([tmpStr length] - 2 - len, len + 2)];
        UIColor *statusColor;
        if ([[tourney tournamentState] isEqualToString:@"2"]) {
            statusColor = [UIColor orangeColor];
            cell.detailTextLabel.text = [NSString
                stringWithFormat:NSLocalizedString(
                                     @"Registration closed. Starts %@", nil),
                                 [tourney date]];
        } else {
            statusColor = [UIColor greenColor];
            if ([[tourney tournamentState] isEqualToString:@"1"]) {
                cell.detailTextLabel.text = [NSString
                    stringWithFormat:NSLocalizedString(
                                         @"Registration is open until %@", nil),
                                     [tourney date]];
            } else {
                cell.detailTextLabel.text = [NSString
                    stringWithFormat:
                        NSLocalizedString(
                            @"Tournament started. Current round: %@", nil),
                        [tourney round]];
            }
        }
        [tmpStr addAttribute:NSForegroundColorAttributeName
                       value:statusColor
                       range:NSMakeRange(0, 1)];
        //        [tmpStr addAttribute:NSFontAttributeName value:[UIFont
        //        fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0,
        //        [tmpStr length])];
        cell.textLabel.attributedText = tmpStr;
        [cell setUserInteractionEnabled:YES];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }

    if (indexPath.section == KOTHSECTION) {
        KingOfTheHill *koth = [[self.player hills] objectAtIndex:indexPath.row];
        cell = [tableView dequeueReusableCellWithIdentifier:@"kingOfTheHill"];
        if (!cell) {
            cell = [[GameTableViewCell alloc]
                  initWithStyle:UITableViewCellStyleSubtitle
                reuseIdentifier:@"kingOfTheHill"];
        }
        tmpStr = [[NSMutableAttributedString alloc]
            initWithString:[NSString
                               stringWithFormat:@"\u25CF  %@ ", [koth game]]];
        [tmpStr addAttribute:NSFontAttributeName
                       value:[UIFont fontWithName:@"HelveticaNeue-Bold" size:18]
                       range:NSMakeRange(0, 1)];
        long len = [[koth game] length];
        [tmpStr addAttribute:NSFontAttributeName
                       value:[UIFont fontWithName:@"HelveticaNeue" size:16]
                       range:NSMakeRange([tmpStr length] - 1 - len, len)];
        UIColor *statusColor;
        if (![koth member]) {
            statusColor = [UIColor orangeColor];
        } else {
            statusColor = [UIColor greenColor];
        }
        [tmpStr addAttribute:NSForegroundColorAttributeName
                       value:statusColor
                       range:NSMakeRange(0, 1)];
        if ([koth king]) {
            [tmpStr addAttribute:NSForegroundColorAttributeName
                           value:[UIColor blackColor]
                           range:NSMakeRange(1, [tmpStr length] - 1)];
            NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
            textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
            NSAttributedString *crownStr = [NSAttributedString
                attributedStringWithAttachment:textAttachment];
            [tmpStr appendAttributedString:crownStr];
        }
        cell.textLabel.attributedText = tmpStr;
        if ([[koth currentKing] length] > 0) {
            NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
            textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
            NSAttributedString *crownStr = [NSAttributedString
                attributedStringWithAttachment:textAttachment];
            NSMutableAttributedString *str = [[NSMutableAttributedString alloc]
                initWithString:[koth currentKing]];
            [str appendAttributedString:[[NSAttributedString alloc]
                                            initWithString:@" "]];
            [str appendAttributedString:crownStr];
            tmpStr = [[NSMutableAttributedString alloc]
                initWithString:[NSString
                                   stringWithFormat:
                                       NSLocalizedString(
                                           @" %@ players ruled by %@ ", nil),
                                       [koth numPlayers], [koth currentKing]]];
            NSMutableAttributedString *tmpAttrStr = [crownStr mutableCopy];
            [tmpAttrStr appendAttributedString:[[NSAttributedString alloc]
                                                   initWithString:@" "]];
            [tmpStr insertAttributedString:tmpAttrStr
                                   atIndex:[[tmpStr string]
                                               rangeOfString:[koth currentKing]]
                                               .location +
                                           [[koth currentKing] length] + 1];
            //            cell.ratingLabel.attributedText = crownStr;
        } else {
            tmpStr = [[NSMutableAttributedString alloc]
                initWithString:
                    [NSString
                        stringWithFormat:NSLocalizedString(
                                             @" Number of players: %@", nil),
                                         [koth numPlayers]]];
        }
        cell.detailTextLabel.attributedText = tmpStr;
        [cell setUserInteractionEnabled:YES];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        if ([koth king]) {
            cell.backgroundColor = [UIColor colorWithRed:222.0 / 256
                                                   green:236.0 / 256
                                                    blue:222.0 / 256
                                                   alpha:1];
        } else {
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor systemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor whiteColor];
            }
        }
    }

    //    NSLog(@"kittyfontcell %@",cell.textLabel.font);
    //    [cell.textLabel setFont:[UIFont fontWithName:@"Helvetica Neue"
    //    size:17.f]];
    [cell.detailTextLabel setFont:[UIFont fontWithName:@"Helvetica Neue"
                                                  size:14.f]];
    [cell.detailTextLabel setTextColor:[UIColor grayColor]];
    //    [cell.detailTextLabel setAlpha:0.7];
    return cell;
}

- (void)sectionTap:(UIGestureRecognizer *)gestureRecognizer {

    [TSMessage dismissActiveNotification];

    //    NSLog(@"kittySection %i",gestureRecognizer.view.tag);
    int section = (int)gestureRecognizer.view.tag;
    NSMutableArray *indexSet = [[NSMutableArray alloc] init];
    //    NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
    NSArray *sectionArray;
    BOOL collapse;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    switch (gestureRecognizer.view.tag) {
    case MESSAGESSECTION:
        messagesCollapsed = !messagesCollapsed;
        [defaults setBool:messagesCollapsed forKey:@"messagesCollapsed"];
        collapse = messagesCollapsed;
        sectionArray = [self.player messages];
        break;
    case INVITATIONSSECTION:
        if (selectedInvitationIndexPath && !invitationsReceivedCollapsed) {
            [[self.tableView cellForRowAtIndexPath:selectedInvitationIndexPath]
                setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            [self.tableView beginUpdates];
            [self removeButtonsFromCell];
            selectedInvitationIndexPath = nil;
            selectedInvitationCell = nil;
            [self.tableView endUpdates];
        }
        invitationsReceivedCollapsed = !invitationsReceivedCollapsed;
        [defaults setBool:invitationsReceivedCollapsed
                   forKey:@"invitationsReceivedCollapsed"];
        collapse = invitationsReceivedCollapsed;
        sectionArray = [self.player invitations];
        break;
    case ACTIVEGAMESSECTION:
        activeGamesCollapsed = !activeGamesCollapsed;
        [defaults setBool:activeGamesCollapsed forKey:@"activeGamesCollapsed"];
        collapse = activeGamesCollapsed;
        sectionArray = [self.player activeGames];
        break;
    case PUBLICINVITATIONSSECTION:
        if (selectedPublicInvitationIndexPath && !publicInvitationsCollapsed) {
            [[self.tableView
                cellForRowAtIndexPath:selectedPublicInvitationIndexPath]
                setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            [self.tableView beginUpdates];
            [self removeButtonsFromPublicInvitationsCell];
            selectedPublicInvitationIndexPath = nil;
            selectedPublicInvitationCell = nil;
            [self.tableView endUpdates];
        }
        publicInvitationsCollapsed = !publicInvitationsCollapsed;
        [defaults setBool:publicInvitationsCollapsed
                   forKey:@"publicInvitationsCollapsed"];
        collapse = publicInvitationsCollapsed;
        sectionArray = [self.player publicInvitations];
        break;
    case SENTINVITATIONSSECTION:
        sentInvitationsCollapsed = !sentInvitationsCollapsed;
        [defaults setBool:sentInvitationsCollapsed
                   forKey:@"sentInvitationsCollapsed"];
        collapse = sentInvitationsCollapsed;
        sectionArray = [self.player sentInvitations];
        break;
    case NONACTIVEGAMESSECTION:
        nonActiveGamesCollapsed = !nonActiveGamesCollapsed;
        [defaults setBool:nonActiveGamesCollapsed
                   forKey:@"nonActiveGamesCollapsed"];
        collapse = nonActiveGamesCollapsed;
        sectionArray = [self.player nonActiveGames];
        break;
    case TOURNAMENTSSECTION:
        tournamentsCollapsed = !tournamentsCollapsed;
        [defaults setBool:tournamentsCollapsed forKey:@"tournamentsCollapsed"];
        collapse = tournamentsCollapsed;
        sectionArray = [self.player tournaments];
        break;
    case KOTHSECTION:
        kothCollapsed = !kothCollapsed;
        [defaults setBool:kothCollapsed forKey:@"kothCollapsed"];
        collapse = kothCollapsed;
        sectionArray = [[NSArray alloc] init];
        break;
    default:
        break;
    }
    for (int i = 0; i < [sectionArray count]; ++i) {
        [indexSet addObject:[NSIndexPath indexPathForRow:i inSection:section]];
    }
    [CATransaction begin];
    [self.tableView beginUpdates];
    [CATransaction setCompletionBlock:^{
        //            [self performSelector:@selector(scrollViewDidScroll:)
        //            withObject: self.tableView afterDelay:0.05];
        //        [self.tableView performSelector:@selector(reloadData)
        //        withObject: nil afterDelay:0.011];
        [self performSelector:@selector(scrollViewDidScroll:)
                   withObject:self.tableView
                   afterDelay:0.00];
    }];
    if (collapse) {
        [self.tableView deleteRowsAtIndexPaths:indexSet
                              withRowAnimation:UITableViewRowAnimationFade];
    } else {
        [self.tableView insertRowsAtIndexPaths:indexSet
                              withRowAnimation:UITableViewRowAnimationFade];
    }
    [self.tableView
          reloadSections:[NSIndexSet
                             indexSetWithIndex:gestureRecognizer.view.tag]
        withRowAnimation:UITableViewRowAnimationFade];
    //    [[self.tableView headerViewForSection:gestureRecognizer.view.tag]
    //    setNeedsLayout];
    //    [[self.tableView headerViewForSection:gestureRecognizer.view.tag]
    //    setNeedsDisplay];
    [self.tableView endUpdates];
    [CATransaction commit];
}

- (UIView *)tableView:(UITableView *)tableView
    viewForHeaderInSection:(NSInteger)section {
    //    NSLog(@"kitttttttyyyyyyyyy %i", section);

    UITapGestureRecognizer *sectionTapRecogniser =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(sectionTap:)];
    [sectionTapRecogniser setDelegate:self];
    sectionTapRecogniser.numberOfTouchesRequired = 1;
    sectionTapRecogniser.numberOfTapsRequired = 1;

    UILabel *headerLabel;
    UILabel *collapsedLabel;
    UIView *sectionHeaderView = [self.tableView
        dequeueReusableHeaderFooterViewWithIdentifier:@"Header"];
    //    [self.tableView headerViewForSection:section];
    if (sectionHeaderView == nil) {
        //        NSLog(@"kitten %i", section);
        sectionHeaderView = [[UIView alloc]
            initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width,
                                     tableView.sectionHeaderHeight)];
        sectionHeaderView.userInteractionEnabled = YES;
        sectionHeaderView.tag = section;
        sectionHeaderView.restorationIdentifier = @"Header";

        UIImageView *backgroundImageView = [[UIImageView alloc]
            initWithFrame:CGRectMake(0, -1, tableView.bounds.size.width, 23)];

        headerLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(12, 2, tableView.bounds.size.width - 40,
                                     18)];
        headerLabel.backgroundColor = [UIColor clearColor];
        headerLabel.textColor = [UIColor whiteColor];
        headerLabel.shadowColor = [UIColor darkGrayColor];
        headerLabel.shadowOffset = CGSizeMake(0, 1);
        headerLabel.font = [UIFont systemFontOfSize:15.0f];
        headerLabel.text = [self tableView:tableView
                   titleForHeaderInSection:section];
        headerLabel.tag = 0;
        collapsedLabel = [[UILabel alloc]
            initWithFrame:CGRectMake(tableView.bounds.size.width - 40, 2, 40,
                                     18)];
        collapsedLabel.center =
            CGPointMake(tableView.bounds.size.width - 20, 11);
        collapsedLabel.backgroundColor = [UIColor clearColor];
        collapsedLabel.textColor = [UIColor whiteColor];
        collapsedLabel.shadowColor = [UIColor darkGrayColor];
        collapsedLabel.shadowOffset = CGSizeMake(0, 1);
        //    collapsedLabel.font = [UIFont boldSystemFontOfSize:18];
        [collapsedLabel setFont:[UIFont fontWithName:@"CourierNewPS-BoldMT"
                                                size:17.0f]];
        collapsedLabel.tag = 1;

        [sectionHeaderView addSubview:backgroundImageView];
        [sectionHeaderView addSubview:headerLabel];
        [sectionHeaderView addSubview:collapsedLabel];
        [sectionHeaderView addGestureRecognizer:sectionTapRecogniser];
    }

    for (UIView *label in sectionHeaderView.subviews) {
        if ([label isKindOfClass:[UILabel class]]) {
            if (label.tag == 0) {
                headerLabel = (UILabel *)label;
            } else if (label.tag == 1) {
                collapsedLabel = (UILabel *)label;
            }
        }
    }
    //    sectionHeaderView.backgroundColor = [UIColor colorWithWhite:0
    //    alpha:0];

    //    backgroundImageView.image = [UIImage
    //    imageNamed:@"PlainTableViewSectionHeader.png"];

    switch (section) {
    case MESSAGESSECTION:
        if (messagesCollapsed)
            collapsedLabel.text = @"(+)";
        else
            collapsedLabel.text = @"(-)";
        break;
    case INVITATIONSSECTION:
        if (invitationsReceivedCollapsed)
            collapsedLabel.text = @"(+)";
        else
            collapsedLabel.text = @"(-)";
        break;
    case ACTIVEGAMESSECTION:
        if (activeGamesCollapsed)
            collapsedLabel.text = @"(+)";
        else
            collapsedLabel.text = @"(-)";
        break;
    case PUBLICINVITATIONSSECTION:
        if (publicInvitationsCollapsed)
            collapsedLabel.text = @"(+)";
        else
            collapsedLabel.text = @"(-)";
        break;
    case SENTINVITATIONSSECTION:
        if (sentInvitationsCollapsed)
            collapsedLabel.text = @"(+)";
        else
            collapsedLabel.text = @"(-)";
        break;
    case NONACTIVEGAMESSECTION:
        if (nonActiveGamesCollapsed)
            collapsedLabel.text = @"(+)";
        else
            collapsedLabel.text = @"(-)";
        break;
    case TOURNAMENTSSECTION:
        if (tournamentsCollapsed)
            collapsedLabel.text = @"(+)";
        else
            collapsedLabel.text = @"(-)";
        break;
    case KOTHSECTION:
        if (kothCollapsed)
            collapsedLabel.text = @"(+)";
        else
            collapsedLabel.text = @"(-)";
        break;

    default:
        collapsedLabel.text = @"+-";
        break;
    }

    BOOL unread = NO;
    for (Message *message in [self.player messages]) {
        unread = [message.unread isEqualToString:@"unread"];
        if (unread) {
            break;
        }
    }
    BOOL king = NO;
    for (KingOfTheHill *hill in [self.player hills]) {
        if ([hill king]) {
            king = YES;
            break;
        }
    }
    if ((section == MESSAGESSECTION) && (unread)) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0f
                                                              green:0.5f
                                                               blue:0
                                                              alpha:1.0]];
    } else if ((section == INVITATIONSSECTION) &&
               ([[self.player invitations] count] > 0)) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0f
                                                              green:0.5f
                                                               blue:0
                                                              alpha:1.0]];
    } else if ((section == ACTIVEGAMESSECTION) &&
               ([[self.player activeGames] count] > 0)) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0f
                                                              green:0.5f
                                                               blue:0
                                                              alpha:1.0]];
    } else if ((section == KOTHSECTION) && king) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0f
                                                              green:0.5f
                                                               blue:0
                                                              alpha:1.0]];
    } else {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:(8.0 / 255)
                                                              green:(52.0 / 255)
                                                               blue:(29.0 / 255)
                                                              alpha:1.0]];
    }

    return sectionHeaderView;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
    if (section == MESSAGESSECTION) {
        return [NSString
            stringWithFormat:NSLocalizedString(@"messages (%lu)", nil),
                             (unsigned long)[[self.player messages] count]];
    } else if (section == INVITATIONSSECTION) {
        return [NSString
            stringWithFormat:NSLocalizedString(@"invitations (%lu)", nil),
                             (unsigned long)[[self.player invitations] count]];
    } else if (section == ACTIVEGAMESSECTION) {
        return [NSString
            stringWithFormat:NSLocalizedString(@"my turn (%lu)", nil),
                             (unsigned long)[[self.player activeGames] count]];
    } else if (section == PUBLICINVITATIONSSECTION) {
        int kothInvitations = 0;
        for (Game *game in [self.player publicInvitations]) {
            if ([[game ratedNot] isEqualToString:@"KotH"]) {
                kothInvitations += 1;
            }
        }
        if (kothInvitations == 0) {
            return [NSString
                stringWithFormat:NSLocalizedString(@"public invitations (%lu)",
                                                   nil),
                                 (unsigned long)[[self.player publicInvitations]
                                     count]];
        } else {
            return [NSString
                stringWithFormat:NSLocalizedString(
                                     @"public invitations (%lu + %i KotH)",
                                     nil),
                                 (unsigned long)[[self.player publicInvitations]
                                     count] -
                                     kothInvitations,
                                 kothInvitations];
        }
    } else if (section == SENTINVITATIONSSECTION) {
        return [NSString
            stringWithFormat:NSLocalizedString(@"invitations sent (%lu)", nil),
                             (unsigned long)[[self.player sentInvitations]
                                 count]];
    } else if (section == NONACTIVEGAMESSECTION) {
        return [NSString
            stringWithFormat:NSLocalizedString(@"opponent's turn (%lu)", nil),
                             (unsigned long)[[self.player nonActiveGames]
                                 count]];
    } else if (section == TOURNAMENTSSECTION) {
        return [NSString
            stringWithFormat:NSLocalizedString(@"tournaments (%lu)", nil),
                             (unsigned long)[[self.player tournaments] count]];
    } else if (section == KOTHSECTION) {
        int hills = 0, totalHills;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"showOnlyTB"]) {
            totalHills = player.tbHills;
        } else {
            totalHills = (int)[[self.player hills] count];
        }
        for (KingOfTheHill *hill in [self.player hills]) {
            if ([hill king]) {
                hills += 1;
            }
        }
        if (hills > 0) {
            return [NSString
                stringWithFormat:NSLocalizedString(@"King of the Hill (%i/%lu)",
                                                   nil),
                                 hills, (unsigned long)totalHills];
        } else {
            return [NSString
                stringWithFormat:NSLocalizedString(@"King of the Hill (%lu)",
                                                   nil),
                                 (unsigned long)totalHills];
        }
    }
    return @"uh-oh";
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath
*)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath]
withRowAnimation:UITableViewRowAnimationFade];
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the
array, and add a new row to the table view
    }
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath
*)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath
*)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    self.tableView.layer.borderWidth = 0.0;

    if (selectedInvitationIndexPath) {
        [[self.tableView cellForRowAtIndexPath:selectedInvitationIndexPath]
            setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [self.tableView beginUpdates];
        [self removeButtonsFromCell];
        selectedInvitationIndexPath = nil;
        [self.tableView endUpdates];
    }
    if (selectedPublicInvitationIndexPath) {
        [[self.tableView
            cellForRowAtIndexPath:selectedPublicInvitationIndexPath]
            setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [self.tableView beginUpdates];
        [self removeButtonsFromPublicInvitationsCell];
        selectedPublicInvitationIndexPath = nil;
        [self.tableView endUpdates];
    }
    if ([segue.identifier isEqualToString:@"gameTap"]) {
        boardController =
            (BoardViewController *)segue.destinationViewController;
    }
    if ([segue.identifier isEqualToString:@"messagesTap"]) {
        messagesViewController =
            (MessagesViewController *)segue.destinationViewController;
    }
    if ([segue.identifier isEqualToString:@"settingsTap"]) {
        settingsViewController =
            (SettingsViewController *)segue.destinationViewController;
    }
    //    if([segue.identifier isEqualToString:@"addInvitationsTap"]){
    //        invitationsViewController = (InvitationsViewController
    //        *)segue.destinationViewController; long count = [[self.player
    //        activeGames] count] + [[self.player nonActiveGames] count]; for
    //        (Game *game in [self.player sentInvitations]) {
    //            if ([[game opponentName] isEqualToString:@"Anyone"]) {
    //                continue;
    //            }
    //            if ([[game ratedNot] isEqualToString:@"rated"]) {
    //                count += 2;
    //            } else {
    //                ++count;
    //            }
    //        }
    //        if (count > gamesLimit) {
    //            [invitationsViewController setOpenInvitationOnly: YES];
    //        } else {
    //            [invitationsViewController setOpenInvitationOnly: NO];
    //        }
    //    }
    //    if([segue.identifier isEqualToString:@"settingsTap"]){
    //        [(SettingsViewController *)segue.destinationViewController
    //        setNavC:(PenteNavigationViewController
    //        *)self.navigationController];
    //    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier
                                  sender:(id)sender {
    //    NSLog(@"kitty 1");
    return YES;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#>
     alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController
     animated:YES];
     */

    [TSMessage dismissActiveNotification];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == MESSAGESSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock:^{
            [self performSelector:@selector(scrollViewDidScroll:)
                       withObject:self.tableView
                       afterDelay:0.01];
        }];
        if (selectedInvitationIndexPath) {
            [self removeButtonsFromCell];
            //                [tableView beginUpdates];
            selectedInvitationIndexPath = nil;
            selectedInvitationCell = nil;
            //                [tableView endUpdates];
        }
        if (selectedPublicInvitationIndexPath) {
            [self removeButtonsFromPublicInvitationsCell];
            //                [tableView beginUpdates];
            selectedPublicInvitationIndexPath = nil;
            selectedPublicInvitationCell = nil;
            //                [tableView endUpdates];
        }
        [self.tableView endUpdates];
        [CATransaction commit];

        PenteNavigationViewController *navControllor =
            (PenteNavigationViewController *)self.navigationController;
        [navControllor setDeletedMessageRow:(int)indexPath.row];

        [self performSegueWithIdentifier:@"messagesTap" sender:self];

        [messagesViewController setPlayer:player];
        [messagesViewController setGamesLimit:gamesLimit];
        [messagesViewController
            setMessageID:[[[self.player messages] objectAtIndex:indexPath.row]
                             messageID]];
        [messagesViewController
            setAuthor:[[[self.player messages] objectAtIndex:indexPath.row]
                          author]];
        [messagesViewController
            setSubject:[[[self.player messages] objectAtIndex:indexPath.row]
                           subject]];
        if ([[[[self.player messages] objectAtIndex:indexPath.row] unread]
                isEqualToString:@"unread"]) {
            [[[self.player messages] objectAtIndex:indexPath.row]
                setUnread:@"read"];
            [self.tableView reloadData];
        }
    }
    if (indexPath.section == INVITATIONSSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock:^{
            [self performSelector:@selector(scrollViewDidScroll:)
                       withObject:self.tableView
                       afterDelay:0.01];
        }];
        if (selectedPublicInvitationIndexPath) {
            [self removeButtonsFromPublicInvitationsCell];
            //                [tableView beginUpdates];
            selectedPublicInvitationIndexPath = nil;
            selectedPublicInvitationCell = nil;
            //                [tableView endUpdates];
        }
        GameTableViewCell *cell =
            (GameTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
        if (selectedInvitationIndexPath) {
            if ((selectedInvitationIndexPath.section == indexPath.section) &&
                (selectedInvitationIndexPath.row == indexPath.row)) {
                [self removeButtonsFromCell];
                //                    [tableView beginUpdates];
                selectedInvitationIndexPath = nil;
                [cell setAccessoryType:
                          UITableViewCellAccessoryDisclosureIndicator];
                //                    [tableView endUpdates];

            } else {
                [self removeButtonsFromCell];
                GameTableViewCell *tmpCell =
                    (GameTableViewCell *)[self.tableView
                        cellForRowAtIndexPath:selectedInvitationIndexPath];
                [tmpCell setAccessoryType:
                             UITableViewCellAccessoryDisclosureIndicator];

                [cell setAccessoryType:UITableViewCellAccessoryNone];
                [cell layoutSubviews];
                //                    [tableView beginUpdates];
                selectedInvitationIndexPath = indexPath;
                //                    [tableView endUpdates];

                [self addButtonsToCell:cell];
                selectedInvitationCell = cell;
            }
        } else {
            //            NSLog(@"stopKitty");
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            //                [tableView beginUpdates];
            selectedInvitationIndexPath = indexPath;
            //                [tableView endUpdates];

            [self addButtonsToCell:cell];
            selectedInvitationCell = cell;
        }
        selectedGame = [[self.player invitations] objectAtIndex:indexPath.row];

        [self.tableView endUpdates];
        [CATransaction commit];
    }
    if (indexPath.section == ACTIVEGAMESSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock:^{
            [self performSelector:@selector(scrollViewDidScroll:)
                       withObject:self.tableView
                       afterDelay:0.01];
        }];
        if (selectedInvitationIndexPath) {
            [self removeButtonsFromCell];
            //            [tableView beginUpdates];
            selectedInvitationIndexPath = nil;
            selectedInvitationCell = nil;
            //            [tableView endUpdates];
        }
        if (selectedPublicInvitationIndexPath) {
            [self removeButtonsFromPublicInvitationsCell];
            //            [tableView beginUpdates];
            selectedPublicInvitationIndexPath = nil;
            selectedPublicInvitationCell = nil;
            //            [tableView endUpdates];
        }
        [self.tableView endUpdates];
        [CATransaction commit];
        selectedGame = [[self.player activeGames] objectAtIndex:indexPath.row];
        [self performSegueWithIdentifier:@"gameTap" sender:self];
        [boardController setGame:selectedGame];
        [boardController setActiveGame:YES];
        [boardController replayGame];
        [[boardController boardTapRecognizer] setEnabled:YES];
    }
    if (indexPath.section == PUBLICINVITATIONSSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock:^{
            [self performSelector:@selector(scrollViewDidScroll:)
                       withObject:self.tableView
                       afterDelay:0.01];
        }];
        if (selectedInvitationIndexPath) {
            [self removeButtonsFromCell];
            //                [tableView beginUpdates];
            selectedInvitationIndexPath = nil;
            selectedInvitationCell = nil;
            //                [tableView endUpdates];
        }

        GameTableViewCell *cell =
            (GameTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
        if (selectedPublicInvitationIndexPath) {
            if ((selectedPublicInvitationIndexPath.section ==
                 indexPath.section) &&
                (selectedPublicInvitationIndexPath.row == indexPath.row)) {
                [self removeButtonsFromPublicInvitationsCell];
                //                [tableView
                //                performSelector:@selector(beginUpdates)
                //                withObject: nil afterDelay:0.1];
                //                    [tableView beginUpdates];
                selectedPublicInvitationIndexPath = nil;
                [cell setAccessoryType:
                          UITableViewCellAccessoryDisclosureIndicator];
                //                [cell layoutSubviews];
                //                    [tableView endUpdates];

            } else {
                [self removeButtonsFromPublicInvitationsCell];
                GameTableViewCell *tmpCell = (GameTableViewCell
                                                  *)[self.tableView
                    cellForRowAtIndexPath:selectedPublicInvitationIndexPath];
                [tmpCell setAccessoryType:
                             UITableViewCellAccessoryDisclosureIndicator];

                [cell setAccessoryType:UITableViewCellAccessoryNone];
                [cell layoutSubviews];
                //                    [tableView beginUpdates];
                selectedPublicInvitationIndexPath = indexPath;
                //                    [tableView endUpdates];

                [self addButtonsToPublicInvitationsCell:cell];
                selectedPublicInvitationCell = cell;
            }
        } else {
            [cell setAccessoryType:UITableViewCellAccessoryNone];
            //                [tableView beginUpdates];
            selectedPublicInvitationIndexPath = indexPath;
            //                [tableView endUpdates];

            //            NSLog(@"stopKitty");
            [self addButtonsToPublicInvitationsCell:cell];
            selectedPublicInvitationCell = cell;
        }
        selectedGame =
            [[self.player publicInvitations] objectAtIndex:indexPath.row];
        [self.tableView endUpdates];
        [CATransaction commit];
    }
    if (indexPath.section == NONACTIVEGAMESSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock:^{
            [self performSelector:@selector(scrollViewDidScroll:)
                       withObject:self.tableView
                       afterDelay:0.01];
        }];
        if (selectedInvitationIndexPath) {
            [self removeButtonsFromCell];
            //                [tableView beginUpdates];
            selectedInvitationIndexPath = nil;
            selectedInvitationCell = nil;
            //                [tableView endUpdates];
        }
        if (selectedPublicInvitationIndexPath) {
            [self removeButtonsFromPublicInvitationsCell];
            //                [tableView beginUpdates];
            selectedPublicInvitationIndexPath = nil;
            selectedPublicInvitationCell = nil;
            //                [tableView endUpdates];
        }
        [self.tableView endUpdates];
        [CATransaction commit];

        [self performSegueWithIdentifier:@"gameTap" sender:self];

        selectedGame =
            [[self.player nonActiveGames] objectAtIndex:indexPath.row];
        [boardController setActiveGame:NO];
        [boardController setGame:selectedGame];
        [boardController replayGame];
        [[boardController boardTapRecognizer] setEnabled:YES];
        //        [[boardController boardTapRecognizer] setEnabled: NO];
    }

    if (indexPath.section == TOURNAMENTSSECTION) {
        NSString *url = @"https://www.google.com";
        if ([[[[self.player tournaments] objectAtIndex:indexPath.row]
                tournamentState] isEqualToString:@"2"]) {
            url = [NSString stringWithFormat:
                                @"https://www.pente.org/gameServer/tournaments/"
                                @"status.jsp?eid=%@&name2=%@&password2=%@",
                                [[[self.player tournaments]
                                    objectAtIndex:indexPath.row] tournamentID],
                                username, password];
            if (development) {
                url = [NSString
                    stringWithFormat:
                        @"https://localhost/gameServer/tournaments/"
                        @"status.jsp?eid=%@&name2=%@&password2=%@",
                        [[[self.player tournaments] objectAtIndex:indexPath.row]
                            tournamentID],
                        username, password];
            }
        } else if ([[[[self.player tournaments] objectAtIndex:indexPath.row]
                       tournamentState] isEqualToString:@"1"]) {
            url = [NSString
                stringWithFormat:
                    @"https://www.pente.org/gameServer/tournaments/"
                    @"tournamentConfirm.jsp?eid=%@&name2=%@&password2=%@",
                    [[[self.player tournaments] objectAtIndex:indexPath.row]
                        tournamentID],
                    username, password];
            if (development) {
                url = [NSString
                    stringWithFormat:
                        @"https://localhost/gameServer/tournaments/"
                        @"tournamentConfirm.jsp?eid=%@&name2=%@&password2=%@",
                        [[[self.player tournaments] objectAtIndex:indexPath.row]
                            tournamentID],
                        username, password];
            }
        } else {
            url = [NSString
                stringWithFormat:
                    @"https://www.pente.org/gameServer/tournaments/"
                    @"statusRound.jsp?eid=%@&round=%@&name2=%@&password2=%@",
                    [[[self.player tournaments] objectAtIndex:indexPath.row]
                        tournamentID],
                    [[[self.player tournaments] objectAtIndex:indexPath.row]
                        round],
                    username, password];
            if (development) {
                url = [NSString
                    stringWithFormat:
                        @"https://localhost/gameServer/tournaments/"
                        @"statusRound.jsp?eid=%@&round=%@&name2=%@&password2=%"
                        @"@",
                        [[[self.player tournaments] objectAtIndex:indexPath.row]
                            tournamentID],
                        [[[self.player tournaments] objectAtIndex:indexPath.row]
                            round],
                        username, password];
            }
        }
        PenteWebViewController *webViewController =
            [[PenteWebViewController alloc] initWithAddress:url];
        [self.navigationController pushViewController:webViewController
                                             animated:YES];
    }

    if (indexPath.section == KOTHSECTION) {
        KOTHTableViewController *vc = [[KOTHTableViewController alloc] init];
        [vc setHillSummary:[[self.player hills] objectAtIndex:indexPath.row]];
        [vc setPlayer:player];
        [vc setTitle:[(KingOfTheHill *)[[self.player hills]
                         objectAtIndex:indexPath.row] game]];
        [self.navigationController pushViewController:vc animated:YES];
    }
    [self performSelector:@selector(scrollViewDidScroll:)
               withObject:self.tableView
               afterDelay:0.305];
}

- (void)postToPenteOrgUrl:(NSDictionary *)urlAndPostString {
    //    NSLog(@"kitty");

    NSString *url = [urlAndPostString objectForKey:@"url"];
    NSString *postString = [urlAndPostString objectForKey:@"postString"];

    NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding
                                allowLossyConversion:YES];
    NSString *postLength =
        [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];

    //    [request setHTTPShouldUsePipelining: YES];

    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:NSLocalizedString(@"Error", nil)
                          message:[NSString
                                      stringWithFormat:NSLocalizedString(
                                                           @"Reason: %@", nil),
                                                       error.localizedDescription]
                         delegate:nil
                cancelButtonTitle:NSLocalizedString(@"OK", nil)
                otherButtonTitles:nil];
            //        [alert show];
            [alert performSelectorOnMainThread:@selector(show)
                                    withObject:nil
                                 waitUntilDone:YES];
            return;
        }
        //    NSData *responseData = [PenteHTTPClient sendSynchronousRequest:request
        //    returningResponse:&response error:&error]; NSString *dashboardString =
        //    [[NSString alloc] initWithData:responseData
        //    encoding:NSUTF8StringEncoding];
        (void)weakSelf;
    }];
}

- (void)acceptInvitation:(UIButton *)sender {
    //    long count = [[self.player activeGames] count] + [[self.player
    //    nonActiveGames] count]; for (Game *game in [self.player
    //    sentInvitations]) {
    //        if ([[game ratedNot] isEqualToString:@"rated"]) {
    //            count += 2;
    //        } else {
    //            ++count;
    //        }
    //    }
    //    if (count > gamesLimit) {
    //        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New
    //        account limit reached." message:@"You cannot accept more games.
    //        You can, however, play more games by posting open invitations. \n
    //        This limit will gradually increase as you finish more games."
    //        delegate:self cancelButtonTitle:@"Got it." otherButtonTitles:
    //        nil]; [alert setTag: 2]; [alert show]; return;
    //    }

    self.tableView.layer.borderWidth = 1.5;

    NSIndexPath *tmpPath = selectedInvitationIndexPath;

    NSString *url = @"https://www.pente.org/gameServer/tb/replyInvitation";
    if (development) {
        url = @"https://localhost/gameServer/tb/replyInvitation";
    }
    NSString *postString = [NSString
        stringWithFormat:@"sid=%@&inviteeMessage=&command=Accept&mobile=",
                         [[self.player.invitations objectAtIndex:tmpPath.row]
                             gameID]];
    NSDictionary *urlAndPostString = [NSDictionary
        dictionaryWithObjects:[NSArray arrayWithObjects:url, postString, nil]
                      forKeys:[NSArray
                                  arrayWithObjects:@"url", @"postString", nil]];
    [NSThread detachNewThreadSelector:@selector(postToPenteOrgUrl:)
                             toTarget:self
                           withObject:urlAndPostString];

    NSString *newFriend =
        [[self.player.invitations objectAtIndex:tmpPath.row] opponentName];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *toHistory =
        [[defaults objectForKey:@"invitedHistory"] mutableCopy];
    if (toHistory) {
        int i = 0;
        for (i = 0; i < [toHistory count]; ++i) {
            if ([[toHistory objectAtIndex:i]
                    localizedCaseInsensitiveCompare:newFriend] ==
                NSOrderedDescending)
                break;
        }
        if (![toHistory containsObject:newFriend]) {
            [toHistory insertObject:newFriend atIndex:i];
        }
    } else {
        toHistory = [NSMutableArray arrayWithObject:newFriend];
    }
    [defaults setObject:toHistory forKey:@"invitedHistory"];

    [UIView animateWithDuration:0.3
        animations:^{
            [self removeButtonsFromCell];
            [self.tableView beginUpdates];
            selectedInvitationIndexPath = nil;
            [self.tableView endUpdates];
            selectedInvitationCell = nil;
        }
        completion:^(BOOL finished) {
            [self performSelector:@selector(scrollViewDidScroll:)
                       withObject:self.tableView
                       afterDelay:0.01];
        }];

    [self.player.invitations removeObjectAtIndex:tmpPath.row];
    [UIView animateWithDuration:0.3
        animations:^{
            [self.tableView
                deleteRowsAtIndexPaths:[NSArray arrayWithObject:tmpPath]
                      withRowAnimation:UITableViewRowAnimationFade];
        }
        completion:^(BOOL finished) {
            [self dashboardParse];
        }];
}

- (void)rejectInvitation:(UIButton *)sender {
    //    [self.tableView setUserInteractionEnabled: NO];
    self.tableView.layer.borderWidth = 1.5;

    NSIndexPath *tmpPath = selectedInvitationIndexPath;

    NSString *post = [NSString
        stringWithFormat:@"sid=%@&inviteeMessage=&command=Decline&mobile=",
                         [[self.player.invitations objectAtIndex:tmpPath.row]
                             gameID]];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                          allowLossyConversion:YES];
    NSString *postLength =
        [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSURL *url = [NSURL
        URLWithString:@"https://www.pente.org/gameServer/tb/replyInvitation"];
    if (development) {
        url = [NSURL
            URLWithString:@"https://localhost/gameServer/tb/replyInvitation"];
    }
    [request setURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];

    //    [request setHTTPShouldUsePipelining: YES];

    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:NSLocalizedString(@"Error", nil)
                          message:[NSString
                                      stringWithFormat:NSLocalizedString(
                                                           @"Reason: %@", nil),
                                                       error.localizedDescription]
                         delegate:nil
                cancelButtonTitle:NSLocalizedString(@"OK", nil)
                otherButtonTitles:nil];
            //        [alert show];
            [alert performSelectorOnMainThread:@selector(show)
                                    withObject:nil
                                 waitUntilDone:YES];
            return;
        }
        //    NSData *responseData = [PenteHTTPClient sendSynchronousRequest:request
        //    returningResponse:&response error:&error]; NSString *dashboardString =
        //    [[NSString alloc] initWithData:responseData
        //    encoding:NSUTF8StringEncoding];

        [UIView animateWithDuration:0.3
            animations:^{
                [weakSelf removeButtonsFromCell];
                [weakSelf.tableView beginUpdates];
                selectedInvitationIndexPath = nil;
                [weakSelf.tableView endUpdates];
                selectedInvitationCell = nil;
            }
            completion:^(BOOL finished) {
                [weakSelf performSelector:@selector(scrollViewDidScroll:)
                           withObject:weakSelf.tableView
                           afterDelay:0.01];
                //[self parseDashboard];
            }];

        [weakSelf.player.invitations removeObjectAtIndex:tmpPath.row];

        [UIView animateWithDuration:0.3
            animations:^{
                [weakSelf.tableView
                    deleteRowsAtIndexPaths:[NSArray arrayWithObject:tmpPath]
                          withRowAnimation:UITableViewRowAnimationFade];
            }
        completion:^(BOOL finished) {
            [weakSelf dashboardParse];
        }];
    }];
}

- (void)cancelInvitation:(UIButton *)sender {
    [CATransaction begin];
    [self.tableView beginUpdates];
    [CATransaction setCompletionBlock:^{
        [self performSelector:@selector(scrollViewDidScroll:)
                   withObject:self.tableView
                   afterDelay:0.01];
    }];
    [selectedInvitationCell
        setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    [self removeButtonsFromCell];
    //        [self.tableView beginUpdates];
    selectedInvitationIndexPath = nil;
    //        [self.tableView endUpdates];
    selectedInvitationCell = nil;
    [self.tableView endUpdates];
    [CATransaction commit];
}

- (void)addButtonsToCell:(GameTableViewCell *)cell {

    cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelButton.backgroundColor = [UIColor clearColor];
    cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [cancelButton setTitleColor:[UIColor blackColor]
                       forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) {
        if ([cell.backgroundColor isEqual:[UIColor systemBackgroundColor]]) {
            [cancelButton setTitleColor:[UIColor labelColor]
                               forState:UIControlStateNormal];
        }
    }
    [cancelButton setTitle:NSLocalizedString(@"cancel", nil)
                  forState:UIControlStateNormal];
    [cancelButton addTarget:self
                     action:@selector(cancelInvitation:)
           forControlEvents:UIControlEventTouchUpInside];

    acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
    acceptButton.backgroundColor = [UIColor clearColor];
    acceptButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [acceptButton setTitleColor:[UIColor colorWithRed:0
                                                green:0.259
                                                 blue:0.145
                                                alpha:1]
                       forState:UIControlStateNormal];
    [acceptButton setTitle:NSLocalizedString(@"accept", nil)
                  forState:UIControlStateNormal];
    [acceptButton addTarget:self
                     action:@selector(acceptInvitation:)
           forControlEvents:UIControlEventTouchUpInside];

    rejectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rejectButton.backgroundColor = [UIColor clearColor];
    rejectButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [rejectButton setTitleColor:[UIColor colorWithRed:0.698
                                                green:0.133
                                                 blue:0.133
                                                alpha:1]
                       forState:UIControlStateNormal];
    [rejectButton setTitle:NSLocalizedString(@"decline", nil)
                  forState:UIControlStateNormal];
    [rejectButton addTarget:self
                     action:@selector(rejectInvitation:)
           forControlEvents:UIControlEventTouchUpInside];

    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width, spacing;

    NSDictionary *fontAttributes =
        [NSDictionary dictionaryWithObject:[acceptButton.titleLabel font]
                                    forKey:NSFontAttributeName];
    CGSize cancelFontSize =
               [cancelButton.titleLabel.text sizeWithAttributes:fontAttributes],
           acceptFontSize =
               [acceptButton.titleLabel.text sizeWithAttributes:fontAttributes],
           rejectFontSize =
               [rejectButton.titleLabel.text sizeWithAttributes:fontAttributes];

    spacing = (screenWidth - cancelFontSize.width - acceptFontSize.width -
               rejectFontSize.width - 45) /
              4;

    CGRect buttonFrame = CGRectMake(spacing, 45, cancelFontSize.width + 15.0,
                                    cancelFontSize.height + 10);
    [cancelButton setFrame:buttonFrame];
    buttonFrame =
        CGRectMake(2 * spacing + cancelButton.frame.size.width, 45,
                   acceptFontSize.width + 15.0, acceptFontSize.height + 10);
    [acceptButton setFrame:buttonFrame];
    buttonFrame =
        CGRectMake(3 * spacing + cancelButton.frame.size.width +
                       acceptButton.frame.size.width,
                   45, rejectFontSize.width + 15.0, rejectFontSize.height + 10);
    [rejectButton setFrame:buttonFrame];

    [cell performSelector:@selector(addSubview:)
               withObject:acceptButton
               afterDelay:0.25];
    [cell performSelector:@selector(addSubview:)
               withObject:cancelButton
               afterDelay:0.2];
    [cell performSelector:@selector(addSubview:)
               withObject:rejectButton
               afterDelay:0.3];
}

- (void)removeButtonsFromCell {
    [rejectButton performSelector:@selector(removeFromSuperview)
                       withObject:nil
                       afterDelay:0.05];
    [acceptButton performSelector:@selector(removeFromSuperview)
                       withObject:nil
                       afterDelay:0.1];
    [cancelButton performSelector:@selector(removeFromSuperview)
                       withObject:nil
                       afterDelay:0.15];
}

- (void)acceptPublicInvitation:(UIButton *)sender {
    Game *game = [self.player.publicInvitations
        objectAtIndex:selectedPublicInvitationIndexPath.row];
    if ([game.ratedNot containsString:@", beginner"]) {
        [self nagBeginnerAccept];
        return;
    }

    //    if (true || !player.subscriber) {
    if (!player.subscriber) {
        long openInvitationsLimit = [[NSUserDefaults standardUserDefaults]
            integerForKey:@"openInvitationsLimit"];
        //        if (true || openInvitationsLimit <= 1) {
        if (openInvitationsLimit <= 1) {
            UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:NSLocalizedString(
                                      @"Public invitations limit reached", nil)
                          message:
                              NSLocalizedString(
                                  @"After posting a public invitation, you you "
                                  @"will "
                                  @"be able to accept 2 more. To post a public "
                                  @"invitation, select humans in the play menu "
                                  @"and "
                                  @"leave the opponent field "
                                  @"blank.\n\nSubscribers "
                                  @"can accept public invitations without "
                                  @"limits.",
                                  nil)
                         delegate:self
                cancelButtonTitle:NSLocalizedString(@"Got it.", nil)
                otherButtonTitles:NSLocalizedString(@"Post now", nil),
                                  NSLocalizedString(@"Subscription info", nil),
                                  nil];
            [alert setTag:2];
            [alert show];
            return;
        }
        if (openInvitationsLimit > 1) {
            --openInvitationsLimit;
            [[NSUserDefaults standardUserDefaults]
                setInteger:openInvitationsLimit
                    forKey:@"openInvitationsLimit"];
        }
    }

    //    long count = [[self.player activeGames] count] + [[self.player
    //    nonActiveGames] count]; for (Game *game in [self.player
    //    sentInvitations]) {
    //        if ([[game ratedNot] isEqualToString:@"rated"]) {
    //            count += 2;
    //        } else {
    //            ++count;
    //        }
    //    }
    //    if (count > gamesLimit) {
    //        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New
    //        account limit reached." message:@"You cannot accept more games.
    //        You can, however, play more games by posting open invitations. \n
    //        This limit will gradually increase as you finish more games."
    //        delegate:self cancelButtonTitle:@"Got it." otherButtonTitles:
    //        nil]; [alert setTag: 2]; [alert show]; return;
    //    }

    self.tableView.layer.borderWidth = 1.5;
    [self performSelector:@selector(scrollViewDidScroll:)
               withObject:self.tableView];

    NSString *url = @"https://www.pente.org/gameServer/tb/replyInvitation";
    if (development) {
        url = @"https://localhost/gameServer/tb/replyInvitation";
    }
    NSString *postString = [NSString
        stringWithFormat:@"sid=%@&inviteeMessage=&command=Accept&mobile=",
                         [[self.player.publicInvitations
                             objectAtIndex:selectedPublicInvitationIndexPath
                                               .row] gameID]];
    NSDictionary *urlAndPostString = [NSDictionary
        dictionaryWithObjects:[NSArray arrayWithObjects:url, postString, nil]
                      forKeys:[NSArray
                                  arrayWithObjects:@"url", @"postString", nil]];
    [NSThread detachNewThreadSelector:@selector(postToPenteOrgUrl:)
                             toTarget:self
                           withObject:urlAndPostString];

    NSString *newFriend = [[self.player.publicInvitations
        objectAtIndex:selectedPublicInvitationIndexPath.row] opponentName];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *toHistory =
        [[defaults objectForKey:@"invitedHistory"] mutableCopy];
    if (toHistory) {
        int i = 0;
        for (i = 0; i < [toHistory count]; ++i) {
            if ([[toHistory objectAtIndex:i]
                    localizedCaseInsensitiveCompare:newFriend] ==
                NSOrderedDescending)
                break;
        }
        if (![toHistory containsObject:newFriend]) {
            [toHistory insertObject:newFriend atIndex:i];
        }
    } else {
        toHistory = [NSMutableArray arrayWithObject:newFriend];
    }
    [defaults setObject:toHistory forKey:@"invitedHistory"];

    NSIndexPath *tmpPath = selectedPublicInvitationIndexPath;
    [UIView animateWithDuration:0.3
        animations:^{
            [self removeButtonsFromPublicInvitationsCell];
            [self.tableView beginUpdates];
            selectedPublicInvitationIndexPath = nil;
            [self.tableView endUpdates];
            self->selectedPublicInvitationCell = nil;
        }
        completion:^(BOOL finished) {
            [self performSelector:@selector(scrollViewDidScroll:)
                       withObject:self.tableView
                       afterDelay:0.01];
        }];

    [self.player.publicInvitations removeObjectAtIndex:tmpPath.row];
    [UIView animateWithDuration:0.3
        animations:^{
            [self.tableView
                deleteRowsAtIndexPaths:[NSArray arrayWithObject:tmpPath]
                      withRowAnimation:UITableViewRowAnimationFade];
        }
        completion:^(BOOL finished) {
            [self dashboardParse];
            //        [self performSelector:@selector(scrollViewDidScroll:)
            //        withObject: self.tableView afterDelay:0.4];
        }];
    //    [self.tableView deleteRowsAtIndexPaths:[NSArray
    //    arrayWithObject:tmpPath]
    //    withRowAnimation:UITableViewRowAnimationFade]; [self
    //    performSelector:@selector(parseDashboard) withObject: nil
    //    afterDelay:0.7]; [self.tableView performSelector:@selector(reloadData)
    //    withObject: nil afterDelay:0.7]; [self
    //    performSelector:@selector(parseDashboard) withObject: nil
    //    afterDelay:0.5]; [self.tableView performSelector:@selector(reloadData)
    //    withObject: nil afterDelay:0.5];
}

- (void)cancelPublicInvitation:(UIButton *)sender {
    long openInvitationsLimit = [[NSUserDefaults standardUserDefaults]
        integerForKey:@"openInvitationsLimit"];
    if (openInvitationsLimit > 2) {
        openInvitationsLimit -= 2;
    } else if (openInvitationsLimit == 2) {
        openInvitationsLimit = 1;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:openInvitationsLimit
                                               forKey:@"openInvitationsLimit"];

    [CATransaction begin];
    [self.tableView beginUpdates];
    [CATransaction setCompletionBlock:^{
        [self performSelector:@selector(scrollViewDidScroll:)
                   withObject:self.tableView
                   afterDelay:0.01];
    }];
    [selectedPublicInvitationCell
        setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    [self removeButtonsFromPublicInvitationsCell];
    //    [self.tableView beginUpdates];
    selectedPublicInvitationIndexPath = nil;
    //    [self.tableView endUpdates];
    selectedPublicInvitationCell = nil;
    [self.tableView endUpdates];
    [CATransaction commit];
    //    [self performSelector:@selector(scrollViewDidScroll:) withObject:
    //    self.tableView afterDelay:0.32f];
}

- (void)addButtonsToPublicInvitationsCell:(GameTableViewCell *)cell {

    cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelButton.backgroundColor = [UIColor clearColor];
    cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [cancelButton setTitleColor:[UIColor blackColor]
                       forState:UIControlStateNormal];
    if (@available(iOS 13.0, *)) {
        if ([cell.backgroundColor isEqual:[UIColor systemBackgroundColor]]) {
            [cancelButton setTitleColor:[UIColor labelColor]
                               forState:UIControlStateNormal];
        }
    }
    [cancelButton setTitle:NSLocalizedString(@"cancel", nil)
                  forState:UIControlStateNormal];
    [cancelButton addTarget:self
                     action:@selector(cancelPublicInvitation:)
           forControlEvents:UIControlEventTouchUpInside];

    acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
    acceptButton.backgroundColor = [UIColor clearColor];
    acceptButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [acceptButton setTitleColor:[UIColor colorWithRed:0
                                                green:0.259
                                                 blue:0.145
                                                alpha:1]
                       forState:UIControlStateNormal];
    [acceptButton setTitle:NSLocalizedString(@"accept", nil)
                  forState:UIControlStateNormal];
    [acceptButton addTarget:self
                     action:@selector(acceptPublicInvitation:)
           forControlEvents:UIControlEventTouchUpInside];

    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width, spacing;

    NSDictionary *fontAttributes =
        [NSDictionary dictionaryWithObject:[acceptButton.titleLabel font]
                                    forKey:NSFontAttributeName];
    CGSize cancelFontSize =
               [cancelButton.titleLabel.text sizeWithAttributes:fontAttributes],
           acceptFontSize =
               [acceptButton.titleLabel.text sizeWithAttributes:fontAttributes];

    spacing =
        (screenWidth - cancelFontSize.width - acceptFontSize.width - 45) / 3;

    CGRect buttonFrame = CGRectMake(spacing, 45, cancelFontSize.width + 15.0,
                                    cancelFontSize.height + 10);
    [cancelButton setFrame:buttonFrame];
    buttonFrame =
        CGRectMake(2 * spacing + cancelButton.frame.size.width, 45,
                   acceptFontSize.width + 15.0, acceptFontSize.height + 10);
    [acceptButton setFrame:buttonFrame];

    [cell performSelector:@selector(addSubview:)
               withObject:acceptButton
               afterDelay:0.25];
    [cell performSelector:@selector(addSubview:)
               withObject:cancelButton
               afterDelay:0.2];
}

- (void)removeButtonsFromPublicInvitationsCell {
    [acceptButton performSelector:@selector(removeFromSuperview)
                       withObject:nil
                       afterDelay:0.05];
    [cancelButton performSelector:@selector(removeFromSuperview)
                       withObject:nil
                       afterDelay:0.1];
}

- (void)tableView:(UITableView *)tableView
    willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == PUBLICINVITATIONSSECTION) {
        [[tableView cellForRowAtIndexPath:indexPath] layoutSubviews];
    }
}

- (BOOL)tableView:(UITableView *)tableView
    canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((indexPath.section == PUBLICINVITATIONSSECTION) ||
        (indexPath.section == TOURNAMENTSSECTION) ||
        (indexPath.section == KOTHSECTION) ||
        (indexPath.section == NONACTIVEGAMESSECTION)) {
        return NO;
    }
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MESSAGESSECTION) {
        return NSLocalizedString(@"delete", nil);
    }
    if (indexPath.section == ACTIVEGAMESSECTION) {
        return NSLocalizedString(@"resign", nil);
    }
    if (indexPath.section == SENTINVITATIONSSECTION) {
        return NSLocalizedString(@"cancel", nil);
    }
    //    if (indexPath.section == NONACTIVEGAMESSECTION) {
    //        return @"cancel set";
    //    }
    return @"uh-oh";
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((indexPath.section != PUBLICINVITATIONSSECTION) &&
        (indexPath.section != TOURNAMENTSSECTION)) {
        return UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    //    if (editingStyle == UITableViewCellEditingStyleDelete) {
    [self.tableView beginUpdates];
    selectedInvitationIndexPath = nil;
    selectedInvitationCell = nil;
    [self.tableView endUpdates];
    if (indexPath.section == MESSAGESSECTION) {
        //            [self.tableView setUserInteractionEnabled: NO];
        self.tableView.layer.borderWidth = 1.5;
        [self performSelector:@selector(scrollViewDidScroll:)
                   withObject:self.tableView];

        //        NSUserDefaults *defaults = [NSUserDefaults
        //        standardUserDefaults]; username = [defaults
        //        objectForKey:usernameKey]; password = [defaults
        //        objectForKey:passwordKey];

        NSString *post = [NSString
            stringWithFormat:
                @"command=delete&mid=%@&name2=%@&password2=%@&mobile=",
                [[[self.player messages] objectAtIndex:indexPath.row]
                    messageID],
                username, password];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                              allowLossyConversion:YES];
        NSString *postLength = [NSString
            stringWithFormat:@"%lu", (unsigned long)[postData length]];

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

        NSURL *url = [NSURL
            URLWithString:@"https://www.pente.org/gameServer/mymessages"];
        if (development) {
            url = [NSURL
                URLWithString:@"https://localhost/gameServer/mymessages"];
        }
        [request setURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded"
            forHTTPHeaderField:@"Content-Type"];

        //        [request setHTTPShouldUsePipelining: YES];

        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        __weak typeof(self) weakSelf = self;
        [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:NSLocalizedString(@"Error", nil)
                              message:[NSString
                                          stringWithFormat:
                                              NSLocalizedString(@"Reason: %@", nil),
                                              error.localizedDescription]
                             delegate:nil
                    cancelButtonTitle:NSLocalizedString(@"OK", nil)
                    otherButtonTitles:nil];
                //        [alert show];
                [alert performSelectorOnMainThread:@selector(show)
                                        withObject:nil
                                     waitUntilDone:YES];
                return;
            }
            //        NSData *responseData = [NSURLConnection
            //        sendSynchronousRequest:request returningResponse:&response
            //        error:&error]; NSString *dashboardString = [[NSString alloc]
            //        initWithData:responseData encoding:NSUTF8StringEncoding];
            //        //        [self login];
            //        NSLog(@"kitty %@", dashboardString);

            [weakSelf.player.messages removeObjectAtIndex:indexPath.row];
            [UIView animateWithDuration:0.3
                animations:^{
                    [weakSelf.tableView
                        deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
                    //            [tableView reloadData];
                }
                completion:^(BOOL finished) {
                    [weakSelf dashboardParse];
                    [weakSelf performSelector:@selector(scrollViewDidScroll:)
                               withObject:weakSelf.tableView
                               afterDelay:0.01];
                }];
            //            [self.tableView deleteRowsAtIndexPaths:[NSArray
            //            arrayWithObject:indexPath]
            //            withRowAnimation:UITableViewRowAnimationFade]; [self
            //            parseDashboard]; [self.tableView reloadData];
        }];
    }
    if (indexPath.section == ACTIVEGAMESSECTION) {
        //            [self.tableView setUserInteractionEnabled: NO];
        self.tableView.layer.borderWidth = 1.5;
        [self performSelector:@selector(scrollViewDidScroll:)
                   withObject:self.tableView];
        NSString *post = [NSString
            stringWithFormat:@"gid=%@&command=resign&mobile=",
                             [[self.player.activeGames
                                 objectAtIndex:indexPath.row] gameID]];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                              allowLossyConversion:YES];
        NSString *postLength = [NSString
            stringWithFormat:@"%lu", (unsigned long)[postData length]];

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

        NSURL *url =
            [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/resign"];
        if (development) {
            url =
                [NSURL URLWithString:@"https://localhost/gameServer/tb/resign"];
        }
        [request setURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded"
            forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];

        //        [request setHTTPShouldUsePipelining: YES];

        __weak typeof(self) weakSelf = self;
        [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:NSLocalizedString(@"Error", nil)
                              message:[NSString
                                          stringWithFormat:
                                              NSLocalizedString(@"Reason: %@", nil),
                                              error.localizedDescription]
                             delegate:nil
                    cancelButtonTitle:NSLocalizedString(@"OK", nil)
                    otherButtonTitles:nil];
                //        [alert show];
                [alert performSelectorOnMainThread:@selector(show)
                                        withObject:nil
                                     waitUntilDone:YES];
                return;
            }
            //    NSData *responseData = [NSURLConnection
            //    sendSynchronousRequest:request returningResponse:&response
            //    error:&error]; NSString *dashboardString =
            //    [[NSString alloc] initWithData:responseData
            //    encoding:NSUTF8StringEncoding];

            [weakSelf.player.activeGames removeObjectAtIndex:indexPath.row];
            [UIView animateWithDuration:0.3
                animations:^{
                    [weakSelf.tableView
                        deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
                }
                completion:^(BOOL finished) {
                    [weakSelf dashboardParse];
                    [weakSelf performSelector:@selector(scrollViewDidScroll:)
                               withObject:weakSelf.tableView
                               afterDelay:0.01];
                }];
            //            [self.tableView deleteRowsAtIndexPaths:[NSArray
            //            arrayWithObject:indexPath]
            //            withRowAnimation:UITableViewRowAnimationFade]; [self
            //            parseDashboard]; [self.tableView reloadData];
        }];
    }

    if (indexPath.section == SENTINVITATIONSSECTION) {
        //            [self.tableView setUserInteractionEnabled: NO];
        self.tableView.layer.borderWidth = 1.5;
        [self performSelector:@selector(scrollViewDidScroll:)
                   withObject:self.tableView];
        NSString *post = [NSString
            stringWithFormat:@"sid=%@&command=Cancel&mobile=",
                             [[self.player.sentInvitations
                                 objectAtIndex:indexPath.row] gameID]];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                              allowLossyConversion:YES];
        NSString *postLength = [NSString
            stringWithFormat:@"%lu", (unsigned long)[postData length]];

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

        NSURL *url =
            [NSURL URLWithString:
                       @"https://www.pente.org/gameServer/tb/cancelInvitation"];
        if (development) {
            url =
                [NSURL URLWithString:
                           @"https://localhost/gameServer/tb/cancelInvitation"];
        }
        [request setURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded"
            forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];

        //        [request setHTTPShouldUsePipelining: YES];

        __weak typeof(self) weakSelf = self;
        [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:NSLocalizedString(@"Error", nil)
                              message:[NSString
                                          stringWithFormat:
                                              NSLocalizedString(@"Reason: %@", nil),
                                              error.localizedDescription]
                             delegate:nil
                    cancelButtonTitle:NSLocalizedString(@"OK", nil)
                    otherButtonTitles:nil];
                //        [alert show];
                [alert performSelectorOnMainThread:@selector(show)
                                        withObject:nil
                                     waitUntilDone:YES];
                return;
            }
            //    NSData *responseData = [NSURLConnection
            //    sendSynchronousRequest:request returningResponse:&response
            //    error:&error]; NSString *dashboardString =
            //    [[NSString alloc] initWithData:responseData
            //    encoding:NSUTF8StringEncoding];

            [weakSelf.player.sentInvitations removeObjectAtIndex:indexPath.row];
            [UIView animateWithDuration:0.1
                animations:^{
                    [weakSelf.tableView
                        deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
                }
                completion:^(BOOL finished) {
                    [weakSelf dashboardParse];
                    [weakSelf performSelector:@selector(scrollViewDidScroll:)
                               withObject:weakSelf.tableView
                               afterDelay:0.01];
                }];
            //            [self.tableView deleteRowsAtIndexPaths:[NSArray
            //            arrayWithObject:indexPath]
            //            withRowAnimation:UITableViewRowAnimationFade]; [self
            //            parseDashboard]; [self.tableView reloadData];
        }];
    }
    if (indexPath.section == NONACTIVEGAMESSECTION) {
        //            [self.tableView setUserInteractionEnabled: NO];
        self.tableView.layer.borderWidth = 1.5;
        [self performSelector:@selector(scrollViewDidScroll:)
                   withObject:self.tableView];

        NSString *tmpStr = [NSString
            stringWithFormat:
                @"https://www.pente.org/gameServer/tb/game?gid=%@&command=load",
                [[self.player.nonActiveGames objectAtIndex:indexPath.row]
                    gameID]];
        if (development) {
            tmpStr = [NSString
                stringWithFormat:
                    @"https://localhost/gameServer/tb/game?gid=%@&command=load",
                    [[self.player.nonActiveGames objectAtIndex:indexPath.row]
                        gameID]];
        }
        NSURL *url = [NSURL URLWithString:tmpStr];
        NSError *error;
        NSString *htmlString =
            [NSString stringWithContentsOfURL:url
                                     encoding:NSASCIIStringEncoding
                                        error:&error];
        NSRange movesRange = NSMakeRange(0, [htmlString length]);
        movesRange = [htmlString rangeOfString:@"     sid=\""
                                       options:0
                                         range:movesRange];
        movesRange.length = [htmlString length] - movesRange.location - 10;
        movesRange.location = movesRange.location + 10;
        NSRange movesRangeEnd =
            [[htmlString substringWithRange:movesRange] rangeOfString:@"\""];
        movesRange.length = movesRangeEnd.location;
        [[self.player.nonActiveGames objectAtIndex:indexPath.row]
            setSetID:[htmlString substringWithRange:movesRange]];

        NSString *post =
            [NSString stringWithFormat:@"sid=%@&command=request&mobile=",
                                       [[self.player.nonActiveGames
                                           objectAtIndex:indexPath.row] setID]];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                              allowLossyConversion:YES];
        NSString *postLength = [NSString
            stringWithFormat:@"%lu", (unsigned long)[postData length]];

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

        url =
            [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/cancel"];
        if (development) {
            url =
                [NSURL URLWithString:@"https://localhost/gameServer/tb/cancel"];
        }
        [request setURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded"
            forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        __weak typeof(self) weakSelf = self;
        [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:NSLocalizedString(@"Error", nil)
                              message:[NSString
                                          stringWithFormat:
                                              NSLocalizedString(@"Reason: %@", nil),
                                              error.localizedDescription]
                             delegate:nil
                    cancelButtonTitle:NSLocalizedString(@"OK", nil)
                    otherButtonTitles:nil];
                [alert show];
                return;
            }
            NSString *dashboardString =
                [[NSString alloc] initWithData:responseData
                                      encoding:NSUTF8StringEncoding];
            NSRange movesRange = NSMakeRange(0, [dashboardString length]);
            movesRange = [dashboardString
                rangeOfString:@"Error: Cancel request already exists."
                      options:0
                        range:movesRange];
            if (movesRange.location != NSNotFound) {
                UIAlertView *alert = [[UIAlertView alloc]
                        initWithTitle:NSLocalizedString(@"Error", nil)
                              message:NSLocalizedString(
                                          @"A cancel request already exists.", nil)
                             delegate:nil
                    cancelButtonTitle:NSLocalizedString(@"OK", nil)
                    otherButtonTitles:nil];
                [alert show];
                strongSelf.tableView.layer.borderWidth = 0.0;
                [strongSelf.tableView setEditing:FALSE animated:TRUE];
            } else {
                [strongSelf dashboardParse];
            }
        }];
    }

    //    }
}

- (void)dashboardParse {
    [self performSelector:@selector(scrollViewDidScroll:)
               withObject:self.tableView
               afterDelay:0.05];
    self.tableView.layer.borderWidth = 1.5;

    [NSThread detachNewThreadSelector:@selector(parseDashboard)
                             toTarget:self
                           withObject:nil];
}

- (void)showErrorAlertWithMessage:(NSString *)message {
    UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"Error", nil)
                  message:[NSString stringWithFormat:NSLocalizedString(
                                                         @"Reason: %@", nil),
                                                     message]
                 delegate:nil
        cancelButtonTitle:NSLocalizedString(@"OK", nil)
        otherButtonTitles:nil];
    //            [alert show];
    [alert performSelectorOnMainThread:@selector(show)
                            withObject:nil
                         waitUntilDone:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(pullDownToReloadActionFinished)
                   withObject:nil];
        self.tableView.layer.borderWidth = 0.0;
        [self.tableView setUserInteractionEnabled:YES];
        //            [self performSegueWithIdentifier:@"settingsTap"
        //            sender:self];
        //        settingsViewController.showAIOption = YES;
    });
}

- (void)updateSection:(NSInteger)section
             newItems:(NSMutableArray *)newItems
             oldItems:(NSMutableArray *)oldItems
            collapsed:(BOOL)collapsed
               setter:(void (^)(NSMutableArray *))setter {
    if ([newItems count] != [oldItems count]) {
        if (!collapsed) {
            NSMutableArray *indexSet = [[NSMutableArray alloc] init];
            for (int i = 0; i < (int)[oldItems count]; ++i)
                [indexSet addObject:[NSIndexPath indexPathForRow:i inSection:section]];
            setter([[NSMutableArray alloc] init]);
            [self.tableView deleteRowsAtIndexPaths:indexSet
                                  withRowAnimation:UITableViewRowAnimationFade];
        }
        setter(newItems);
        if (!collapsed) {
            NSMutableArray *indexSet = [[NSMutableArray alloc] init];
            for (int i = 0; i < (int)[newItems count]; ++i)
                [indexSet addObject:[NSIndexPath indexPathForRow:i inSection:section]];
            [self.tableView insertRowsAtIndexPaths:indexSet
                                  withRowAnimation:UITableViewRowAnimationFade];
        }
    } else {
        setter(newItems);
    }
}

- (void)parseDashboard {
    UIColor *blackColor = UIColorFromRGB(0);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pullToReloadHeaderView setStatusString:@"Loading Games..."
                                            animated:YES];
        [self.pullToReloadHeaderView layoutSubviews];
    });

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    username = [defaults objectForKey:usernameKey];
    password = [defaults objectForKey:passwordKey];
    BOOL wantsToSeeAvatars = [defaults boolForKey:@"wantToSeeAvatars"];
    if (!wantsToSeeAvatars) {
        [self.player.avatars removeAllObjects];
        [self.player.pendingAvatarChecks removeAllObjects];
    }
    self.tableView.layer.borderWidth = 1.5;

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url;

    // connect to the game server
    url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobile/"
                                     @"json/index.jsp?name=%@&password=%@",
                                     username, password];
    //    url =  [NSString
    //    stringWithFormat:@"https://www.pente.org/gameServer/mobile/index.jsp?name=%@&password=%@&checkname=graviton",username,password];
    //    url =  [NSString
    //    stringWithFormat:@"https://www.pente.org/gameServer/mobile/index.jsp?name=%@&password=%@&checkname=padler66",username,password];
    //    username = @"padler66";
    if (development) {
        url = [NSString stringWithFormat:@"https://localhost/gameServer/mobile/"
                                         @"json/index.jsp?name=%@&password=%@",
                                         username, password];
        //        url =  [NSString
        //        stringWithFormat:@"https://localhost/gameServer/mobile/index.jsp?name=harveyjoe&password=tsetsoi"];
        //        url =  [NSString
        //        stringWithFormat:@"https://localhost/gameServer/mobile/index.jsp?name=%@&password=%@&checkname=harveyjoe",username,password];
        //        url =  [NSString
        //        stringWithFormat:@"https://localhost/gameServer/mobile/index.jsp?name=%@&password=%@&checkname=iostest",username,password];
        //        username = @"harveyjoe";
    }

    //    NSLog(@"kitty %@, %@", username, password);

    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        //    NSString *dashboardString = [NSString stringWithContentsOfURL:[NSURL
        //    URLWithString:url] encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            [strongSelf showErrorAlertWithMessage:error.localizedDescription];
            return;
        }
        // read the response into a dictionary
        NSError *jsonError;
        NSDictionary *jsonResponse =
            [NSJSONSerialization JSONObjectWithData:responseData
                                            options:NSJSONReadingMutableContainers
                                              error:&jsonError];
        if (jsonError) {
            [strongSelf showErrorAlertWithMessage:jsonError.localizedDescription];
            return;
        }

        [CATransaction begin];
        [CATransaction setCompletionBlock:^{
            strongSelf.tableView.layer.borderWidth = 0.0;
            [strongSelf performSelector:@selector(scrollViewDidScroll:)
                       withObject:strongSelf.tableView
                       afterDelay:0.01];
            //            [self performSelector:@selector(scrollViewDidScroll:)
            //            withObject: self.tableView afterDelay:0.05];
            [strongSelf performSelector:@selector(pullDownToReloadActionFinished)
                       withObject:nil];
            [strongSelf parseMessages];
        }];
        [strongSelf.tableView beginUpdates];

        [strongSelf.tableView setUserInteractionEnabled:NO];

        if (![jsonResponse objectForKey:@"invitationsReceived"]) {
            strongSelf.tableView.layer.borderWidth = 0.0;
            [strongSelf performSelector:@selector(scrollViewDidScroll:)
                       withObject:strongSelf.tableView
                       afterDelay:0.01];
            [strongSelf performSelector:@selector(pullDownToReloadActionFinished)
                       withObject:nil];
            [strongSelf.tableView setUserInteractionEnabled:YES];
            return;
        } else {
            [defaults setBool:YES forKey:@"registrationSuccess"];
        }

        NSMutableArray *sectionItems;
        NSMutableArray *indexSet;

        NSDictionary *userInfo = jsonResponse[@"player"];
        [strongSelf.player setMyColor:UIColorFromRGB([userInfo[@"color"] intValue])];
        [strongSelf.player setShowAds:[userInfo[@"showAds"] boolValue]];
        [strongSelf.player setPlayerName:userInfo[@"name"]];
        [strongSelf.player setSubscriber:[userInfo[@"subscriber"] boolValue]];
        [strongSelf.player setDbAccess:[userInfo[@"dbAccess"] boolValue]];
        [strongSelf.player setEmailMe:[userInfo[@"emailMe"] boolValue]];
        [[NSUserDefaults standardUserDefaults] setBool:strongSelf.player.emailMe
                                                forKey:@"emailMe"];
        [[NSUserDefaults standardUserDefaults] setBool:strongSelf.player.personalizeAds
                                                forKey:PERSONALIZEADSKEY];
        livePlayers = [userInfo[@"livePlayers"] stringValue];
        if (@available(iOS 26.0, *)) {
            if ([userInfo[@"livePlayers"] intValue] > 0) {
                [inviteButton setBadge:[UIBarButtonItemBadge
                                           badgeWithString:livePlayers]];
                [inviteButton.badge
                    setBackgroundColor:[UIColor colorWithRed:(8.0 / 255)
                                                       green:(52.0 / 255)
                                                        blue:(29.0 / 255)
                                                       alpha:1.0]];
            } else {
                [inviteButton setBadge:nil];
            }
        } else {
            inviteButton.badgeValue = livePlayers;
            [inviteButton setBadgeBGColor:[UIColor colorWithRed:(8.0 / 255)
                                                          green:(52.0 / 255)
                                                           blue:(29.0 / 255)
                                                          alpha:1.0]];
        }
        onlineFollowing = [userInfo[@"onlineFollowing"] stringValue];
        if (@available(iOS 26.0, *)) {
            if ([userInfo[@"onlineFollowing"] intValue] > 0) {
                UIBarButtonItemBadge *badge =
                    [UIBarButtonItemBadge badgeWithString:onlineFollowing];
                badge.backgroundColor = [UIColor colorWithRed:(8.0 / 255)
                                                        green:(52.0 / 255)
                                                         blue:(29.0 / 255)
                                                        alpha:1.0];
                [moreButton setBadge:badge];
            } else {
                moreButton.badge = nil;
            }
        } else {
            moreButton.badgeValue = onlineFollowing;
            [moreButton setBadgeBGColor:[UIColor colorWithRed:(8.0 / 255)
                                                        green:(52.0 / 255)
                                                         blue:(29.0 / 255)
                                                        alpha:1.0]];
        }
        if ([strongSelf.player subscriber]) {
            [[NSUserDefaults standardUserDefaults]
                setBool:NO
                 forKey:@"shouldSendReceipt"];
        }

        int tbHills = 0;
        //        NSLog(  @"kitty hills: %@", jsonResponse[@"kingOfTheHill"]);
        sectionItems = [[NSMutableArray alloc] init];
        for (NSDictionary *hill_dict in jsonResponse[@"kingOfTheHill"]) {
            KingOfTheHill *hill = [[KingOfTheHill alloc] init];
            [hill setGameId:[hill_dict[@"gameId"] intValue]];
            [hill setNumPlayers:hill_dict[@"numPlayers"]];
            [hill setMember:[hill_dict[@"amIMember"] boolValue]];
            [hill setKing:[hill_dict[@"iAmKing"] boolValue]];
            [hill setCurrentKing:hill_dict[@"kingName"]];
            [hill setCanSendOpen:[hill_dict[@"canChallenge"] boolValue]];

            int gameInt = hill.gameId;
            if (gameInt > 50) {
                gameInt -= 50;
                tbHills += 1;
            }
            NSString *gameStr = [PenteGame getGameName: gameInt];
            if (hill.gameId > 50) {
                [hill setGame:[@"tb-" stringByAppendingString:gameStr]];
            } else if (hill.gameId % 2 == 0) {
                [hill setGame:[@"Speed " stringByAppendingString:gameStr]];
            } else {
                [hill setGame:gameStr];
            }
            [sectionItems addObject:hill];
        }
        [strongSelf.player setTbHills:tbHills];

        int totalHills =
            ([[NSUserDefaults standardUserDefaults] boolForKey:@"showOnlyTB"]
                 ? strongSelf.player.tbHills
                 : (int)[sectionItems count]);
        long kothRows = 0;
        if (strongSelf.tableView) {
            kothRows = [strongSelf.tableView numberOfRowsInSection:KOTHSECTION];
        }
        if (totalHills != kothRows) {
            if (!kothCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for (int i = 0; i < kothRows; ++i) {
                    [indexSet
                        addObject:[NSIndexPath indexPathForRow:i
                                                     inSection:KOTHSECTION]];
                }
                [strongSelf.player setHills:[[NSMutableArray alloc] init]];
                [strongSelf.tableView
                    deleteRowsAtIndexPaths:indexSet
                          withRowAnimation:UITableViewRowAnimationFade];
            }
            [strongSelf.player setHills:sectionItems];
            if (!kothCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for (int i = 0; i < totalHills; ++i) {
                    [indexSet
                        addObject:[NSIndexPath indexPathForRow:i
                                                     inSection:KOTHSECTION]];
                }
                [strongSelf.tableView
                    insertRowsAtIndexPaths:indexSet
                          withRowAnimation:UITableViewRowAnimationFade];
            }
        } else {
            [strongSelf.player setHills:sectionItems];
        }

        int totalTB = 0;
        for (KingOfTheHill *hill in sectionItems) {
            if (hill.gameId > 50) {
                totalTB++;
            }
        }
        if (totalTB != tbHills) {
            if (tbHills > 0) {
                if (!kothCollapsed) {
                    indexSet = [[NSMutableArray alloc] init];
                    for (int i = 0; i < tbHills; ++i) {
                        [indexSet addObject:[NSIndexPath
                                                indexPathForRow:i
                                                      inSection:KOTHSECTION]];
                    }
                    [strongSelf.tableView
                        insertRowsAtIndexPaths:indexSet
                              withRowAnimation:UITableViewRowAnimationFade];
                }
            } else {
                if (kothRows > 0) {
                    indexSet = [[NSMutableArray alloc] init];
                    for (int i = 0; i < kothRows; ++i) {
                        [indexSet addObject:[NSIndexPath
                                                indexPathForRow:i
                                                      inSection:KOTHSECTION]];
                    }
                    [strongSelf.tableView
                        deleteRowsAtIndexPaths:indexSet
                              withRowAnimation:UITableViewRowAnimationFade];
                }
            }
        }

        int tbRatings = 0;
        NSArray *ratingStats = jsonResponse[@"ratingStats"];
        [[strongSelf.player ratingStats] removeAllObjects];
        for (NSDictionary *ratingStat_dict in ratingStats) {
            RatingStat *ratingStat = [[RatingStat alloc] init];
            //                [ratingStat setGame:
            //                ratingStat_dict[@"gameName"]];
            [ratingStat setRating:[ratingStat_dict[@"rating"] stringValue]];
            [ratingStat setTotalGames:[ratingStat_dict[@"totalGames"] stringValue]];
            [ratingStat setLastPlayed:[ratingStat_dict[@"lastGameDate"] stringValue]];
            [ratingStat setCrown:[ratingStat_dict[@"tourneyWinner"] intValue]];
            [ratingStat setGameId:[ratingStat_dict[@"gameId"] intValue]];

            [[strongSelf.player ratingStats] addObject:ratingStat];
            int gameInt = ratingStat.gameId;
            if (gameInt > 50) {
                gameInt -= 50;
                tbRatings += 1;
            }
            NSString *gameStr = [PenteGame getGameName:gameInt];
            if (ratingStat.gameId > 50) {
                [ratingStat setGame:[@"tb-" stringByAppendingString:gameStr]];
            } else if (ratingStat.gameId % 2 == 0) {
                [ratingStat
                    setGame:[@"Speed " stringByAppendingString:gameStr]];
            } else {
                [ratingStat setGame:gameStr];
            }
        }
        [strongSelf.player setTbRatings:tbRatings];

        sectionItems = [[NSMutableArray alloc] init];

        for (NSDictionary
                 *invitation_dict in jsonResponse[@"invitationsSent"]) {
            Game *game = [[Game alloc] init];
            [game setGameID:[invitation_dict[@"gid"] stringValue]];
            [game setGameType:invitation_dict[@"gameName"]];
            [game setOpponentName:invitation_dict[@"opponentName"]];
            [game setOpponentRating:[invitation_dict[@"opponentRating"]
                                        stringValue]];
            [game setMyColor:invitation_dict[@"color"]];
            [game setRemainingTime:
                      [NSString
                          stringWithFormat:@"%@ days per move",
                                           invitation_dict[@"daysPerMove"]]];
            [game setRatedNot:invitation_dict[@"rated"]];
            [game setNameColor:UIColorFromRGB([invitation_dict[@"opponentColor"]
                                   intValue])];
            [game setCrown:[invitation_dict[@"opponentTourneyWinner"] intValue]];
            if (wantsToSeeAvatars && ![game.nameColor isEqual:blackColor]) {
                [strongSelf.player addUser:[game opponentName]];
            }
            [sectionItems addObject:game];
        }
        [strongSelf updateSection:SENTINVITATIONSSECTION
                   newItems:sectionItems
                   oldItems:[strongSelf.player sentInvitations]
                  collapsed:sentInvitationsCollapsed
                     setter:^(NSMutableArray *items) { [strongSelf.player setSentInvitations:items]; }];

        sectionItems = [[NSMutableArray alloc] init];
        for (NSDictionary
                 *invitation_dict in jsonResponse[@"invitationsReceived"]) {
            Game *game = [[Game alloc] init];
            [game setGameID:[invitation_dict[@"setId"] stringValue]];
            [game setGameType:invitation_dict[@"gameName"]];
            [game setOpponentName:invitation_dict[@"opponentName"]];
            [game setOpponentRating:[invitation_dict[@"opponentRating"]
                                        stringValue]];
            [game setMyColor:invitation_dict[@"color"]];
            [game setRemainingTime:
                      [NSString
                          stringWithFormat:@"%@ days per move",
                                           invitation_dict[@"daysPerMove"]]];
            [game setRatedNot:invitation_dict[@"rated"]];
            [game setNameColor:UIColorFromRGB([invitation_dict[@"opponentColor"]
                                   intValue])];
            [game setCrown:[invitation_dict[@"opponentTourneyWinner"] intValue]];
            if (wantsToSeeAvatars && ![game.nameColor isEqual:blackColor]) {
                [strongSelf.player addUser:[game opponentName]];
            }
            [sectionItems addObject:game];
        }
        [strongSelf updateSection:INVITATIONSSECTION
                   newItems:sectionItems
                   oldItems:[strongSelf.player invitations]
                  collapsed:invitationsReceivedCollapsed
                     setter:^(NSMutableArray *items) { [strongSelf.player setInvitations:items]; }];

        //        [self.tableView reloadData];

        //    [self.tableView reloadData];
        //    [self performSelector:@selector(scrollViewDidScroll:) withObject:
        //    self.tableView afterDelay:.63f]; [self
        //    performSelectorOnMainThread:@selector(scrollViewDidScroll:)
        //    withObject: self.tableView waitUntilDone:YES];

        //    [self.tableView beginUpdates];
        //    [self.tableView endUpdates];

        //    [CATransaction commit];

        //    [self.tableView reloadData];
        //    [self performSelector:@selector(scrollViewDidScroll:) withObject:
        //    self.tableView afterDelay:.63f]; [self
        //    performSelectorOnMainThread:@selector(scrollViewDidScroll:)
        //    withObject: self.tableView waitUntilDone:YES];
        sectionItems = [[NSMutableArray alloc] init];

        for (NSDictionary *game_dict in jsonResponse[@"activeGamesMyTurn"]) {
            Game *game = [[Game alloc] init];
            [game setGameID:[game_dict[@"gid"] stringValue]];
            [game setGameType:game_dict[@"gameName"]];
            [game setOpponentName:game_dict[@"opponentName"]];
            [game setOpponentRating:[game_dict[@"opponentRating"] stringValue]];
            [game setMyColor:game_dict[@"color"]];
            [game setRemainingTime:game_dict[@"timeLeft"]];
            [game setRatedNot:game_dict[@"rated"]];
            [game setNameColor:UIColorFromRGB(
                                   [game_dict[@"opponentColor"] intValue])];
            [game setCrown:[game_dict[@"opponentTourneyWinner"] intValue]];
            if (wantsToSeeAvatars && ![game.nameColor isEqual:blackColor]) {
                [strongSelf.player addUser:[game opponentName]];
            }
            [sectionItems addObject:game];
        }

        [strongSelf updateSection:ACTIVEGAMESSECTION
                   newItems:sectionItems
                   oldItems:[strongSelf.player activeGames]
                  collapsed:activeGamesCollapsed
                     setter:^(NSMutableArray *items) { [strongSelf.player setActiveGames:items]; }];

        sectionItems = [[NSMutableArray alloc] init];
        for (NSDictionary
                 *game_dict in jsonResponse[@"activeGamesOpponentTurn"]) {
            Game *game = [[Game alloc] init];
            [game setGameID:[game_dict[@"gid"] stringValue]];
            [game setGameType:game_dict[@"gameName"]];
            [game setOpponentName:game_dict[@"opponentName"]];
            [game setOpponentRating:[game_dict[@"opponentRating"] stringValue]];
            [game setMyColor:game_dict[@"color"]];
            [game setRemainingTime:game_dict[@"timeLeft"]];
            [game setRatedNot:game_dict[@"rated"]];
            [game setNameColor:UIColorFromRGB(
                                   [game_dict[@"opponentColor"] intValue])];
            [game setCrown:[game_dict[@"opponentTourneyWinner"] intValue]];
            if (wantsToSeeAvatars && ![game.nameColor isEqual:blackColor]) {
                [strongSelf.player addUser:[game opponentName]];
            }
            [sectionItems addObject:game];
        }

        [strongSelf updateSection:NONACTIVEGAMESSECTION
                   newItems:sectionItems
                   oldItems:[strongSelf.player nonActiveGames]
                  collapsed:nonActiveGamesCollapsed
                     setter:^(NSMutableArray *items) { [strongSelf.player setNonActiveGames:items]; }];
        //        [self.tableView reloadData];
        [strongSelf.pullToReloadHeaderView
            setStatusString:@"Loading Open Invitations..."
                   animated:YES];
        [strongSelf.pullToReloadHeaderView layoutSubviews];

        //    [self.tableView beginUpdates];
        //    [self.tableView endUpdates];

        //    [CATransaction commit];

        //    [self.tableView reloadData];
        //    [self performSelector:@selector(scrollViewDidScroll:) withObject:
        //    self.tableView afterDelay:.63f]; [self
        //    performSelectorOnMainThread:@selector(scrollViewDidScroll:)
        //    withObject: self.tableView waitUntilDone:YES];

        // load the public games

        sectionItems = [[NSMutableArray alloc] init];
        for (NSDictionary *game_dict in jsonResponse[@"openInvitationGames"]) {
            Game *game = [[Game alloc] init];
            [game setGameID:[game_dict[@"setId"] stringValue]];
            [game setGameType:game_dict[@"gameName"]];
            [game setOpponentName:game_dict[@"inviterName"]];
            [game setOpponentRating:[game_dict[@"inviterRating"] stringValue]];
            [game setMyColor:game_dict[@"color"]];
            [game setRemainingTime:
                      [NSString stringWithFormat:@"%@ days per move",
                                                 game_dict[@"daysPerMove"]]];
            [game setRatedNot:game_dict[@"rated"]];
            [game setNameColor:UIColorFromRGB(
                                   [game_dict[@"inviterColor"] intValue])];
            [game setCrown:[game_dict[@"inviterTourneyWinner"] intValue]];
            if (wantsToSeeAvatars && ![game.nameColor isEqual:blackColor]) {
                [strongSelf.player addUser:[game opponentName]];
            }
            [sectionItems addObject:game];
        }

        [strongSelf updateSection:PUBLICINVITATIONSSECTION
                   newItems:sectionItems
                   oldItems:[strongSelf.player publicInvitations]
                  collapsed:publicInvitationsCollapsed
                     setter:^(NSMutableArray *items) { [strongSelf.player setPublicInvitations:items]; }];
        //        [self.tableView reloadData];

        [strongSelf performSelector:@selector(scrollViewDidScroll:)
                   withObject:strongSelf.tableView
                   afterDelay:.33f];
        [strongSelf.pullToReloadHeaderView setStatusString:@"Loading Messages..."
                                            animated:YES];
        [strongSelf.pullToReloadHeaderView layoutSubviews];

        //    [CATransaction begin];
        //    [CATransaction setCompletionBlock:^{
        //        //    [self.tableView
        //        performSelectorOnMainThread:@selector(reloadData)
        //        withObject:nil waitUntilDone:NO]; [self.tableView reloadData];
        //        //        [self
        //        performSelectorOnMainThread:@selector(scrollViewDidScroll:)
        //        withObject: self.tableView waitUntilDone:YES]; [self
        //        performSelector:@selector(scrollViewDidScroll:) withObject:
        //        self.tableView afterDelay:.65f];
        //    }];

        sectionItems = [[NSMutableArray alloc] init];
        int unreadMsgs = 0, readMsgs = 0;
        for (NSDictionary *message_dict in jsonResponse[@"messages"]) {
            Message *message = [[Message alloc] init];
            [message setMessageID:message_dict[@"mid"]];
            [message setUnread:[message_dict[@"read"] intValue] == 0 ? @"unread"
                                                                     : @"read"];
            [message unread] ? readMsgs++ : unreadMsgs++;
            [message setSubject:message_dict[@"subject"]];
            [message setAuthor:message_dict[@"from"]];
            [message setTimeStamp:message_dict[@"date"]];
            [message setNameColor:UIColorFromRGB(
                                      [message_dict[@"fromColor"] intValue])];
            [message setCrown:[message_dict[@"fromTourneyWinner"] intValue]];
            if (wantsToSeeAvatars && ![message.nameColor isEqual:blackColor]) {
                [strongSelf.player addUser:[message author]];
            }
            [sectionItems addObject:message];
        }
        [strongSelf updateSection:MESSAGESSECTION
                   newItems:sectionItems
                   oldItems:[strongSelf.player messages]
                  collapsed:messagesCollapsed
                     setter:^(NSMutableArray *items) { [strongSelf.player setMessages:items]; }];

        sectionItems = [[NSMutableArray alloc] init];
        for (NSDictionary *tournament_dict in jsonResponse[@"tournaments"]) {
            Tournament *tournament = [[Tournament alloc] init];
            [tournament setName:tournament_dict[@"name"]];
            [tournament
                setTournamentID:[tournament_dict[@"eventId"] stringValue]];
            [tournament setRound:[tournament_dict[@"numRounds"] stringValue]];
            [tournament setGame:tournament_dict[@"gameName"]];
            [tournament
                setTournamentState:[tournament_dict[@"status"] stringValue]];
            [tournament setDate:tournament_dict[@"date"]];
            [sectionItems addObject:tournament];
        }

        [strongSelf updateSection:TOURNAMENTSSECTION
                   newItems:sectionItems
                   oldItems:[strongSelf.player tournaments]
                  collapsed:tournamentsCollapsed
                     setter:^(NSMutableArray *items) { [strongSelf.player setTournaments:items]; }];

        NSMutableDictionary<NSString *, NSString *> *playersDict =
            [[NSMutableDictionary alloc] init];
        for (NSString *name in jsonResponse[@"onlinePlayers"]) {
            [playersDict setObject:@"" forKey:name];
        }
        [strongSelf.player setOnlinePlayers:playersDict];

        [strongSelf.tableView endUpdates];
        [CATransaction commit];
        [strongSelf.tableView setUserInteractionEnabled:YES];
    }];
}

- (void)messagesParse {
    //    [self performSelector:@selector(scrollViewDidScroll:) withObject:
    //    self.tableView afterDelay:0.05];
    self.tableView.layer.borderWidth = 1.5;
    [NSThread detachNewThreadSelector:@selector(parseMessages)
                             toTarget:self
                           withObject:nil];
}

- (void)parseMessages {

    PenteNavigationViewController *navController =
        (PenteNavigationViewController *)self.navigationController;
    if (navController.receivedNotification) {
        //        NSLog(@"kitty  %@", navController.receivedNotification);

        Game *notificationGame;
        if ([[navController receivedNotification] objectForKey:@"gameID"]) {
            Game *notificationGame;
            for (notificationGame in [self.player activeGames]) {
                if ([[notificationGame gameID]
                        isEqualToString:[[navController receivedNotification]
                                            objectForKey:@"gameID"]]) {
                    break;
                }
            }
            if ([[notificationGame gameID]
                    isEqualToString:[[navController receivedNotification]
                                        objectForKey:@"gameID"]]) {
                [self performSegueWithIdentifier:@"gameTap" sender:self];
                [boardController setGame:notificationGame];
                [boardController setActiveGame:YES];
                [boardController replayGame];
                [[boardController boardTapRecognizer] setEnabled:YES];
            }
        } else if ([[navController receivedNotification]
                       objectForKey:@"setID"]) {
            long idx = 0;
            for (notificationGame in [self.player invitations]) {
                if ([[notificationGame gameID]
                        isEqualToString:[[navController receivedNotification]
                                            objectForKey:@"setID"]]) {
                    break;
                }
                idx++;
            }
            if (idx < [[self.player invitations] count]) {
                if (invitationsReceivedCollapsed) {
                    invitationsReceivedCollapsed =
                        !invitationsReceivedCollapsed;
                    [[NSUserDefaults standardUserDefaults]
                        setBool:invitationsReceivedCollapsed
                         forKey:@"invitationsReceivedCollapsed"];
                    NSMutableArray *indexSet = [[NSMutableArray alloc] init];
                    for (int i = 0; i < [[self.player invitations] count];
                         ++i) {
                        [indexSet
                            addObject:[NSIndexPath
                                          indexPathForRow:i
                                                inSection:INVITATIONSSECTION]];
                    }
                    [self.tableView
                        insertRowsAtIndexPaths:indexSet
                              withRowAnimation:UITableViewRowAnimationFade];
                    [self.tableView performSelector:@selector(reloadData)
                                         withObject:nil
                                         afterDelay:0.275];
                    [self performSelector:@selector(scrollViewDidScroll:)
                               withObject:self.tableView
                               afterDelay:0.315];

                    [[self.tableView headerViewForSection:INVITATIONSSECTION]
                        setNeedsDisplay];
                }
                if (selectedPublicInvitationIndexPath) {
                    [self removeButtonsFromPublicInvitationsCell];
                    [self.tableView beginUpdates];
                    selectedPublicInvitationIndexPath = nil;
                    selectedPublicInvitationCell = nil;
                    [self.tableView endUpdates];
                }
                GameTableViewCell *cell = (GameTableViewCell *)[self.tableView
                    cellForRowAtIndexPath:
                        [NSIndexPath indexPathForRow:idx
                                           inSection:INVITATIONSSECTION]];
                if (selectedInvitationIndexPath) {
                    if ((selectedInvitationIndexPath.section !=
                         INVITATIONSSECTION) ||
                        (selectedInvitationIndexPath.row != idx)) {
                        [self removeButtonsFromCell];
                        GameTableViewCell *tmpCell = (GameTableViewCell
                                                          *)[self.tableView
                            cellForRowAtIndexPath:selectedInvitationIndexPath];
                        [tmpCell
                            setAccessoryType:
                                UITableViewCellAccessoryDisclosureIndicator];

                        [cell setAccessoryType:UITableViewCellAccessoryNone];
                        [cell layoutSubviews];
                        [self.tableView beginUpdates];
                        selectedInvitationIndexPath =
                            [NSIndexPath indexPathForRow:idx
                                               inSection:INVITATIONSSECTION];
                        [self.tableView endUpdates];

                        [self addButtonsToCell:cell];
                        selectedInvitationCell = cell;
                    }
                } else {
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    [self.tableView beginUpdates];
                    selectedInvitationIndexPath =
                        [NSIndexPath indexPathForRow:idx
                                           inSection:INVITATIONSSECTION];
                    [self.tableView endUpdates];

                    [self addButtonsToCell:cell];
                    selectedInvitationCell = cell;
                }
                selectedGame = [[self.player invitations] objectAtIndex:idx];
            }
        } else if ([[navController receivedNotification]
                       objectForKey:@"msgID"]) {

            Message *notificationMessage;
            long idx = 0;
            for (notificationMessage in [self.player messages]) {
                if ([[notificationMessage messageID]
                        isEqualToString:[[navController receivedNotification]
                                            objectForKey:@"msgID"]]) {
                    break;
                }
                idx++;
            }
            if (idx < [[self.player messages] count]) {
                if ([[notificationMessage messageID]
                        isEqualToString:[[navController receivedNotification]
                                            objectForKey:@"msgID"]]) {
                    if (selectedInvitationIndexPath) {
                        [self removeButtonsFromCell];
                        [self.tableView beginUpdates];
                        selectedInvitationIndexPath = nil;
                        selectedInvitationCell = nil;
                        [self.tableView endUpdates];
                    }
                    if (selectedPublicInvitationIndexPath) {
                        [self removeButtonsFromPublicInvitationsCell];
                        [self.tableView beginUpdates];
                        selectedPublicInvitationIndexPath = nil;
                        selectedPublicInvitationCell = nil;
                        [self.tableView endUpdates];
                    }
                    PenteNavigationViewController *navControllor =
                        (PenteNavigationViewController *)
                            self.navigationController;
                    [navControllor setDeletedMessageRow:(int)idx];

                    [self performSegueWithIdentifier:@"messagesTap"
                                              sender:self];

                    [messagesViewController
                        setMessageID:[[[self.player messages] objectAtIndex:idx]
                                         messageID]];
                    [messagesViewController
                        setAuthor:[[[self.player messages] objectAtIndex:idx]
                                      author]];
                    [messagesViewController
                        setSubject:[[[self.player messages] objectAtIndex:idx]
                                       subject]];
                    if ([[[[self.player messages] objectAtIndex:idx] unread]
                            isEqualToString:@"unread"]) {
                        [[[self.player messages] objectAtIndex:idx]
                            setUnread:@"read"];
                        //                            [self.tableView
                        //                            reloadData];
                    }
                }
            }
        }
    } else {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (navController.loggedIn && [defaults boolForKey:GDPRTERMSKEY]) {
            if ([[self.player activeGames] count] +
                    [[self.player nonActiveGames] count] +
                    [[self.player sentInvitations] count] ==
                0) {
                if (!alreadyAskedAboutInvitations) {
                    if (![defaults boolForKey:@"doNotRemindOpenInvitation"]) {
                        UIAlertView *alert = [[UIAlertView alloc]
                                initWithTitle:NSLocalizedString(
                                                  @"Nothing to see here", nil)
                                      message:NSLocalizedString(
                                                  @"You have no ongoing games, "
                                                  @"shall we post "
                                                  @"an open invitation and get "
                                                  @"you started?",
                                                  nil)
                                     delegate:self
                            cancelButtonTitle:NSLocalizedString(
                                                  @"Remind me next time.", nil)
                            otherButtonTitles:NSLocalizedString(@"Sure!", nil),
                                              NSLocalizedString(
                                                  @"Do not remind me again.",
                                                  nil),
                                              nil];
                        [alert setTag:0];
                        [alert show];
                    }
                }
            }
        }
    }
    [navController setReceivedNotification:nil];
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    long badgeNr = 0;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"badgeMyTurn"]) {
        badgeNr += [[self.player activeGames] count];
    }
    if (![defaults boolForKey:@"badgeInvitations"]) {
        badgeNr += [[self.player invitations] count];
    }
    if (![defaults boolForKey:@"badgeMessages"]) {
        for (Message *message in [self.player messages]) {
            if ([message.unread isEqualToString:@"unread"]) {
                badgeNr++;
            }
        }
    }
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badgeNr];
    self.tableView.layer.borderWidth = 0.0;
    [self.tableView setUserInteractionEnabled:YES];

    if (navController.loggedIn) {
        [self requestReview];
    }
}

- (void)requestReview {
    if (@available(iOS 10.3, *)) {
        NSDate *installationDate = [[NSUserDefaults standardUserDefaults]
            objectForKey:@"installationDate"];
        if (installationDate) {
            double daysPassed = 0;
            daysPassed = [installationDate timeIntervalSinceNow] / -86400.0;
            if (daysPassed < 15) {
                return;
            }
            NSDate *lastRated = [[NSUserDefaults standardUserDefaults]
                objectForKey:@"lastRatedApp"];
            daysPassed = 0;
            if (lastRated) {
                daysPassed = [lastRated timeIntervalSinceNow] / -86400.0;
            }
            if (!lastRated || daysPassed > 120) {
                [SKStoreReviewController requestReview];
                [[NSUserDefaults standardUserDefaults]
                    setObject:[NSDate date]
                       forKey:@"lastRatedApp"];
            }
        }
    }
}

- (void)showActions {
    NSMutableArray *buttonsArray = [[NSMutableArray alloc] init];
    CGRect frame;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    //    button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [button setImage:[UIImage imageNamed:@"newmessage.png"]
            forState:UIControlStateNormal];
    [button setTitle:NSLocalizedString(@" new message", nil)
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(toComposer)
        forControlEvents:UIControlEventTouchUpInside];
    //    [button setFrame:frame];
    [button sizeToFit];
    frame = button.frame;
    [buttonsArray addObject:button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"showstats.png"]
            forState:UIControlStateNormal];
    [button setTitle:NSLocalizedString(@" my ratings", nil)
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(showStats)
        forControlEvents:UIControlEventTouchUpInside];
    //    [button setFrame:frame];
    [button sizeToFit];
    if (button.frame.size.width > frame.size.width) {
        frame = button.frame;
    }
    [buttonsArray addObject:button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"onlineUsers.png"]
            forState:UIControlStateNormal];
    [button setTitle:NSLocalizedString(@" online players", nil)
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(showOnlinePlayers)
        forControlEvents:UIControlEventTouchUpInside];
    button.shouldHideBadgeAtZero = YES;
    button.badgeValue = onlineFollowing;
    [button setBadgeBGColor:[UIColor colorWithRed:(8.0 / 255)
                                            green:(52.0 / 255)
                                             blue:(29.0 / 255)
                                            alpha:1.0]];
    [button sizeToFit];
    if (button.frame.size.width > frame.size.width) {
        frame = button.frame;
    }
    [buttonsArray addObject:button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"footprint"]
            forState:UIControlStateNormal];
    [button setTitle:NSLocalizedString(@" social", nil)
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(toSocial)
        forControlEvents:UIControlEventTouchUpInside];
    //    [button setFrame:frame];
    [button sizeToFit];
    if (button.frame.size.width > frame.size.width) {
        frame = button.frame;
    }
    [buttonsArray addObject:button];

    actionPopoverView = [PopoverView
        showPopoverAtPoint:CGPointMake(self.view.bounds.size.width - 20,
                                       self.tableView.contentOffset.y)
                    inView:self.view
             withViewArray:buttonsArray
                  delegate:self];
}

- (void)toSocial {
    [actionPopoverView dismiss];
    SocialViewController *vc =
        [[SocialViewController alloc] initWithPlayer:player];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)toComposer {
    [actionPopoverView dismiss];
    [self performSegueWithIdentifier:@"messagesTap" sender:self];
    //    [self performSegueWithIdentifier:@"inviteAItap" sender:self];
}

- (void)showStats {
    [actionPopoverView dismiss];

    CGFloat maxHeight = floor(self.view.frame.size.height * 4 / (5 * 44)) * 44;

    RatingStatsView *ratingView = [[RatingStatsView alloc]
        initWithFrame:CGRectMake(0, 0, self.view.frame.size.width * 9 / 10,
                                 MIN(44 * [[self.player ratingStats] count],
                                     maxHeight))];
    ratingView.layer.cornerRadius = 5.0f;
    ratingView.layer.borderWidth = 1.0f;
    [ratingView setDelegate:ratingView];
    [ratingView setDataSource:ratingView];
    [ratingView setRatingStats:[self.player ratingStats]];
    //    [ratingView setUserInteractionEnabled:NO];
    [ratingView setVc:self];

    actionPopoverView = [PopoverView
        showPopoverAtPoint:CGPointMake(self.view.bounds.size.width - 20,
                                       self.tableView.contentOffset.y)
                    inView:self.view
                 withTitle:@"rating stats"
           withContentView:ratingView
                  delegate:self];
    [actionPopoverView layoutSubviews];
    //    [ratingView setFrame: frame];
}

- (void)showOnlinePlayers {
    [actionPopoverView dismiss];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url =
        [NSString stringWithFormat:@"https://www.pente.org/gameServer/"
                                   @"mobile/whosonlineandlive.jsp"];
    if (development) {
        url =
            [NSString stringWithFormat:@"https://localhost/gameServer/"
                                       @"mobile/whosonlineandlive.jsp"];
    }

    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *dashboardString =
            [[NSString alloc] initWithData:responseData
                                  encoding:NSUTF8StringEncoding];

        if (error) {
            UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:NSLocalizedString(@"Error", nil)
                          message:[NSString stringWithFormat:
                                                NSLocalizedString(
                                                    @"Reason: %@", nil),
                                                error.localizedDescription]
                         delegate:nil
                cancelButtonTitle:NSLocalizedString(@"OK", nil)
                otherButtonTitles:nil];
            [alert show];
            [strongSelf.progressView stopAnimating];
            [strongSelf.progressView removeFromSuperview];
            return;
        }
        [strongSelf.progressView stopAnimating];
        BOOL wantsToSeeAvatars = [[NSUserDefaults standardUserDefaults]
            boolForKey:@"wantToSeeAvatars"];
        NSMutableDictionary<NSString *, NSString *> *playersDict =
            [[NSMutableDictionary alloc] init];
        NSMutableArray<Room *> *rooms = [[NSMutableArray alloc] init];
        for (NSString *line in
             [dashboardString componentsSeparatedByString:@"\n"]) {
            NSArray *splitRoomPlayers =
                [line componentsSeparatedByString:@":"];
            if ([splitRoomPlayers count] > 1) {
                Room *room = [[Room alloc] init];
                [room setName:[splitRoomPlayers objectAtIndex:0]];
                NSArray *splitPlayers = [[splitRoomPlayers objectAtIndex:1]
                    componentsSeparatedByString:@";"];
                for (NSString *playerString in splitPlayers) {
                    NSArray *splitLine =
                        [playerString componentsSeparatedByString:@","];
                    if ([splitLine count] > 3) {
                        Player *playr = [[Player alloc] init];
                        [playr setName:[splitLine objectAtIndex:0]];
                        [playr setRating:[splitLine objectAtIndex:1]];
                        [playr setColor:[[splitLine objectAtIndex:2]
                                            intValue]];
                        [playr setCrown:[[splitLine objectAtIndex:3]
                                                intValue]];
                            [playr
                                setNumberOfGames:[splitLine objectAtIndex:4]];
                            [room addPlayer:playr];
                        [playersDict setObject:@"" forKey:playr.name];
                        if (wantsToSeeAvatars && (playr.color != 0)) {
                            [strongSelf.player addUser:playr.name];
                        }
                    }
                }
                [rooms addObject:room];
            }
        }
        [strongSelf.player setOnlinePlayers:playersDict];

        WhosOnlineView *playersView = [[WhosOnlineView alloc]
            initWithFrame:CGRectMake(0, 0, 285,
                                     floor(strongSelf.view.frame.size.height *
                                           2 / (3 * 44)) *
                                         44)];
        [playersView setPlayer:strongSelf.player];
        playersView.layer.cornerRadius = 5.0f;
        playersView.layer.borderWidth = 1.0f;
        [playersView setDelegate:playersView];
        [playersView setDataSource:playersView];
        [playersView setRooms:rooms];
        //            [self.playersView setPlayers:players];
        [playersView setVc:strongSelf];
        strongSelf.actionPopoverView = [PopoverView
            showPopoverAtPoint:CGPointMake(
                                   strongSelf.view.bounds.size.width - 20,
                                   strongSelf.tableView.contentOffset.y)
                        inView:strongSelf.view
                     withTitle:NSLocalizedString(@"who's online", nil)
               withContentView:playersView
                      delegate:strongSelf];
        [strongSelf.actionPopoverView layoutSubviews];
        [playersView flashScrollIndicators];
    }];

    //    [ratingView setFrame: frame];
}

- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    [self.progressView stopAnimating];
    [self.progressView removeFromSuperview];
}

- (void)showInvitationActions {
    NSMutableArray *buttonsArray = [[NSMutableArray alloc] init];
    CGRect frame = CGRectMake(0, 0, 45, 45);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setTitle:NSLocalizedString(@" server AI", nil)
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"server.png"]
            forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(toAIInvitations)
        forControlEvents:UIControlEventTouchUpInside];
    //    [button setFrame: frame];
    [button sizeToFit];
    frame = button.frame;
    [buttonsArray addObject:button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setTitle:NSLocalizedString(@" onboard AI", nil)
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"computer.png"]
            forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(toMMAI)
        forControlEvents:UIControlEventTouchUpInside];
    [button sizeToFit];
    if (button.frame.size.width > frame.size.width) {
        frame = button.frame;
    }
    [buttonsArray addObject:button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setTitle:NSLocalizedString(@" humans", nil)
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"person.png"]
            forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(toRegularInvitations)
        forControlEvents:UIControlEventTouchUpInside];
    [button sizeToFit];
    if (button.frame.size.width > frame.size.width) {
        frame = button.frame;
    }
    [buttonsArray addObject:button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:NSLocalizedString(@" database", nil)
            forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"database.png"]
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor];
    //    if (player && ![self.player subscriber]) {
    //        [button setAlpha:0.5f];
    //    }
    //    [button setImage:[UIImage imageNamed:@"person.png"]
    //    forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(toDatabase)
        forControlEvents:UIControlEventTouchUpInside];
    [button sizeToFit];
    if (button.frame.size.width > frame.size.width) {
        frame = button.frame;
    }
    [buttonsArray addObject:button];

    button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setTitle:NSLocalizedString(@" Live Games", nil)
            forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:@"lightning"]
            forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor clearColor];
    //    if (player && ![self.player subscriber]) {
    //        [button setAlpha:0.5f];
    //    }
    //    [button setImage:[UIImage imageNamed:@"person.png"]
    //    forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(toLive)
        forControlEvents:UIControlEventTouchUpInside];
    button.shouldHideBadgeAtZero = YES;
    button.badgeValue = livePlayers;
    [button sizeToFit];
    if (button.frame.size.width > frame.size.width) {
        frame = button.frame;
    }
    [buttonsArray addObject:button];
    for (UIButton *bttn in buttonsArray) {
        bttn.contentHorizontalAlignment =
            UIControlContentHorizontalAlignmentLeft;
        bttn.frame = frame;
    }

    actionPopoverView = [PopoverView
        showPopoverAtPoint:CGPointMake(self.view.bounds.size.width - 80,
                                       self.tableView.contentOffset.y)
                    inView:self.view
             withViewArray:buttonsArray
                  delegate:self];
    //    actionPopoverView = [PopoverView showPopoverAtPoint:
    //    CGPointMake(100.0f, 100.0f) inView:self.view withViewArray:
    //    buttonsArray delegate:self]; actionPopoverView = [PopoverView
    //    showPopoverAtPoint: CGPointMake(100.0f, 100.0f) inView:self.view
    //    withViewArray: buttonsArray delegate:self]; actionPopoverView=
    //    [PopoverView showPopoverAtPoint:CGPointMake(100.0f, 100.0f)
    //    inView:self.tableView withTitle:@"test" withContentView:button
    //    delegate:self];
}

- (void)toLive {
    [actionPopoverView dismiss];
    LobbyViewController *vc = [[LobbyViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}
- (void)toRegularInvitations {
    [actionPopoverView dismiss];
    [self performSegueWithIdentifier:@"addInvitationsTap" sender:self];
    //    [self performSegueWithIdentifier:@"inviteAItap" sender:self];
}
- (void)toInvitationsWithPlayer:(NSString *)playerName {
    [actionPopoverView dismiss];
    if (![playerName isEqualToString:username]) {
        PenteNavigationViewController *navController =
            (PenteNavigationViewController *)self.navigationController;
        [navController setChallengedUser:playerName];
        [self performSegueWithIdentifier:@"addInvitationsTap" sender:self];
    } else {
        PenteWebViewController *webVC = [[PenteWebViewController alloc]
            initWithAddress:
                [NSString stringWithFormat:@"https://www.pente.org/"
                                           @"gameServer/profile?viewName=%@",
                                           username]];
        [self.navigationController pushViewController:webVC animated:YES];
    }
}
- (void)toMMAI {
    [actionPopoverView dismiss];
    [self performSegueWithIdentifier:@"MMAItap" sender:self];
}
- (void)toAIInvitations {
    [actionPopoverView dismiss];
    [self performSegueWithIdentifier:@"inviteAItap" sender:self];
}
- (void)toDatabase {
    [actionPopoverView dismiss];
    if (player && !player.dbAccess) {
        UIAlertController *subscribersOnlyController = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"Level up your game",
                                                       nil)
                             message:
                                 NSLocalizedString(
                                     @"The database allows you to search games "
                                     @"in "
                                     @"the pente.org database by position. "
                                     @"This "
                                     @"powerful tool enables you to study and "
                                     @"analyze games and opponents, practice "
                                     @"opening moves, sort the results by most "
                                     @"played or highest win percentage, and "
                                     @"filter by player name and winner. More "
                                     @"features will be added in the "
                                     @"future.\n\nThe database is open to "
                                     @"subscribers or new users after their "
                                     @"first "
                                     @"rated game in their first two months "
                                     @"only.",
                                     nil)
                      preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction =
            [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil)
                                     style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action){
                                       //            NSLog(@"Cancel action");
                                   }];
        UIAlertAction *subscribeAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"subscription info", nil)
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
                        ((PenteNavigationViewController *)
                             self.navigationController)
                            .showSubscribe = YES;
                        [self performSegueWithIdentifier:@"settingsTap"
                                                  sender:self];
                    }];
        [subscribersOnlyController addAction:cancelAction];
        [subscribersOnlyController addAction:subscribeAction];

        if (subscribersOnlyController.popoverPresentationController != nil) {
            subscribersOnlyController.popoverPresentationController
                .barButtonItem = self.navigationItem.rightBarButtonItems[1];
        }

        [self presentViewController:subscribersOnlyController
                           animated:NO
                         completion:nil];
        return;
    }
    [self performSegueWithIdentifier:@"databaseSegue" sender:self];
}

- (void)alertView:(UIAlertView *)alertView
    clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 0) {
        alreadyAskedAboutInvitations = YES;
        if (buttonIndex == 0) {
            //            NSLog(@"button 0");
        } else if (buttonIndex == 1) {
            //            NSLog(@"button 1");
            UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:NSLocalizedString(@"How to?", nil)
                          message:
                              NSLocalizedString(
                                  @"Pick any game but leave the opponent field "
                                  @"empty and everyone will see your "
                                  @"invitation.",
                                  nil)
                         delegate:self
                cancelButtonTitle:NSLocalizedString(@"Got it!", nil)
                otherButtonTitles:nil, nil];
            [alert setTag:1];
            [alert show];
        } else if (buttonIndex == 2) {
            //            NSLog(@"button 2");
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:YES forKey:@"doNotRemindOpenInvitation"];
        }
    } else if (alertView.tag == 1) {
        [self performSegueWithIdentifier:@"addInvitationsTap" sender:self];
    } else if (alertView.tag == 2) {
        if (buttonIndex == 1) {
            [self performSegueWithIdentifier:@"addInvitationsTap" sender:self];
        } else if (buttonIndex == 2) {
            ((PenteNavigationViewController *)self.navigationController)
                .showSubscribe = YES;
            [self performSegueWithIdentifier:@"settingsTap" sender:self];
        }
    }
}

- (NSString *)replaceWithSmileys:(NSString *)inStr {
    NSString *tmpStrComma = [inStr stringByReplacingOccurrencesOfString:@"\\1"
                                                             withString:@","];
    NSString *tmpStrSmiley =
        [tmpStrComma stringByReplacingOccurrencesOfString:
                         @"<img border=\"0\" "
                         @"src=\"http://[host]/gameServer/forums/images/"
                         @"emoticons/happy.gif\" alt=\"\">"
                                               withString:@":)"];
    NSString *tmpStrWink =
        [tmpStrSmiley stringByReplacingOccurrencesOfString:
                          @"<img border=\"0\" "
                          @"src=\"http://[host]/gameServer/forums/images/"
                          @"emoticons/wink.gif\" alt=\"\">"
                                                withString:@";)"];
    NSString *tmpStrTongue = [tmpStrWink
        stringByReplacingOccurrencesOfString:
            @"<img border=\"0\" "
            @"src=\"http://[host]/gameServer/forums/images/emoticons/"
            @"silly.gif\" alt=\"\">"
                                  withString:@":p"];
    NSString *tmpStrGrin =
        [tmpStrTongue stringByReplacingOccurrencesOfString:
                          @"<img border=\"0\" "
                          @"src=\"http://[host]/gameServer/forums/images/"
                          @"emoticons/grin.gif\" alt=\"\">"
                                                withString:@":D"];
    NSString *tmpStrSad = [tmpStrGrin
        stringByReplacingOccurrencesOfString:
            @"<img border=\"0\" "
            @"src=\"http://[host]/gameServer/forums/images/emoticons/"
            @"sad.gif\" alt=\"\">"
                                  withString:@":("];
    NSString *tmpStrLove = [tmpStrSad
        stringByReplacingOccurrencesOfString:
            @"<img border=\"0\" "
            @"src=\"http://[host]/gameServer/forums/images/emoticons/"
            @"love.gif\" alt=\"\">"
                                  withString:@"<3"];
    NSString *tmpStrMischief = [tmpStrLove
        stringByReplacingOccurrencesOfString:
            @"<img border=\"0\" "
            @"src=\"http://[host]/gameServer/forums/images/emoticons/"
            @"mischief.gif\" alt=\"\">"
                                  withString:@";\\"];
    NSString *tmpStrCool =
        [tmpStrMischief stringByReplacingOccurrencesOfString:
                            @"<img border=\"0\" "
                            @"src=\"http://[host]/gameServer/forums/images/"
                            @"emoticons/cool.gif\" alt=\"\">"
                                                  withString:@"B)"];
    NSString *tmpStrDevil = [tmpStrCool
        stringByReplacingOccurrencesOfString:
            @"<img border=\"0\" "
            @"src=\"http://[host]/gameServer/forums/images/emoticons/"
            @"devil.gif\" alt=\"\">"
                                  withString:@">:)"];
    NSString *tmpStrAngry =
        [tmpStrDevil stringByReplacingOccurrencesOfString:
                         @"<img border=\"0\" "
                         @"src=\"http://[host]/gameServer/forums/images/"
                         @"emoticons/angry.gif\" alt=\"\">"
                                               withString:@"X("];
    NSString *tmpStrLaugh =
        [tmpStrAngry stringByReplacingOccurrencesOfString:
                         @"<img border=\"0\" "
                         @"src=\"http://[host]/gameServer/forums/images/"
                         @"emoticons/laugh.gif\" alt=\"\">"
                                               withString:@":^O"];
    NSString *tmpStrBlush =
        [tmpStrLaugh stringByReplacingOccurrencesOfString:
                         @"<img border=\"0\" "
                         @"src=\"http://[host]/gameServer/forums/images/"
                         @"emoticons/blush.gif\" alt=\"\">"
                                               withString:@":8)"];
    NSString *tmpStrCry =
        [tmpStrBlush stringByReplacingOccurrencesOfString:
                         @"<img border=\"0\" "
                         @"src=\"http://[host]/gameServer/forums/images/"
                         @"emoticons/cry.gif\" alt=\"\">"
                                               withString:@":'("];
    NSString *tmpStrConfused = [tmpStrCry
        stringByReplacingOccurrencesOfString:
            @"<img border=\"0\" "
            @"src=\"http://[host]/gameServer/forums/images/emoticons/"
            @"confused.gif\" alt=\"\">"
                                  withString:@"?:|"];
    NSString *tmpStrShocked =
        [tmpStrConfused stringByReplacingOccurrencesOfString:
                            @"<img border=\"0\" "
                            @"src=\"http://[host]/gameServer/forums/images/"
                            @"emoticons/shocked.gif\" alt=\"\">"
                                                  withString:@":O"];
    return [tmpStrShocked stringByReplacingOccurrencesOfString:
                              @"<img border=\"0\" "
                              @"src=\"http://[host]/gameServer/forums/images/"
                              @"emoticons/plain.gif\" alt=\"\">"
                                                    withString:@":|"];
}

- (void)nagBeginnerAccept {
    if (![[NSUserDefaults standardUserDefaults]
            boolForKey:@"remindBeginnerAccept"]) {
        UIAlertController *remindBeginnerController = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"Warning", nil)
                             message:
                                 NSLocalizedString(
                                     @"If you accept a beginner invitation, "
                                     @"the "
                                     @"server will post an identical "
                                     @"invitation in "
                                     @"your name. This warning can be disabled "
                                     @"in "
                                     @"the settings.\nDo you want to continue?",
                                     nil)
                      preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"dismiss", nil)
                      style:UIAlertActionStyleCancel
                    handler:^(UIAlertAction *action) {
                        [UIView animateWithDuration:0.3
                            animations:^{
                                [self removeButtonsFromPublicInvitationsCell];
                                [self.tableView beginUpdates];
                                selectedPublicInvitationIndexPath = nil;
                                [self.tableView endUpdates];
                                selectedPublicInvitationCell = nil;
                            }
                            completion:^(BOOL finished) {
                                [self performSelector:@selector
                                      (scrollViewDidScroll:)
                                           withObject:self.tableView
                                           afterDelay:0.01];
                            }];
                    }];
        UIAlertAction *acceptAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"yes, accept invitation", nil)
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
                        [self acceptPublicBeginnerInvitation];
                    }];
        UIAlertAction *acceptAndStopRemindingAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"yes and stop warnings", nil)
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
                        [[NSUserDefaults standardUserDefaults]
                            setBool:YES
                             forKey:@"remindBeginnerAccept"];
                        [self acceptPublicBeginnerInvitation];
                    }];
        [remindBeginnerController addAction:cancelAction];
        [remindBeginnerController addAction:acceptAction];
        [remindBeginnerController addAction:acceptAndStopRemindingAction];

        if (remindBeginnerController.popoverPresentationController != nil) {
            remindBeginnerController.popoverPresentationController
                .barButtonItem = self.navigationItem.rightBarButtonItems[1];
        }

        [self presentViewController:remindBeginnerController
                           animated:YES
                         completion:nil];
        return;

    } else {
        [self acceptPublicBeginnerInvitation];
    }
}

- (void)acceptPublicBeginnerInvitation {
    self.tableView.layer.borderWidth = 1.5;
    [self performSelector:@selector(scrollViewDidScroll:)
               withObject:self.tableView];

    NSString *url = @"https://www.pente.org/gameServer/tb/replyInvitation";
    if (development) {
        url = @"https://localhost/gameServer/tb/replyInvitation";
    }
    NSString *postString = [NSString
        stringWithFormat:@"sid=%@&inviteeMessage=&command=Accept&mobile=",
                         [[self.player.publicInvitations
                             objectAtIndex:selectedPublicInvitationIndexPath
                                               .row] gameID]];
    NSDictionary *urlAndPostString = [NSDictionary
        dictionaryWithObjects:[NSArray arrayWithObjects:url, postString, nil]
                      forKeys:[NSArray
                                  arrayWithObjects:@"url", @"postString", nil]];
    [NSThread detachNewThreadSelector:@selector(postToPenteOrgUrl:)
                             toTarget:self
                           withObject:urlAndPostString];

    NSString *newFriend = [[self.player.publicInvitations
        objectAtIndex:selectedPublicInvitationIndexPath.row] opponentName];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *toHistory =
        [[defaults objectForKey:@"invitedHistory"] mutableCopy];
    if (toHistory) {
        int i = 0;
        for (i = 0; i < [toHistory count]; ++i) {
            if ([[toHistory objectAtIndex:i]
                    localizedCaseInsensitiveCompare:newFriend] ==
                NSOrderedDescending)
                break;
        }
        if (![toHistory containsObject:newFriend]) {
            [toHistory insertObject:newFriend atIndex:i];
        }
    } else {
        toHistory = [NSMutableArray arrayWithObject:newFriend];
    }
    [defaults setObject:toHistory forKey:@"invitedHistory"];

    NSIndexPath *tmpPath = selectedPublicInvitationIndexPath;
    [UIView animateWithDuration:0.3
        animations:^{
            [self removeButtonsFromPublicInvitationsCell];
            [self.tableView beginUpdates];
            selectedPublicInvitationIndexPath = nil;
            [self.tableView endUpdates];
            self->selectedPublicInvitationCell = nil;
        }
        completion:^(BOOL finished) {
            [self performSelector:@selector(scrollViewDidScroll:)
                       withObject:self.tableView
                       afterDelay:0.01];
        }];

    [self.player.publicInvitations removeObjectAtIndex:tmpPath.row];
    [UIView animateWithDuration:0.3
        animations:^{
            [self.tableView
                deleteRowsAtIndexPaths:[NSArray arrayWithObject:tmpPath]
                      withRowAnimation:UITableViewRowAnimationFade];
        }
        completion:^(BOOL finished) {
            [self dashboardParse];
        }];
}
@end

@implementation GameTableViewCell
@synthesize ratingLabel;

- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        ratingLabel = [[UILabel alloc] init];
        [ratingLabel setTextAlignment:NSTextAlignmentRight];
        [self.ratingLabel setFont:[UIFont fontWithName:@"HelveticaNeue"
                                                  size:16.f]];
        [self.contentView addSubview:ratingLabel];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.clipsToBounds = YES;
        self.textLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat imageWidth = 0;
    if (self.imageView.image) {
        [self.imageView setFrame:CGRectMake(0, 0, 44, 44)];
        imageWidth = self.imageView.frame.size.width;
    }
    CGFloat accessoryWidth;
    if (self.accessoryType == UITableViewCellAccessoryDisclosureIndicator) {
        accessoryWidth = 20;
    } else {
        accessoryWidth = 0;
    }
    if ([self.reuseIdentifier isEqualToString:@"tournament"] ||
        [self.reuseIdentifier isEqualToString:@"kingOfTheHill"]) {
        [self.textLabel
            setFrame:CGRectMake(10, 2, (screenWidth - accessoryWidth - 10),
                                22)];
        [self.detailTextLabel
            setFrame:CGRectMake(10, 24, screenWidth - accessoryWidth - 20, 18)];
        //        [self.imageView setFrame:CGRectMake(0, 0, imageWidth,
        //        imageWidth)];
    } else {
        [self.textLabel
            setFrame:CGRectMake(
                         imageWidth + 10, 2,
                         (screenWidth - imageWidth - accessoryWidth + 60) / 2,
                         22)];
        [self.ratingLabel
            setFrame:CGRectMake(
                         imageWidth + 10 +
                             (screenWidth - imageWidth - accessoryWidth - 20) /
                                 2,
                         2,
                         (screenWidth - imageWidth - accessoryWidth - 60) / 2,
                         22)];
        [self.detailTextLabel
            setFrame:CGRectMake(imageWidth + 10, 24,
                                screenWidth - imageWidth - accessoryWidth - 20,
                                18)];
        [self.imageView setFrame:CGRectMake(0, 0, imageWidth, imageWidth)];
    }

    //        NSLog(@"kittenfont ");
}

//- (void) replaceButton {
//    if ([(UITableView *)self.superview.superview indexPathForCell:
//    self].section == 3) {
//        UIView *deleteButtonView;
//        for (UIView *subview in self.subviews) {
//            //            NSLog(@"kitty2 %@", NSStringFromClass([subview
//            class])); for (UIView *subsubview in subview.subviews) {
////                NSLog(@"kitty1 %@", NSStringFromClass([subsubview class]));
//                if ([NSStringFromClass([subsubview class])
//                isEqualToString:@"UITableViewCellDeleteConfirmationView"]) {
//                    //                if ([NSStringFromClass([subsubview
//                    class]) isEqualToString:@"UIButton"]) {
//
//                    deleteButtonView = (UIView *) subsubview;
//                    //                    deleteButtonView.backgroundColor =
//                    [UIColor greenColor]; UIImageView *image = [[UIImageView
//                    alloc] initWithImage:[UIImage
//                    imageNamed:@"acceptButton"]]; [image
//                    setFrame:CGRectMake(0,0,deleteButtonView.frame.size.width,
//                    deleteButtonView.frame.size.height)]; [deleteButtonView
//                    addSubview:image];
//                }
//            }
//        }
//    }
//}

@end
