//
//  GamesTableViewController.m
//  test1
//
//  Created by rainwolf on 12/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "GamesTableViewController.h"
#import "PentePlayer.h"
#import "BoardViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "BoardView.h"
#import "RatingStatsView.h"
#import "SVWebViewController.h"
#import "MMAIViewController.h"
#import "KOTHTableViewController.h"


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
@synthesize bannerView;
@synthesize messagesCollapsed, invitationsReceivedCollapsed, activeGamesCollapsed, publicInvitationsCollapsed, sentInvitationsCollapsed, nonActiveGamesCollapsed,
            alreadyAskedAboutInvitations, tournamentsCollapsed, kothCollapsed;
@synthesize selectedInvitationCell, selectedPublicInvitationCell;
@synthesize interstitial;
@synthesize gamesLimit;
@synthesize showAds;
@synthesize actionPopoverView;


//- (void)adViewWillLeaveApplication:(GADBannerView *)bannerView {
//    NSLog(@"... leaving penteLive for an ad");
//    NSLog(@"The ad's adNetworkClassName: %@", self.bannerView.adNetworkClassName);
//}

- (BOOL)shouldAutorotate {
//    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    //    return ((interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown) && (interfaceOrientation != UIInterfaceOrientationLandscapeLeft) && (interfaceOrientation != UIInterfaceOrientationLandscapeRight));
    return YES;
//    if (((1 << interfaceOrientation) & [self supportedInterfaceOrientations]) == 0) {
//        return YES;
//    } else {
//        return NO;
//    }
//    return (interfaceOrientation != UIInterfaceOrientationPortrait);
}
-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
//    return UIInterfaceOrientationLandscapeLeft | UIInterfaceOrientationLandscapeRight | UIInterfaceOrientationPortrait;
}



- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    player = [[PentePlayer alloc] init];
    [super viewDidLoad];
    [self setTitle:@"Home"];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;

    selectedInvitationCell = nil;
    selectedPublicInvitationCell = nil;
    
//    messageButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"messageBubble0.png"] style:UIBarButtonItemStylePlain target:self action:@selector(messageTap)];
//    [messageButton setImage:[UIImage imageNamed:@"messageBubbleEnd.png"]];
//    inviteButton = [self.navigationItem rightBarButtonItem];
    UIBarButtonItem *inviteButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:self action: @selector(showInvitationActions)];
    UIBarButtonItem *moreButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed:@"showpopup.png"] style: UIBarButtonItemStylePlain target:self action: @selector(showActions)];
//    statsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItem target:self action: @selector(showStats)];
//    friendsButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed:@"friends.png"] style: UIBarButtonItemStylePlain target:self action:@selector(toFriends)];
    [self.navigationItem setRightBarButtonItem:nil];
    [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:moreButton, inviteButton, nil]];

    UIBarButtonItem *leftBarButton = [self.navigationItem leftBarButtonItem];
    [leftBarButton setImage:[UIImage imageNamed:@"settings.png"]];
    [leftBarButton setTitle: nil];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    messagesCollapsed = [defaults boolForKey:@"messagesCollapsed"];
    invitationsReceivedCollapsed = [defaults boolForKey:@"invitationsReceivedCollapsed"];
    activeGamesCollapsed = [defaults boolForKey:@"activeGamesCollapsed"];
    publicInvitationsCollapsed = [defaults boolForKey:@"publicInvitationsCollapsed"];
    sentInvitationsCollapsed = [defaults boolForKey:@"sentInvitationsCollapsed"];
    nonActiveGamesCollapsed = [defaults boolForKey:@"nonActiveGamesCollapsed"];
    tournamentsCollapsed = [defaults boolForKey:@"tournamentsCollapsed"];
    kothCollapsed = [defaults boolForKey:@"kothCollapsed"];
    self.tableView.layer.borderColor = [UIColor redColor].CGColor;
    
    alreadyAskedAboutInvitations = NO;
    
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    bannerView = navController.bannerView;

    self.interstitial = nil;
    self.interstitial = [[GADInterstitial alloc] initWithAdUnitID:@"ca-app-pub-3326997956703582/8641559446"];
    [self.interstitial setDelegate:self];
//    [self.interstitial setAdUnitID:@"567b72e8189a488c"];
    [self.interstitial loadRequest:[GADRequest request]];
    
    showAds = YES;
    gamesLimit = 200;
    
    long openInvitationsLimit = [[NSUserDefaults standardUserDefaults] integerForKey:@"openInvitationsLimit"];
    if (openInvitationsLimit == 0) {
        [[NSUserDefaults standardUserDefaults] setInteger: 3 forKey:@"openInvitationsLimit"];
    }
}



- (void)interstitialDidDismissScreen:(GADInterstitial *)interstitial {
    self.interstitial = nil;
    if (showAds) {
        self.interstitial = [[GADInterstitial alloc] initWithAdUnitID:@"ca-app-pub-3326997956703582/8641559446"];
        [self.interstitial setDelegate:self];
        [self.interstitial loadRequest:[GADRequest request]];
    }
}


-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [super scrollViewDidScroll:scrollView];
    if (showAds) {
        if (bannerView) {
            CGFloat newOriginY = self.tableView.contentOffset.y + self.tableView.frame.size.height - bannerView.frame.size.height;
            CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
            bannerView.frame = newBannerViewFrame;
        }
    } else if (bannerView) {
        [bannerView removeFromSuperview];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    if (!navController.loggedIn) {
        self.tableView.layer.borderWidth = 1.5;
        [self login];
    }
    bannerView = navController.bannerView;
    [navController setChallengeCancelled:NO];
    bannerView.rootViewController = self;
    [bannerView setDelegate: self];
    if (showAds) {
        CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
        CGFloat newOriginY = screenHeight - navController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height - bannerView.frame.size.height;
        CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
        bannerView.frame = newBannerViewFrame;
        [self.tableView setTableFooterView:bannerView];
        [self.tableView bringSubviewToFront:bannerView];
        [self scrollViewDidScroll: self.tableView];
    }

    
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    int numberAppearances = 0;
//    if ((numberAppearances = (int) [defaults integerForKey:@"gamesTableViewAppearances"])) {
//        numberAppearances = (numberAppearances + 1) % 5;
//    } else {
//        ++numberAppearances;
//    }
//    [defaults setInteger:numberAppearances forKey:@"gamesTableViewAppearances"];
//    if (!navController.receivedNotification) {
//        if (numberAppearances == 0) {
//            if ([self.interstitial isReady]) {
//                [self.interstitial presentFromRootViewController:self];
//            }
//        }
//
//    } else if (numberAppearances == 0) {
//        [defaults setInteger:4 forKey:@"gamesTableViewAppearances"];
//    }
    
//    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:.05f];
}

- (void)viewWillAppear:(BOOL)animated {
    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
    if (navControllor.needHelp) {
        [self performSegueWithIdentifier:@"messagesTap" sender:self];
        [messagesViewController setPlayer:player];
        [messagesViewController setGamesLimit: gamesLimit];
        return;
    }
    if (navControllor.didMove) {
        [navControllor setDidMove: NO];
        if (!activeGamesCollapsed) {
            for( int i = 0; i < [[player activeGames] count]; ++i) {
                if ([navControllor.activeGameToRemove isEqualToString:[[[player activeGames] objectAtIndex:i] gameID]]) {
                    [[player activeGames] removeObjectAtIndex:i];
                    [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:i inSection:2]] withRowAnimation:UITableViewRowAnimationFade];
                    break;
                }
            }
        }
        [self dashboardParse];
    } else if (navControllor.messageDeleted) {
        [navControllor setMessageDeleted:NO];
        [player.messages removeObjectAtIndex: navControllor.deletedMessageRow];
        [UIView animateWithDuration:0.3 animations:^{ if (!messagesCollapsed) {
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject: [NSIndexPath indexPathForRow:navControllor.deletedMessageRow inSection:0]] withRowAnimation:UITableViewRowAnimationFade];
        } else {
            [self.tableView reloadData];
        }
        } completion:^(BOOL finished){[self dashboardParse];
                //                [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView];
            }];
    }
    
    selectedInvitationIndexPath = nil;
    selectedInvitationCell = nil;
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [bannerView removeFromSuperview];
    [self.tableView setTableFooterView:nil];
}



-(void) login {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    username = [defaults objectForKey:usernameKey];
    password = [defaults objectForKey:passwordKey];
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
        url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/login.jsp?mobile=&name2=%@&password2=%@",username,password];
//        url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/login.jsp?mobile=&name2=%@&password2=%@",username,password];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setTimeoutInterval:7.0];
        responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        if ([dashboardString isEqualToString:@""] || ([dashboardString rangeOfString:@"HTTP Error"].length != 0)) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"pente.org appears to be down, please try again later." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            [self performSegueWithIdentifier:@"settingsTap" sender:self];
            return;
        }
        else if ([dashboardString rangeOfString:@"<h2>Pente.org is undergoing maintenance.</h2>"].length != 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Maintenance" message:@"pente.org is undergoing maintenance, please try again in a few minutes." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            [self performSegueWithIdentifier:@"settingsTap" sender:self];
            return;
        } else if ([dashboardString rangeOfString:@"Invalid name or password, please try again."].length != 0) {
            [self performSegueWithIdentifier:@"settingsTap" sender:self];
            return;
        } else {
            PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
            [navControllor setLoggedIn: YES];
            [NSThread detachNewThreadSelector:@selector(handleDeviceToken) toTarget:self withObject:nil];
            [self dashboardParse];
        }
    } else {
        [self performSegueWithIdentifier:@"settingsTap" sender:self];
        return;
    }
}

-(void) handleDeviceToken {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *storedTokenString = [defaults objectForKey: @"deviceToken"];
    if (storedTokenString) {
        NSDate *dateOfLastPing = [defaults objectForKey:@"lastPing"];
        if (dateOfLastPing) {
            double daysPassed = [dateOfLastPing timeIntervalSinceNow] / -86400.0;
            if (daysPassed < 1) {
                return;
            }
        }
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        NSString *url = [NSString stringWithFormat:@"https://pente.org/gameServer/notifications/registerDevice.jsp?name=%@&password=%@&token=%@",username,password,storedTokenString];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"GET"];
        [request setTimeoutInterval:7.0];
        NSURLResponse *response;
        NSError *error;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *replyString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

//        NSLog(@"wth \n %@", replyString);
        if ([replyString rangeOfString:@"It seems to have worked"].location != NSNotFound) {
            [defaults setObject:[NSDate date] forKey:@"lastPing"];
        }
    } else {
        NSLog(@"No Device Token stored");
    }
}





-(void) pullDownToReloadAction {
    if (selectedInvitationIndexPath) {
        [self removeButtonsFromCell];
        [self.tableView beginUpdates];
        selectedInvitationIndexPath = nil;
        selectedInvitationCell = nil;
        [self.tableView endUpdates];
        [[self.tableView cellForRowAtIndexPath:selectedInvitationIndexPath] setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
//    [self.tableView setUserInteractionEnabled: NO];
    self.tableView.layer.borderWidth = 1.5;
    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.05];
//	[self performSelector:@selector(pullDownToReloadActionFinished) withObject:nil afterDelay: 0.5f];
    [self performSelectorOnMainThread:@selector(dashboardParse) withObject:nil waitUntilDone:NO];
}

-(void) pullDownToReloadActionFinished {
	[self.pullToReloadHeaderView setLastUpdatedDate: [NSDate date]];
    [self.pullToReloadHeaderView finishReloading:self.tableView animated:YES];
    [self.tableView reloadData];
//    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.25];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    //#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return 8;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    //warning Incomplete method implementation.
    // Return the number of rows in the section.
    if (!player) {
        return 0;
    }
    switch (section) {
        case MESSAGESSECTION:
            if (messagesCollapsed) {
                return 0;
            }
            return [[player messages] count];
            break;
        case INVITATIONSSECTION:
            if (invitationsReceivedCollapsed) {
                return 0;
            }
            return [[player invitations] count];
            break;
        case ACTIVEGAMESSECTION:
            if (activeGamesCollapsed) {
                return 0;
            }
            return [[player activeGames] count];
            break;
        case PUBLICINVITATIONSSECTION:
            if (publicInvitationsCollapsed) {
                return 0;
            }
            return [[player publicInvitations] count];
            break;
        case SENTINVITATIONSSECTION:
            if (sentInvitationsCollapsed) {
                return 0;
            }
            return [[player sentInvitations] count];
            break;
        case NONACTIVEGAMESSECTION:
            if (nonActiveGamesCollapsed) {
                return 0;
            }
            return [[player nonActiveGames] count];
            break;
        case TOURNAMENTSSECTION:
            if (tournamentsCollapsed) {
                return 0;
            }
            return [[player tournaments] count];
            break;
        case KOTHSECTION:
            if (kothCollapsed) {
                return 0;
            }
            return [[player hills] count];
            break;
        default:
            return 0;
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (selectedInvitationIndexPath && (indexPath.section == INVITATIONSSECTION)) {
        if ((selectedInvitationIndexPath.section == INVITATIONSSECTION) && (indexPath.row == selectedInvitationIndexPath.row)) {
            return 88;
        }
    }
    if (selectedPublicInvitationIndexPath && (indexPath.section == PUBLICINVITATIONSSECTION)) {
        if ((selectedPublicInvitationIndexPath.section == PUBLICINVITATIONSSECTION) && (indexPath.row == selectedPublicInvitationIndexPath.row)) {
            return 88;
        }
    }
    return 44;
}

-(void) addColorOfRating: (NSString *) rating toString: (NSMutableAttributedString *) str {
    int ratingInt = [rating intValue];
    UIColor *ratingColor = [UIColor blackColor];
    if (ratingInt >= 1900) {
        ratingColor = [UIColor redColor];
    } else if (ratingInt >= 1700) {
        ratingColor = [UIColor colorWithRed:0.98 green:0.96 blue:0.03 alpha:1.0];
    } else if (ratingInt >= 1400) {
        ratingColor = [UIColor blueColor];
    } else if (ratingInt >= 1000) {
        ratingColor = [UIColor colorWithRed:30.0/255 green: 130.0/255 blue:76.0/255 alpha:1.0];
    } else {
        ratingColor = [UIColor grayColor];
    }
    NSString *strString = [str string];
    [str addAttribute:NSForegroundColorAttributeName value: ratingColor range: [strString rangeOfString: @"\u25A0"]];
    [str addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Bold" size:12.f] range: [strString rangeOfString: @"\u25A0"]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CellIdentifier";
    static NSString *CellWithWhiteStoneImageIdentifier = @"CellWithWhiteStoneImage";
    static NSString *CellWithBlackStoneImageIdentifier = @"CellWithBlackStoneImage";
    static NSString *CellWithUnreadImageIdentifier = @"CellWithUnreadImage";

    NSString *tmpIdentifier;
    //    NSLog(@"here kitty");
//    GameTableViewCell *cell = (GameTableViewCell *) [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    GameTableViewCell *cell;
    NSMutableAttributedString *tmpStr;
    NSMutableString *txtStr;
    
    if (indexPath.section == MESSAGESSECTION) {
        if ([[[[player messages] objectAtIndex:indexPath.row] unread] isEqualToString:@"unread"]) {
            cell = (GameTableViewCell *) [tableView dequeueReusableCellWithIdentifier: CellWithUnreadImageIdentifier];
            if (!cell) {
                cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellWithUnreadImageIdentifier];
            }
            cell.imageView.image = [UIImage imageNamed:@"unread.png"];
        } else {
            cell = (GameTableViewCell *) [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
            if (!cell) {
                cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
            }
        }
        txtStr = [[NSMutableString alloc] initWithString:[[[player messages] objectAtIndex:indexPath.row] author]];
        int crown = [[[player messages] objectAtIndex:indexPath.row] crown];
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        switch (crown) {
            case 1:
                textAttachment.image = [UIImage imageNamed:@"crown.gif"];
                break;
            case 2:
                textAttachment.image = [UIImage imageNamed:@"scrown.gif"];
                break;
            case 3:
                textAttachment.image = [UIImage imageNamed:@"bcrown.gif"];
                break;
            case 4:
                textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
                break;
                
            default:
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        cell.ratingLabel.text = @"";
        tmpStr = [[NSMutableAttributedString alloc] initWithString:txtStr];
        [tmpStr addAttribute:NSForegroundColorAttributeName value:[[[player messages] objectAtIndex:indexPath.row] nameColor] range:NSMakeRange(0, [[[[player messages] objectAtIndex:indexPath.row] author] length])];
        if (![[[[player messages] objectAtIndex:indexPath.row] nameColor] isEqual:UIColorFromRGB(0)]) {
            [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[[[player messages] objectAtIndex:indexPath.row] author] length])];
        } else {
            [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [[[[player messages] objectAtIndex:indexPath.row] author] length])];
        }
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
        [tmpStr appendAttributedString:crownStr];
//        [tmpStr appendString:@" ("];
//        [tmpStr appendString: [[[player messages] objectAtIndex:indexPath.row] timeStamp]];
//        [tmpStr appendString:@")"];
        cell.ratingLabel.text = [[[player messages] objectAtIndex:indexPath.row] timeStamp];
        cell.textLabel.attributedText = tmpStr;
        cell.detailTextLabel.text = [[[player messages] objectAtIndex:indexPath.row] subject];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell setUserInteractionEnabled:YES];
    }
    if (indexPath.section == INVITATIONSSECTION) {
        if (selectedInvitationIndexPath) {
            if ((selectedInvitationIndexPath.section == INVITATIONSSECTION) && (indexPath.row == selectedInvitationIndexPath.row)) {
                return selectedInvitationCell;
            }
        }
        cell = (GameTableViewCell *) [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell.imageView removeFromSuperview];
        txtStr = [[NSMutableString alloc] initWithString:[[[player invitations] objectAtIndex:indexPath.row] opponentName]];
        int crown = [[[player invitations] objectAtIndex:indexPath.row] crown];
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        switch (crown) {
            case 1:
                textAttachment.image = [UIImage imageNamed:@"crown.gif"];
                break;
            case 2:
                textAttachment.image = [UIImage imageNamed:@"scrown.gif"];
                break;
            case 3:
                textAttachment.image = [UIImage imageNamed:@"bcrown.gif"];
                break;
            case 4:
                textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
                break;
                
            default:
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        NSMutableString *ratingStr = [NSMutableString stringWithString:@"\u25A0 "];
        if ([[[[player invitations] objectAtIndex:indexPath.row] opponentRating] length] == 3) {
            [ratingStr appendString:@"  "];
        }
        [ratingStr appendString: [[[player invitations] objectAtIndex:indexPath.row] opponentRating]];
        tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
        [self addColorOfRating: [[[player invitations] objectAtIndex: indexPath.row] opponentRating] toString: tmpStr];
        cell.ratingLabel.attributedText = tmpStr;

        tmpStr = [[NSMutableAttributedString alloc] initWithString:txtStr];
        [tmpStr addAttribute:NSForegroundColorAttributeName value:[[[player invitations] objectAtIndex:indexPath.row] nameColor] range:NSMakeRange(0, [[[[player invitations] objectAtIndex:indexPath.row] opponentName] length])];
        [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
        if (![[[[player invitations] objectAtIndex:indexPath.row] nameColor] isEqual:UIColorFromRGB(0)]) {
            [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[[[player invitations] objectAtIndex:indexPath.row] opponentName] length])];
        }
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
        [tmpStr appendAttributedString:crownStr];
        cell.textLabel.attributedText = tmpStr;
        if ([[[[player invitations] objectAtIndex:indexPath.row] ratedNot] isEqualToString:@"Rated"]) {
            txtStr = (NSMutableString *) [NSString stringWithFormat:@"%@ (%@) - %@", [[[player invitations] objectAtIndex:indexPath.row] gameType], [[[player invitations] objectAtIndex:indexPath.row] ratedNot], [[[player invitations] objectAtIndex:indexPath.row] remainingTime]];
        } else {
            txtStr = (NSMutableString *) [NSString stringWithFormat:@"%@ (%@, %@) - %@", [[[player invitations] objectAtIndex:indexPath.row] gameType], [[[player invitations] objectAtIndex:indexPath.row] ratedNot], [[[[player invitations] objectAtIndex:indexPath.row] myColor] substringWithRange: NSMakeRange(0,5)], [[[player invitations] objectAtIndex:indexPath.row] remainingTime]];
        }
        cell.detailTextLabel.text = txtStr;
        [cell setUserInteractionEnabled: YES];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    if (indexPath.section == ACTIVEGAMESSECTION) {
        tmpIdentifier = [[[[player activeGames] objectAtIndex:indexPath.row] myColor] isEqualToString:@"white"] ? CellWithWhiteStoneImageIdentifier : CellWithBlackStoneImageIdentifier;
        cell = (GameTableViewCell *) [tableView dequeueReusableCellWithIdentifier: tmpIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:tmpIdentifier];
        }
        txtStr = [[NSMutableString alloc] initWithString:[[[player activeGames] objectAtIndex:indexPath.row] opponentName]];
        int crown = [[[player activeGames] objectAtIndex:indexPath.row] crown];
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        switch (crown) {
            case 1:
                textAttachment.image = [UIImage imageNamed:@"crown.gif"];
                break;
            case 2:
                textAttachment.image = [UIImage imageNamed:@"scrown.gif"];
                break;
            case 3:
                textAttachment.image = [UIImage imageNamed:@"bcrown.gif"];
                break;
            case 4:
                textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
                break;
                
            default:
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        
        NSMutableString *ratingStr = [NSMutableString stringWithString:@"\u25A0 "];
        if ([[[[player activeGames] objectAtIndex:indexPath.row] opponentRating] length] == 3) {
            [ratingStr appendString:@"  "];
        }
        [ratingStr appendString: [[[player activeGames] objectAtIndex:indexPath.row] opponentRating]];
        tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
        [self addColorOfRating: [[[player activeGames] objectAtIndex: indexPath.row] opponentRating] toString: tmpStr];
        cell.ratingLabel.attributedText = tmpStr;
   
        tmpStr = [[NSMutableAttributedString alloc] initWithString:txtStr];
        [tmpStr addAttribute:NSForegroundColorAttributeName value:[[[player activeGames] objectAtIndex:indexPath.row] nameColor] range:NSMakeRange(0, [[[[player activeGames] objectAtIndex:indexPath.row] opponentName] length])];
        [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
        if (![[[[player activeGames] objectAtIndex:indexPath.row] nameColor] isEqual:UIColorFromRGB(0)]) {
            [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[[[player activeGames] objectAtIndex:indexPath.row] opponentName] length])];
        }
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
        [tmpStr appendAttributedString:crownStr];
        cell.textLabel.attributedText = tmpStr;
        txtStr = [[NSMutableString alloc] initWithString:[[[player activeGames] objectAtIndex:indexPath.row] gameType]];
        [txtStr appendString:@" ("];
        [txtStr appendString: [[[player activeGames] objectAtIndex:indexPath.row] ratedNot]];
        [txtStr appendString:@") - "];
        [txtStr appendString: [[[player activeGames] objectAtIndex:indexPath.row] remainingTime]];
        cell.detailTextLabel.text = txtStr;
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell setUserInteractionEnabled:YES];
        cell.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@Stone.png",[[[player activeGames] objectAtIndex:indexPath.row] myColor]]];
    }
    if (indexPath.section == PUBLICINVITATIONSSECTION) {
        if (selectedPublicInvitationIndexPath) {
            if ((selectedPublicInvitationIndexPath.section == PUBLICINVITATIONSSECTION) && (indexPath.row == selectedPublicInvitationIndexPath.row)) {
                return selectedPublicInvitationCell;
            }
        }
        cell = (GameTableViewCell *) [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
                [cell.imageView removeFromSuperview];
        txtStr = [[NSMutableString alloc] initWithString:[[[player publicInvitations] objectAtIndex:indexPath.row] opponentName]];
        int crown = [[[player publicInvitations] objectAtIndex:indexPath.row] crown];
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        switch (crown) {
            case 1:
                textAttachment.image = [UIImage imageNamed:@"crown.gif"];
                break;
            case 2:
                textAttachment.image = [UIImage imageNamed:@"scrown.gif"];
                break;
            case 3:
                textAttachment.image = [UIImage imageNamed:@"bcrown.gif"];
                break;
            case 4:
                textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
                break;
                
            default:
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        NSMutableString *ratingStr = [NSMutableString stringWithString:@"\u25A0 "];
        if ([[[[player publicInvitations] objectAtIndex:indexPath.row] opponentRating] length] == 3) {
            [ratingStr appendString:@"  "];
        }
        [ratingStr appendString: [[[player publicInvitations] objectAtIndex:indexPath.row] opponentRating]];
        tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
        [self addColorOfRating: [[[player publicInvitations] objectAtIndex: indexPath.row] opponentRating] toString: tmpStr];
        cell.ratingLabel.attributedText = tmpStr;

        tmpStr = [[NSMutableAttributedString alloc] initWithString:txtStr];
        [tmpStr addAttribute:NSForegroundColorAttributeName value:[[[player publicInvitations] objectAtIndex:indexPath.row] nameColor] range:NSMakeRange(0, [[[[player publicInvitations] objectAtIndex:indexPath.row] opponentName] length])];
        [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
        if (![[[[player publicInvitations] objectAtIndex:indexPath.row] nameColor] isEqual:UIColorFromRGB(0)]) {
            [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[[[player publicInvitations] objectAtIndex:indexPath.row] opponentName] length])];
        }
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
        [tmpStr appendAttributedString:crownStr];
        cell.textLabel.attributedText = tmpStr;
        if ([[[[player publicInvitations] objectAtIndex:indexPath.row] ratedNot] isEqualToString:@"Rated"]) {
            txtStr = (NSMutableString *) [NSString stringWithFormat:@"%@ (%@) - %@", [[[player publicInvitations] objectAtIndex:indexPath.row] gameType], [[[player publicInvitations] objectAtIndex:indexPath.row] ratedNot], [[[player publicInvitations] objectAtIndex:indexPath.row] remainingTime]];
        } else
            txtStr = (NSMutableString *) [NSString stringWithFormat:@"%@ (%@, %@) - %@", [[[player publicInvitations] objectAtIndex:indexPath.row] gameType], [[[player publicInvitations] objectAtIndex:indexPath.row] ratedNot], [[[[player publicInvitations] objectAtIndex:indexPath.row] myColor] substringWithRange: NSMakeRange(0,5)], [[[player publicInvitations] objectAtIndex:indexPath.row] remainingTime]];
        //        [[NSMutableString alloc] initWithString:[[[player invitations] objectAtIndex:indexPath.row] gameType]];
        //        [tmpStr appendString:@" ("];
        //        [tmpStr appendString: [[[player invitations] objectAtIndex:indexPath.row] ratedNot]];
        //        [tmpStr appendString:@") - "];
        //        [tmpStr appendString: [[[player invitations] objectAtIndex:indexPath.row] remainingTime]];
        cell.detailTextLabel.text = txtStr;
        [cell setUserInteractionEnabled: YES];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    }
    if (indexPath.section == SENTINVITATIONSSECTION) {
        cell = (GameTableViewCell *) [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
//        cell = nil;
//        cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        [cell.imageView removeFromSuperview];
        txtStr = [[NSMutableString alloc] initWithString:[[[player sentInvitations] objectAtIndex:indexPath.row] opponentName]];
        int crown = [[[player sentInvitations] objectAtIndex:indexPath.row] crown];
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        switch (crown) {
            case 1:
                textAttachment.image = [UIImage imageNamed:@"crown.gif"];
                break;
            case 2:
                textAttachment.image = [UIImage imageNamed:@"scrown.gif"];
                break;
            case 3:
                textAttachment.image = [UIImage imageNamed:@"bcrown.gif"];
                break;
            case 4:
                textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
                break;
                
            default:
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        if ([txtStr rangeOfString:@"Anyone"].location != NSNotFound) {
            cell.ratingLabel.text = @"";
        } else {
            NSMutableString *ratingStr = [NSMutableString stringWithString:@"\u25A0 "];
            if ([[[[player sentInvitations] objectAtIndex:indexPath.row] opponentRating] length] == 3) {
                [ratingStr appendString:@"  "];
            }
            [ratingStr appendString: [[[player sentInvitations] objectAtIndex:indexPath.row] opponentRating]];
            tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
            [self addColorOfRating: [[[player sentInvitations] objectAtIndex: indexPath.row] opponentRating] toString: tmpStr];
            cell.ratingLabel.attributedText = tmpStr;
        }
        
        tmpStr = [[NSMutableAttributedString alloc] initWithString:txtStr];
        [tmpStr addAttribute:NSForegroundColorAttributeName value:[[[player sentInvitations] objectAtIndex:indexPath.row] nameColor] range:NSMakeRange(0, [[[[player sentInvitations] objectAtIndex:indexPath.row] opponentName] length])];
        [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
        if (![[[[player sentInvitations] objectAtIndex:indexPath.row] nameColor] isEqual:UIColorFromRGB(0)]) {
            [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[[[player sentInvitations] objectAtIndex:indexPath.row] opponentName] length])];
        }
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
        [tmpStr appendAttributedString:crownStr];
        cell.textLabel.attributedText = tmpStr;
        txtStr = [[NSMutableString alloc] initWithString:[[[player sentInvitations] objectAtIndex:indexPath.row] gameType]];
        [txtStr appendString:@" ("];
        [txtStr appendString: [[[player sentInvitations] objectAtIndex:indexPath.row] ratedNot]];
        [txtStr appendString:@") - "];
        [txtStr appendString: [[[player sentInvitations] objectAtIndex:indexPath.row] remainingTime]];
        [txtStr appendString: @" per move"];
        cell.detailTextLabel.text = txtStr;
        [cell setUserInteractionEnabled: YES];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
    if (indexPath.section == NONACTIVEGAMESSECTION) {
        tmpIdentifier = [[[[player nonActiveGames] objectAtIndex:indexPath.row] myColor] isEqualToString:@"white"] ? CellWithWhiteStoneImageIdentifier : CellWithBlackStoneImageIdentifier;
        cell = (GameTableViewCell *) [tableView dequeueReusableCellWithIdentifier: tmpIdentifier];
        if (!cell) {
            cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:tmpIdentifier];
        }
        txtStr = [[NSMutableString alloc] initWithString:[[[player nonActiveGames] objectAtIndex:indexPath.row] opponentName]];
        int crown = [[[player nonActiveGames] objectAtIndex:indexPath.row] crown];
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        switch (crown) {
            case 1:
                textAttachment.image = [UIImage imageNamed:@"crown.gif"];
                break;
            case 2:
                textAttachment.image = [UIImage imageNamed:@"scrown.gif"];
                break;
            case 3:
                textAttachment.image = [UIImage imageNamed:@"bcrown.gif"];
                break;
            case 4:
                textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
                break;
                
            default:
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        NSMutableString *ratingStr = [NSMutableString stringWithString:@"\u25A0 "];
        if ([[[[player nonActiveGames] objectAtIndex:indexPath.row] opponentRating] length] == 3) {
            [ratingStr appendString:@"  "];
        }
        [ratingStr appendString: [[[player nonActiveGames] objectAtIndex:indexPath.row] opponentRating]];
        tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
        [self addColorOfRating: [[[player nonActiveGames] objectAtIndex: indexPath.row] opponentRating] toString: tmpStr];
        cell.ratingLabel.attributedText = tmpStr;

        tmpStr = [[NSMutableAttributedString alloc] initWithString:txtStr];

        [tmpStr addAttribute:NSForegroundColorAttributeName value:[[[player nonActiveGames] objectAtIndex:indexPath.row] nameColor] range:NSMakeRange(0, [[[[player nonActiveGames] objectAtIndex:indexPath.row] opponentName] length])];
        [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
        if (![[[[player nonActiveGames] objectAtIndex:indexPath.row] nameColor] isEqual:UIColorFromRGB(0)]) {
            [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[[[player nonActiveGames] objectAtIndex:indexPath.row] opponentName] length])];
        }
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
        [tmpStr appendAttributedString:crownStr];
        cell.textLabel.attributedText = tmpStr;
        txtStr = [[NSMutableString alloc] initWithString:[[[player nonActiveGames] objectAtIndex:indexPath.row] gameType]];
        [txtStr appendString:@" ("];
        [txtStr appendString: [[[player nonActiveGames] objectAtIndex:indexPath.row] ratedNot]];
        [txtStr appendString:@") - "];
        [txtStr appendString: [[[player nonActiveGames] objectAtIndex:indexPath.row] remainingTime]];
        cell.detailTextLabel.text = txtStr;
        [cell setUserInteractionEnabled:YES];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        cell.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@Stone.png",[[[player nonActiveGames] objectAtIndex:indexPath.row] myColor]]];
    }
    if (indexPath.section == TOURNAMENTSSECTION) {
        cell = [tableView dequeueReusableCellWithIdentifier: @"tournament"];
        if (!cell) {
            cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"tournament"];
        }
        tmpStr = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat:@"\u25CF  %@ - (%@)", [[[player tournaments] objectAtIndex: indexPath.row] name], [[[player tournaments] objectAtIndex: indexPath.row] game]]];
        [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:25] range:NSMakeRange(0, 1)];
        long len = [[[[player tournaments] objectAtIndex: indexPath.row] game] length];
        [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue" size: 14] range:NSMakeRange([tmpStr length] - 2 - len, len + 2)];
        UIColor *statusColor;
        if ([[[[player tournaments] objectAtIndex: indexPath.row] tournamentState] isEqualToString:@"2"]) {
            statusColor = [UIColor orangeColor];
            cell.detailTextLabel.text = [NSString stringWithFormat: @"Registration closed. Starts %@", [[[player tournaments] objectAtIndex: indexPath.row] date]];
        } else {
            statusColor = [UIColor greenColor];
            if ([[[[player tournaments] objectAtIndex: indexPath.row] tournamentState] isEqualToString:@"1"]) {
                cell.detailTextLabel.text = [NSString stringWithFormat: @"Registration is open until %@", [[[player tournaments] objectAtIndex: indexPath.row] date]];
            } else {
                cell.detailTextLabel.text = [NSString stringWithFormat: @"Tournament started. Current round: %@", [[[player tournaments] objectAtIndex: indexPath.row] round]];
            }
        }
        [tmpStr addAttribute:NSForegroundColorAttributeName value:statusColor range:NSMakeRange(0, 1)];
        //        [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
        cell.textLabel.attributedText = tmpStr;
        [cell setUserInteractionEnabled:YES];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
    
    if (indexPath.section == KOTHSECTION) {
        cell = [tableView dequeueReusableCellWithIdentifier: @"kingOfTheHill"];
        if (!cell) {
            cell = [[GameTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"kingOfTheHill"];
        }
        tmpStr = [[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat:@"\u25CF  %@ ", [[[player hills] objectAtIndex: indexPath.row] game]]];
        [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:25] range:NSMakeRange(0, 1)];
        long len = [[[[player hills] objectAtIndex: indexPath.row] game] length];
        [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue" size: 16] range:NSMakeRange([tmpStr length] - 1 - len, len)];
        UIColor *statusColor;
        if (![[[player hills] objectAtIndex: indexPath.row] member]) {
            statusColor = [UIColor orangeColor];
        } else {
            statusColor = [UIColor greenColor];
        }
        [tmpStr addAttribute:NSForegroundColorAttributeName value:statusColor range:NSMakeRange(0, 1)];
        if ([[[player hills] objectAtIndex: indexPath.row] king]) {
            NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
            textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
            NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
//            cell.ratingLabel.attributedText = crownStr;
            [tmpStr appendAttributedString:crownStr];
        }
        cell.textLabel.attributedText = tmpStr;
        if ([[[[player hills] objectAtIndex: indexPath.row] currentKing] length] > 0) {
            tmpStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat: @" %@ players ruled by %@ ", [[[player hills] objectAtIndex: indexPath.row] numPlayers], [[[player hills] objectAtIndex: indexPath.row] currentKing]]];
            NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
            textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
            NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
            //            cell.ratingLabel.attributedText = crownStr;
            [tmpStr appendAttributedString:crownStr];
        } else {
            tmpStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat: @" Number of players: %@", [[[player hills] objectAtIndex: indexPath.row] numPlayers]]];
        }
        cell.detailTextLabel.attributedText = tmpStr;
        [cell setUserInteractionEnabled:YES];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    }
    
//    NSLog(@"kittyfontcell %@",cell.textLabel.font);
//    [cell.textLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size:17.f]];
    [cell.detailTextLabel setFont:[UIFont fontWithName:@"Helvetica Neue" size:14.f]];
    [cell.detailTextLabel setTextColor:[UIColor grayColor]];
//    [cell.detailTextLabel setAlpha:0.7];
    return cell;

}


- (void) sectionTap:(UIGestureRecognizer *)gestureRecognizer {
    
    [TSMessage dismissActiveNotification];

//    NSLog(@"kittySection %i",gestureRecognizer.view.tag);
    int section = (int) gestureRecognizer.view.tag;
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
            sectionArray = [player messages];
            break;
        case INVITATIONSSECTION:
            if (selectedInvitationIndexPath && !invitationsReceivedCollapsed) {
                [[self.tableView cellForRowAtIndexPath:selectedInvitationIndexPath] setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                [self.tableView beginUpdates];
                [self removeButtonsFromCell];
                selectedInvitationIndexPath = nil;
                selectedInvitationCell = nil;
                [self.tableView endUpdates];
            }
            invitationsReceivedCollapsed = !invitationsReceivedCollapsed;
            [defaults setBool:invitationsReceivedCollapsed forKey:@"invitationsReceivedCollapsed"];
            collapse = invitationsReceivedCollapsed;
            sectionArray = [player invitations];
            break;
        case ACTIVEGAMESSECTION:
            activeGamesCollapsed = !activeGamesCollapsed;
            [defaults setBool:activeGamesCollapsed forKey:@"activeGamesCollapsed"];
            collapse = activeGamesCollapsed;
            sectionArray = [player activeGames];
            break;
        case PUBLICINVITATIONSSECTION:
            if (selectedPublicInvitationIndexPath && !publicInvitationsCollapsed) {
                [[self.tableView cellForRowAtIndexPath:selectedPublicInvitationIndexPath] setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                [self.tableView beginUpdates];
                [self removeButtonsFromPublicInvitationsCell];
                selectedPublicInvitationIndexPath = nil;
                selectedPublicInvitationCell = nil;
                [self.tableView endUpdates];
            }
            publicInvitationsCollapsed = !publicInvitationsCollapsed;
            [defaults setBool:publicInvitationsCollapsed forKey:@"publicInvitationsCollapsed"];
            collapse = publicInvitationsCollapsed;
            sectionArray = [player publicInvitations];
            break;
        case SENTINVITATIONSSECTION:
            sentInvitationsCollapsed = !sentInvitationsCollapsed;
            [defaults setBool:sentInvitationsCollapsed forKey:@"sentInvitationsCollapsed"];
            collapse = sentInvitationsCollapsed;
            sectionArray = [player sentInvitations];
            break;
        case NONACTIVEGAMESSECTION:
            nonActiveGamesCollapsed = !nonActiveGamesCollapsed;
            [defaults setBool:nonActiveGamesCollapsed forKey:@"nonActiveGamesCollapsed"];
            collapse = nonActiveGamesCollapsed;
            sectionArray = [player nonActiveGames];
            break;
        case TOURNAMENTSSECTION:
            tournamentsCollapsed = !tournamentsCollapsed;
            [defaults setBool:tournamentsCollapsed forKey:@"tournamentsCollapsed"];
            collapse = tournamentsCollapsed;
            sectionArray = [player tournaments];
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
    for(int i = 0; i < [sectionArray count]; ++i) {
        [indexSet addObject:[NSIndexPath indexPathForRow:i inSection:section]];
    }
    [CATransaction begin];
    [self.tableView beginUpdates];
    [CATransaction setCompletionBlock: ^{
        //            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.05];
//        [self.tableView performSelector:@selector(reloadData) withObject: nil afterDelay:0.011];
        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.00];
    }];
        if (collapse) {
            [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
        } else {
            [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
        }
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:gestureRecognizer.view.tag] withRowAnimation:UITableViewRowAnimationFade];
//    [[self.tableView headerViewForSection:gestureRecognizer.view.tag] setNeedsLayout];
//    [[self.tableView headerViewForSection:gestureRecognizer.view.tag] setNeedsDisplay];
    [self.tableView endUpdates];
    [CATransaction commit];

}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
//    NSLog(@"kitttttttyyyyyyyyy %i", section);
    
    UITapGestureRecognizer *sectionTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(sectionTap:)];
    [sectionTapRecogniser setDelegate: self];
    sectionTapRecogniser.numberOfTouchesRequired = 1;
    sectionTapRecogniser.numberOfTapsRequired = 1;

    UILabel *headerLabel;
    UILabel *collapsedLabel;
    UIView *sectionHeaderView = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:@"Header"];
//    [self.tableView headerViewForSection:section];
    if (sectionHeaderView == nil) {
//        NSLog(@"kitten %i", section);
        sectionHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, tableView.sectionHeaderHeight)];
        sectionHeaderView.userInteractionEnabled = YES;
        sectionHeaderView.tag = section;
        sectionHeaderView.restorationIdentifier = @"Header";

        UIImageView *backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, -1, tableView.bounds.size.width, 23)];

        headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 2, tableView.bounds.size.width-40, 18)];
        headerLabel.backgroundColor = [UIColor clearColor];
        headerLabel.textColor = [UIColor whiteColor];
        headerLabel.shadowColor = [UIColor darkGrayColor];
        headerLabel.shadowOffset = CGSizeMake(0, 1);
        headerLabel.font = [UIFont systemFontOfSize:15.0f];
        headerLabel.text = [self tableView:tableView titleForHeaderInSection:section];
        headerLabel.tag = 0;
        collapsedLabel = [[UILabel alloc] initWithFrame:CGRectMake(tableView.bounds.size.width-40, 2, 40, 18)];
        collapsedLabel.center = CGPointMake(tableView.bounds.size.width-20, 11);
        collapsedLabel.backgroundColor = [UIColor clearColor];
        collapsedLabel.textColor = [UIColor whiteColor];
        collapsedLabel.shadowColor = [UIColor darkGrayColor];
        collapsedLabel.shadowOffset = CGSizeMake(0, 1);
        //    collapsedLabel.font = [UIFont boldSystemFontOfSize:18];
        [collapsedLabel setFont:[UIFont fontWithName:@"CourierNewPS-BoldMT" size:17.0f]];
        collapsedLabel.tag = 1;

    
        [sectionHeaderView addSubview:backgroundImageView];
        [sectionHeaderView addSubview:headerLabel];
        [sectionHeaderView addSubview:collapsedLabel];
        [sectionHeaderView addGestureRecognizer:sectionTapRecogniser];
    }
    
    for (UIView *label in sectionHeaderView.subviews){
        if([label isKindOfClass:[UILabel class]]){
            if (label.tag == 0) {
                headerLabel = (UILabel *) label;
            } else if (label.tag == 1) {
                collapsedLabel = (UILabel *) label;
            }
        }
    }
//    sectionHeaderView.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    
    //    backgroundImageView.image = [UIImage imageNamed:@"PlainTableViewSectionHeader.png"];

    
    
    switch (section) {
        case MESSAGESSECTION:
            if (messagesCollapsed) collapsedLabel.text = @"(+)"; else collapsedLabel.text = @"(-)";
            break;
        case INVITATIONSSECTION:
            if (invitationsReceivedCollapsed) collapsedLabel.text = @"(+)"; else collapsedLabel.text = @"(-)";
            break;
        case ACTIVEGAMESSECTION:
            if (activeGamesCollapsed) collapsedLabel.text = @"(+)"; else collapsedLabel.text = @"(-)";
            break;
        case PUBLICINVITATIONSSECTION:
            if (publicInvitationsCollapsed) collapsedLabel.text = @"(+)"; else collapsedLabel.text = @"(-)";
            break;
        case SENTINVITATIONSSECTION:
            if (sentInvitationsCollapsed) collapsedLabel.text = @"(+)"; else collapsedLabel.text = @"(-)";
            break;
        case NONACTIVEGAMESSECTION:
            if (nonActiveGamesCollapsed) collapsedLabel.text = @"(+)"; else collapsedLabel.text = @"(-)";
            break;
        case TOURNAMENTSSECTION:
            if (tournamentsCollapsed) collapsedLabel.text = @"(+)"; else collapsedLabel.text = @"(-)";
            break;
        case KOTHSECTION:
            if (kothCollapsed) collapsedLabel.text = @"(+)"; else collapsedLabel.text = @"(-)";
            break;
            
        default:
            collapsedLabel.text = @"+-";
            break;
    }
    
    BOOL unread = NO;
    for (Message *message in [player messages]) {
        unread = [message.unread isEqualToString:@"unread"];
        if (unread) {
            break;
        }
    }
    BOOL king = NO;
    for (KingOfTheHill *hill in [player hills]) {
        if ([hill king]) {
            king = YES;
            break;
        }
    }
    if ((section == MESSAGESSECTION) && (unread)) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0f green:0.5f blue:0 alpha:1.0]];
    } else if ((section == INVITATIONSSECTION) && ([[player invitations] count] > 0)) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0f green:0.5f blue:0 alpha:1.0]];
    } else if ((section == ACTIVEGAMESSECTION) && ([[player activeGames] count] > 0)) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0f green:0.5f blue:0 alpha:1.0]];
    } else if ((section == KOTHSECTION) && king) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0f green:0.5f blue:0 alpha:1.0]];
    } else {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:(8.0/255) green:(52.0/255) blue:(29.0/255) alpha:1.0]];
    }
    
    return sectionHeaderView;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if(section == MESSAGESSECTION)    {
        return [NSString stringWithFormat: @"Messages (%lu)",(unsigned long)[[player messages] count]];
    }
    else if(section == INVITATIONSSECTION)    {
        return [NSString stringWithFormat: @"Invitations (%lu)",(unsigned long)[[player invitations] count]];
    }
    else if(section == ACTIVEGAMESSECTION)    {
        return [NSString stringWithFormat: @"Active Games (%lu)",(unsigned long)[[player activeGames] count]];
    }
    else if(section == PUBLICINVITATIONSSECTION)    {
        return [NSString stringWithFormat: @"Public Invitations (%lu)",(unsigned long)[[player publicInvitations] count]];
    }
    else if(section == SENTINVITATIONSSECTION)    {
        return [NSString stringWithFormat: @"Invitations Sent (%lu)",(unsigned long)[[player sentInvitations] count]];
    }
    else if(section == NONACTIVEGAMESSECTION)    {
        return [NSString stringWithFormat: @"Non-Active Games (%lu)",(unsigned long)[[player nonActiveGames] count]];
    }
    else if (section == TOURNAMENTSSECTION)   {
        return [NSString stringWithFormat: @"Tournaments (%lu)",(unsigned long)[[player tournaments] count]];
    } else if (section == KOTHSECTION) {
        return [NSString stringWithFormat: @"King of the Hill (%lu)",(unsigned long)[[player hills] count]];
    }
    return @"uh-oh";
}



/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    self.tableView.layer.borderWidth = 0.0;
    
    if (selectedInvitationIndexPath) {
        [[self.tableView cellForRowAtIndexPath:selectedInvitationIndexPath] setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [self.tableView beginUpdates];
        [self removeButtonsFromCell];
        selectedInvitationIndexPath = nil;
        [self.tableView endUpdates];
    }
    if (selectedPublicInvitationIndexPath) {
        [[self.tableView cellForRowAtIndexPath:selectedPublicInvitationIndexPath] setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [self.tableView beginUpdates];
        [self removeButtonsFromPublicInvitationsCell];
        selectedPublicInvitationIndexPath = nil;
        [self.tableView endUpdates];
    }
    if([segue.identifier isEqualToString:@"gameTap"]){
        boardController = (BoardViewController *)segue.destinationViewController;
        [boardController setShowAds: showAds];
    }
    if([segue.identifier isEqualToString:@"messagesTap"]){
        messagesViewController = (MessagesViewController *)segue.destinationViewController;
        [messagesViewController setShowAds:showAds];
    }
    if([segue.identifier isEqualToString:@"addInvitationsTap"]){
        invitationsViewController = (InvitationsViewController *)segue.destinationViewController;
        long count = [[player activeGames] count] + [[player nonActiveGames] count];
        for (Game *game in [player sentInvitations]) {
//            NSLog(@"kitty %@", [game opponentName]);
            if ([[game opponentName] isEqualToString:@"Anyone"]) {
//                NSLog(@"kitty anyone");
                continue;
            }
            if ([[game ratedNot] isEqualToString:@"rated"]) {
                count += 2;
            } else {
                ++count;
            }
        }
        if (count > gamesLimit) {
//            NSLog(@"kitty1 yes");
            [invitationsViewController setOpenInvitationOnly: YES];
        } else {
//            NSLog(@"kitty1 no");
            [invitationsViewController setOpenInvitationOnly: NO];
        }
    }
    if([segue.identifier isEqualToString:@"MMAItap"]){
        [(MMAIViewController *)segue.destinationViewController setShowAds:showAds];
    }
    
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
//    NSLog(@"kitty 1");
    return YES;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
    
    [TSMessage dismissActiveNotification];
    
    
    if (indexPath.section == MESSAGESSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock: ^{
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
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

        PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
        [navControllor setDeletedMessageRow: (int) indexPath.row];

        [self performSegueWithIdentifier:@"messagesTap" sender:self];
        
        [messagesViewController setPlayer:player];
        [messagesViewController setGamesLimit: gamesLimit];
        [messagesViewController setMessageID:[[[player messages] objectAtIndex:indexPath.row] messageID]];
        [messagesViewController setAuthor:[[[player messages] objectAtIndex:indexPath.row] author]];
        [messagesViewController setSubject:[[[player messages] objectAtIndex:indexPath.row] subject]];
        if ([[[[player messages] objectAtIndex:indexPath.row] unread] isEqualToString:@"unread"]) {
            [[[player messages] objectAtIndex:indexPath.row] setUnread:@"read"];
            [self.tableView reloadData];
        }
    }
    if (indexPath.section == INVITATIONSSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock: ^{
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
            if (selectedPublicInvitationIndexPath) {
                [self removeButtonsFromPublicInvitationsCell];
//                [tableView beginUpdates];
                selectedPublicInvitationIndexPath = nil;
                selectedPublicInvitationCell = nil;
//                [tableView endUpdates];
            }
            GameTableViewCell *cell = (GameTableViewCell *) [tableView cellForRowAtIndexPath:indexPath];
            if (selectedInvitationIndexPath) {
                if ((selectedInvitationIndexPath.section == indexPath.section) && (selectedInvitationIndexPath.row == indexPath.row)) {
                    [self removeButtonsFromCell];
//                    [tableView beginUpdates];
                    selectedInvitationIndexPath = nil;
                    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
//                    [tableView endUpdates];

                } else {
                    [self removeButtonsFromCell];
                    GameTableViewCell *tmpCell = (GameTableViewCell *) [tableView cellForRowAtIndexPath:selectedInvitationIndexPath];
                    [tmpCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];

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
            selectedGame = [[player invitations] objectAtIndex: indexPath.row];

        [self.tableView endUpdates];
        [CATransaction commit];

    }
    if (indexPath.section == ACTIVEGAMESSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock: ^{
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
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
        selectedGame = [[player activeGames] objectAtIndex: indexPath.row];
        [self performSegueWithIdentifier:@"gameTap" sender:self];
        [boardController setShowAds: showAds];
        [boardController setGame:selectedGame];
        [boardController setActiveGame:YES];
        [boardController replayGame];
        [[boardController boardTapRecognizer] setEnabled:YES];
    }
    if (indexPath.section == PUBLICINVITATIONSSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock: ^{
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
            if (selectedInvitationIndexPath) {
                [self removeButtonsFromCell];
//                [tableView beginUpdates];
                selectedInvitationIndexPath = nil;
                selectedInvitationCell = nil;
//                [tableView endUpdates];
            }

            GameTableViewCell *cell = (GameTableViewCell *) [tableView cellForRowAtIndexPath:indexPath];
            if (selectedPublicInvitationIndexPath) {
                if ((selectedPublicInvitationIndexPath.section == indexPath.section) && (selectedPublicInvitationIndexPath.row == indexPath.row)) {
                    [self removeButtonsFromPublicInvitationsCell];
                    //                [tableView performSelector:@selector(beginUpdates) withObject: nil afterDelay:0.1];
//                    [tableView beginUpdates];
                    selectedPublicInvitationIndexPath = nil;
                    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                    //                [cell layoutSubviews];
//                    [tableView endUpdates];
                    
                } else {
                    [self removeButtonsFromPublicInvitationsCell];
                    GameTableViewCell *tmpCell = (GameTableViewCell *) [tableView cellForRowAtIndexPath:selectedPublicInvitationIndexPath];
                    [tmpCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                    
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
                [self addButtonsToPublicInvitationsCell: cell];
                selectedPublicInvitationCell = cell;
            }
            selectedGame = [[player publicInvitations] objectAtIndex: indexPath.row];
        [self.tableView endUpdates];
        [CATransaction commit];
        
    
    }
    if (indexPath.section == NONACTIVEGAMESSECTION) {
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock: ^{
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
            if (selectedInvitationIndexPath) {
                [self removeButtonsFromCell];
//                [tableView beginUpdates];
                selectedInvitationIndexPath = nil;
//                [tableView endUpdates];
                selectedInvitationCell = nil;
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
        
        selectedGame = [[player nonActiveGames] objectAtIndex: indexPath.row];
        [boardController setShowAds: showAds];
        [boardController setActiveGame:NO];
        [boardController setGame:selectedGame];
        [boardController replayGame];
        [[boardController boardTapRecognizer] setEnabled:YES];
//        [[boardController boardTapRecognizer] setEnabled: NO];
    }
    
    if (indexPath.section == TOURNAMENTSSECTION) {
        NSString *url = @"https://www.google.com";
        if ([[[[player tournaments] objectAtIndex: indexPath.row] tournamentState] isEqualToString:@"2"]) {
            url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tournaments/status.jsp?eid=%@", [[[player tournaments] objectAtIndex: indexPath.row] tournamentID]];
//            url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/tournaments/status.jsp?eid=%@", [[[player tournaments] objectAtIndex: indexPath.row] tournamentID]];
        } else if ([[[[player tournaments] objectAtIndex: indexPath.row] tournamentState] isEqualToString:@"1"]) {
            url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tournaments/tournamentConfirm.jsp?eid=%@", [[[player tournaments] objectAtIndex: indexPath.row] tournamentID]];
//            url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/tournaments/tournamentConfirm.jsp?eid=%@", [[[player tournaments] objectAtIndex: indexPath.row] tournamentID]];
        } else {
            url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tournaments/statusRound.jsp?eid=%@&round=%@", [[[player tournaments] objectAtIndex: indexPath.row] tournamentID], [[[player tournaments] objectAtIndex: indexPath.row] round]];
//            url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/tournaments/statusRound.jsp?eid=%@&round=%@", [[[player tournaments] objectAtIndex: indexPath.row] tournamentID], [[[player tournaments] objectAtIndex: indexPath.row] round]];
        }
        SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress: url];
        [self.navigationController pushViewController:webViewController animated:YES];

    }
    
    if (indexPath.section == KOTHSECTION) {
        KOTHTableViewController *vc = [[KOTHTableViewController alloc] init];
        [vc setHillSummary: [[player hills] objectAtIndex: indexPath.row]];
        [vc setPlayer: player];
        [vc setTitle:[[[player hills] objectAtIndex:indexPath.row] game]];
        [self.navigationController pushViewController:vc animated:YES];
    }
    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.305];
}



-(void) postToPenteOrgUrl: (NSDictionary *) urlAndPostString {
//    NSLog(@"kitty");
    
    NSString *url = [urlAndPostString objectForKey:@"url"];
    NSString *postString = [urlAndPostString objectForKey:@"postString"];
    
    NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    
//    [request setHTTPShouldUsePipelining: YES];

    NSURLResponse *response;
    NSError *error;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    //    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    //    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
}

-(void) acceptInvitation: (UIButton *) sender {
    long count = [[player activeGames] count] + [[player nonActiveGames] count];
    for (Game *game in [player sentInvitations]) {
        if ([[game ratedNot] isEqualToString:@"rated"]) {
            count += 2;
        } else {
            ++count;
        }
    }
    if (count > gamesLimit) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New account limit reached." message:@"You cannot accept more games. You can, however, play more games by posting open invitations. \n This limit will gradually increase as you finish more games." delegate:self cancelButtonTitle:@"Got it." otherButtonTitles: nil];
        [alert setTag: 2];
        [alert show];
        return;
    }

    self.tableView.layer.borderWidth = 1.5;

    NSIndexPath *tmpPath = selectedInvitationIndexPath;
    
    NSString *url = @"https://www.pente.org/gameServer/tb/replyInvitation";
    NSString *postString = [NSString stringWithFormat:@"sid=%@&inviteeMessage=&command=Accept&mobile=",[[player.invitations objectAtIndex:tmpPath.row] gameID]];
    NSDictionary *urlAndPostString = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:url,postString,nil] forKeys: [NSArray arrayWithObjects:@"url",@"postString",nil]];
    [NSThread detachNewThreadSelector:@selector(postToPenteOrgUrl:) toTarget:self withObject:urlAndPostString];

    NSString *newFriend = [[player.invitations objectAtIndex:tmpPath.row] opponentName];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *toHistory = [[defaults objectForKey:@"invitedHistory"] mutableCopy];
    if (toHistory) {
        int i = 0;
        for ( i = 0; i < [toHistory count]; ++i) {
            if ([[toHistory objectAtIndex:i] localizedCaseInsensitiveCompare: newFriend] == NSOrderedDescending)
                break;
        }
        if (![toHistory containsObject:newFriend]) {
            [toHistory insertObject:newFriend atIndex:i];
        }
    } else {
        toHistory = [NSMutableArray arrayWithObject:newFriend];
    }
    [defaults setObject:toHistory forKey:@"invitedHistory"];

    
    if (showAds) {
        if ([self.interstitial isReady]) {
            [self.interstitial presentFromRootViewController:self];
        }
    }
    [UIView animateWithDuration:0.3 animations:^{
        [self removeButtonsFromCell];
        [self.tableView beginUpdates];
        selectedInvitationIndexPath = nil;
        [self.tableView endUpdates];
        selectedInvitationCell = nil;
    } completion:^(BOOL finished){
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
    }];

    [player.invitations removeObjectAtIndex:tmpPath.row];
    [UIView animateWithDuration:0.3 animations:^{[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject: tmpPath] withRowAnimation:UITableViewRowAnimationFade];} completion:^(BOOL finished){
        [self dashboardParse];
}];

}

-(void) rejectInvitation: (UIButton *) sender {
//    [self.tableView setUserInteractionEnabled: NO];
    self.tableView.layer.borderWidth = 1.5;

    NSIndexPath *tmpPath = selectedInvitationIndexPath;

    NSString *post = [NSString stringWithFormat:@"sid=%@&inviteeMessage=&command=Decline&mobile=",[[player.invitations objectAtIndex:tmpPath.row] gameID]];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:@"https://www.pente.org/gameServer/tb/replyInvitation"]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    
//    [request setHTTPShouldUsePipelining: YES];
    
    NSURLResponse *response;
    NSError *error;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    //    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    //    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

    [UIView animateWithDuration:0.3 animations:^{
        [self removeButtonsFromCell];
        [self.tableView beginUpdates];
        selectedInvitationIndexPath = nil;
        [self.tableView endUpdates];
        selectedInvitationCell = nil;
    } completion:^(BOOL finished){
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        //[self parseDashboard];
    }];

    [player.invitations removeObjectAtIndex:tmpPath.row];
    
    [UIView animateWithDuration:0.3 animations:^{[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject: tmpPath] withRowAnimation:UITableViewRowAnimationFade];} completion:^(BOOL finished){ [self dashboardParse];
}];
}

-(void) cancelInvitation: (UIButton *) sender {
    [CATransaction begin];
    [self.tableView beginUpdates];
    [CATransaction setCompletionBlock: ^{
        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
    }];
        [selectedInvitationCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [self removeButtonsFromCell];
//        [self.tableView beginUpdates];
        selectedInvitationIndexPath = nil;
//        [self.tableView endUpdates];
        selectedInvitationCell = nil;
    [self.tableView endUpdates];
    [CATransaction commit];
}

-(void) addButtonsToCell: (GameTableViewCell *) cell {
    
    cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelButton.backgroundColor = [UIColor clearColor];
    cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [cancelButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [cancelButton setTitle:@"cancel" forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelInvitation:) forControlEvents:UIControlEventTouchUpInside];
    
    acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
    acceptButton.backgroundColor = [UIColor clearColor];
    acceptButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [acceptButton setTitleColor:[UIColor colorWithRed:0 green:0.259 blue:0.145 alpha:1] forState:UIControlStateNormal];
    [acceptButton setTitle:@"accept" forState:UIControlStateNormal];
    [acceptButton addTarget:self action:@selector(acceptInvitation:) forControlEvents:UIControlEventTouchUpInside];
    
    rejectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rejectButton.backgroundColor = [UIColor clearColor];
    rejectButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [rejectButton setTitleColor:[UIColor colorWithRed:0.698 green:0.133 blue:0.133 alpha:1] forState:UIControlStateNormal];
    [rejectButton setTitle:@"decline" forState:UIControlStateNormal];
    [rejectButton addTarget:self action:@selector(rejectInvitation:) forControlEvents:UIControlEventTouchUpInside];
    
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width, spacing;
    
    NSDictionary *fontAttributes = [NSDictionary dictionaryWithObject:[acceptButton.titleLabel font] forKey:NSFontAttributeName];
    CGSize cancelFontSize = [cancelButton.titleLabel.text sizeWithAttributes:fontAttributes], acceptFontSize = [acceptButton.titleLabel.text sizeWithAttributes:fontAttributes], rejectFontSize = [rejectButton.titleLabel.text sizeWithAttributes:fontAttributes];
    
    spacing = (screenWidth - cancelFontSize.width - acceptFontSize.width - rejectFontSize.width - 45)/4;
    
    CGRect buttonFrame = CGRectMake(spacing, 45, cancelFontSize.width + 15.0, cancelFontSize.height + 10);
    [cancelButton setFrame:buttonFrame];
    buttonFrame = CGRectMake(2*spacing + cancelButton.frame.size.width, 45, acceptFontSize.width + 15.0, acceptFontSize.height + 10);
    [acceptButton setFrame:buttonFrame];
    buttonFrame = CGRectMake(3*spacing + cancelButton.frame.size.width + acceptButton.frame.size.width, 45, rejectFontSize.width + 15.0, rejectFontSize.height + 10);
    [rejectButton setFrame:buttonFrame];
    
    [cell performSelector:@selector(addSubview:) withObject: acceptButton afterDelay:0.25];
    [cell performSelector:@selector(addSubview:) withObject: cancelButton afterDelay:0.2];
    [cell performSelector:@selector(addSubview:) withObject: rejectButton afterDelay:0.3];
    
}

-(void) removeButtonsFromCell {
    [rejectButton performSelector:@selector(removeFromSuperview) withObject: nil afterDelay:0.05];
    [acceptButton performSelector:@selector(removeFromSuperview) withObject: nil afterDelay:0.1];
    [cancelButton performSelector:@selector(removeFromSuperview) withObject: nil afterDelay:0.15];
}


-(void) acceptPublicInvitation: (UIButton *) sender {
    if (!player.subscriber) {
        long openInvitationsLimit = [[NSUserDefaults standardUserDefaults] integerForKey:@"openInvitationsLimit"];
        if (openInvitationsLimit <= 1) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Open invitations limit reached" message:@"After taking 2 open invitations, you have to post one before you can accept 2 more.\n To post an open invitation, press the play button and leave the opponent field blank." delegate:self cancelButtonTitle:@"Got it." otherButtonTitles: nil];
            [alert setTag: 2];
            [alert show];
            return;
        }
        if (openInvitationsLimit > 1) {
            --openInvitationsLimit;
            [[NSUserDefaults standardUserDefaults] setInteger: openInvitationsLimit forKey:@"openInvitationsLimit"];
        }
    }
    
//    long count = [[player activeGames] count] + [[player nonActiveGames] count];
//    for (Game *game in [player sentInvitations]) {
//        if ([[game ratedNot] isEqualToString:@"rated"]) {
//            count += 2;
//        } else {
//            ++count;
//        }
//    }
//    if (count > gamesLimit) {
//        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New account limit reached." message:@"You cannot accept more games. You can, however, play more games by posting open invitations. \n This limit will gradually increase as you finish more games." delegate:self cancelButtonTitle:@"Got it." otherButtonTitles: nil];
//        [alert setTag: 2];
//        [alert show];
//        return;
//    }
    
    self.tableView.layer.borderWidth = 1.5;
    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView];

    NSString *url = @"https://www.pente.org/gameServer/tb/replyInvitation";
    NSString *postString = [NSString stringWithFormat:@"sid=%@&inviteeMessage=&command=Accept&mobile=",[[player.publicInvitations objectAtIndex:selectedPublicInvitationIndexPath.row] gameID]];
    NSDictionary *urlAndPostString = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:url,postString,nil] forKeys: [NSArray arrayWithObjects:@"url",@"postString",nil]];
    [NSThread detachNewThreadSelector:@selector(postToPenteOrgUrl:) toTarget:self withObject:urlAndPostString];

    NSString *newFriend = [[player.publicInvitations objectAtIndex:selectedPublicInvitationIndexPath.row] opponentName];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray<NSString *> *toHistory = [[defaults objectForKey:@"invitedHistory"] mutableCopy];
    if (toHistory) {
        int i = 0;
        for ( i = 0; i < [toHistory count]; ++i) {
            if ([[toHistory objectAtIndex:i] localizedCaseInsensitiveCompare: newFriend] == NSOrderedDescending)
                break;
        }
        if (![toHistory containsObject:newFriend]) {
            [toHistory insertObject:newFriend atIndex:i];
        }
    } else {
        toHistory = [NSMutableArray arrayWithObject:newFriend];
    }
    [defaults setObject:toHistory forKey:@"invitedHistory"];

    if (showAds) {
        if ([self.interstitial isReady]) {
            [self.interstitial presentFromRootViewController:self];
        }
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock: ^{
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
            [self removeButtonsFromPublicInvitationsCell];
    //        [self.tableView beginUpdates];
            selectedPublicInvitationIndexPath = nil;
    //        [self.tableView endUpdates];
            selectedPublicInvitationCell = nil;
        [self.tableView endUpdates];
        [CATransaction commit];
        [self dashboardParse];
    } else {
    
        NSIndexPath *tmpPath = selectedPublicInvitationIndexPath;
        [UIView animateWithDuration:0.3 animations:^{
            [self removeButtonsFromPublicInvitationsCell];
            [self.tableView beginUpdates];
            selectedPublicInvitationIndexPath = nil;
            [self.tableView endUpdates];
            selectedPublicInvitationCell = nil;
        } completion:^(BOOL finished){
                [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
    
        [player.publicInvitations removeObjectAtIndex:tmpPath.row];
        [UIView animateWithDuration:0.3 animations:^{[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject: tmpPath] withRowAnimation:UITableViewRowAnimationFade];} completion:^(BOOL finished){
            [self dashboardParse];
            //        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.4];
        }];
    }
    //    [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:tmpPath] withRowAnimation:UITableViewRowAnimationFade];
    //    [self performSelector:@selector(parseDashboard) withObject: nil afterDelay:0.7];
    //    [self.tableView performSelector:@selector(reloadData) withObject: nil afterDelay:0.7];
    //    [self performSelector:@selector(parseDashboard) withObject: nil afterDelay:0.5];
    //    [self.tableView performSelector:@selector(reloadData) withObject: nil afterDelay:0.5];
}

-(void) cancelPublicInvitation: (UIButton *) sender {
    long openInvitationsLimit = [[NSUserDefaults standardUserDefaults] integerForKey:@"openInvitationsLimit"];
    if (openInvitationsLimit > 2) {
        openInvitationsLimit -= 2;
    } else if (openInvitationsLimit == 2) {
        openInvitationsLimit = 1;
    }
    [[NSUserDefaults standardUserDefaults] setInteger: openInvitationsLimit forKey:@"openInvitationsLimit"];

    [CATransaction begin];
    [self.tableView beginUpdates];
    [CATransaction setCompletionBlock: ^{
        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
    }];
        [selectedPublicInvitationCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        [self removeButtonsFromPublicInvitationsCell];
    //    [self.tableView beginUpdates];
        selectedPublicInvitationIndexPath = nil;
    //    [self.tableView endUpdates];
        selectedPublicInvitationCell = nil;
    [self.tableView endUpdates];
    [CATransaction commit];
//    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.32f];
}



-(void) addButtonsToPublicInvitationsCell: (GameTableViewCell *) cell {
    
    cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelButton.backgroundColor = [UIColor clearColor];
    cancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [cancelButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [cancelButton setTitle:@"cancel" forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelPublicInvitation:) forControlEvents:UIControlEventTouchUpInside];
    
    acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
    acceptButton.backgroundColor = [UIColor clearColor];
    acceptButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [acceptButton setTitleColor:[UIColor colorWithRed:0 green:0.259 blue:0.145 alpha:1] forState:UIControlStateNormal];
    [acceptButton setTitle:@"accept" forState:UIControlStateNormal];
    [acceptButton addTarget:self action:@selector(acceptPublicInvitation:) forControlEvents:UIControlEventTouchUpInside];
    

    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width, spacing;
    
    NSDictionary *fontAttributes = [NSDictionary dictionaryWithObject:[acceptButton.titleLabel font] forKey:NSFontAttributeName];
    CGSize cancelFontSize = [cancelButton.titleLabel.text sizeWithAttributes:fontAttributes], acceptFontSize = [acceptButton.titleLabel.text sizeWithAttributes:fontAttributes];
    
    spacing = (screenWidth - cancelFontSize.width - acceptFontSize.width - 45)/3;
    
    CGRect buttonFrame = CGRectMake(spacing, 45, cancelFontSize.width + 15.0, cancelFontSize.height + 10);
    [cancelButton setFrame:buttonFrame];
    buttonFrame = CGRectMake(2*spacing + cancelButton.frame.size.width, 45, acceptFontSize.width + 15.0, acceptFontSize.height + 10);
    [acceptButton setFrame:buttonFrame];
    
    [cell performSelector:@selector(addSubview:) withObject: acceptButton afterDelay:0.25];
    [cell performSelector:@selector(addSubview:) withObject: cancelButton afterDelay:0.2];
   
}

-(void) removeButtonsFromPublicInvitationsCell {
    [acceptButton performSelector:@selector(removeFromSuperview) withObject: nil afterDelay:0.05];
    [cancelButton performSelector:@selector(removeFromSuperview) withObject: nil afterDelay:0.1];
}

- (void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == PUBLICINVITATIONSSECTION) {
        [[tableView cellForRowAtIndexPath:indexPath] layoutSubviews];
        
    }
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((indexPath.section == PUBLICINVITATIONSSECTION) || (indexPath.section == TOURNAMENTSSECTION)) {
        return NO;
    }
    return YES;
}

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == MESSAGESSECTION) {
        return @"delete";
    }
    if (indexPath.section == ACTIVEGAMESSECTION) {
        return @"resign";
    }
    if (indexPath.section == SENTINVITATIONSSECTION) {
        return @"cancel";
    }
    if (indexPath.section == NONACTIVEGAMESSECTION) {
        return @"cancel set";
    }
    return @"uh-oh";
}


- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ((indexPath.section != PUBLICINVITATIONSSECTION) && (indexPath.section != TOURNAMENTSSECTION)) {
        return  UITableViewCellEditingStyleDelete;
    }
    return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
//    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.tableView beginUpdates];
        selectedInvitationIndexPath = nil;
    selectedInvitationCell = nil;
        [self.tableView endUpdates];
    if (indexPath.section == MESSAGESSECTION) {
        //            [self.tableView setUserInteractionEnabled: NO];
        self.tableView.layer.borderWidth = 1.5;
        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        username = [defaults objectForKey:usernameKey];
        password = [defaults objectForKey:passwordKey];

        NSString *post = [NSString stringWithFormat:@"command=delete&mid=%@&name2=%@&password2=%@&mobile=", [[[player messages] objectAtIndex:indexPath.row] messageID],username,password];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        [request setURL:[NSURL URLWithString:@"https://pente.org/gameServer/mymessages"]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        
        
//        [request setHTTPShouldUsePipelining: YES];
        
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        NSURLResponse *response;
        NSError *error;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//
//        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//        //        [self login];
//        NSLog(@"kitty %@", dashboardString);

        [player.messages removeObjectAtIndex: indexPath.row];
        [UIView animateWithDuration:0.3 animations:^{[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject: indexPath] withRowAnimation:UITableViewRowAnimationFade];
//            [tableView reloadData];
        } completion:^(BOOL finished){
            [self dashboardParse];
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
        //            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        //            [self parseDashboard];
        //            [self.tableView reloadData];
    }
    if (indexPath.section == ACTIVEGAMESSECTION) {
        //            [self.tableView setUserInteractionEnabled: NO];
        self.tableView.layer.borderWidth = 1.5;
        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView];
        NSString *post = [NSString stringWithFormat:@"gid=%@&command=resign&mobile=",[[player.activeGames objectAtIndex:indexPath.row] gameID]];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        [request setURL:[NSURL URLWithString:@"https://www.pente.org/gameServer/tb/resign"]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        
//        [request setHTTPShouldUsePipelining: YES];
        
        NSURLResponse *response;
        NSError *error;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        //    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        //    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        [player.activeGames removeObjectAtIndex:indexPath.row];
        [UIView animateWithDuration:0.3 animations:^{[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject: indexPath] withRowAnimation:UITableViewRowAnimationFade];} completion:^(BOOL finished){
            [self dashboardParse];
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
        //            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        //            [self parseDashboard];
        //            [self.tableView reloadData];
    }
    
    if (indexPath.section == SENTINVITATIONSSECTION) {
        //            [self.tableView setUserInteractionEnabled: NO];
        self.tableView.layer.borderWidth = 1.5;
        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView];
        NSString *post = [NSString stringWithFormat:@"sid=%@&command=Cancel&mobile=",[[player.sentInvitations objectAtIndex:indexPath.row] gameID]];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        [request setURL:[NSURL URLWithString:@"https://www.pente.org/gameServer/tb/cancelInvitation"]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        
//        [request setHTTPShouldUsePipelining: YES];
        
        NSURLResponse *response;
        NSError *error;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        //    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        //    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        [player.sentInvitations removeObjectAtIndex:indexPath.row];
        [UIView animateWithDuration:0.1 animations:^{[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject: indexPath] withRowAnimation:UITableViewRowAnimationFade];} completion:^(BOOL finished){
            [self dashboardParse];
                [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
        //            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
        //            [self parseDashboard];
        //            [self.tableView reloadData];
    }
    if (indexPath.section == NONACTIVEGAMESSECTION) {
        //            [self.tableView setUserInteractionEnabled: NO];
        self.tableView.layer.borderWidth = 1.5;
        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView];

        NSString *tmpStr = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/game?gid=%@&command=load",[[player.nonActiveGames objectAtIndex:indexPath.row] gameID]];
        NSURL *url = [NSURL URLWithString: tmpStr];
        NSError *error;
        NSString *htmlString = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
        NSRange movesRange = NSMakeRange(0,[htmlString length]);
        movesRange = [htmlString rangeOfString: @"     sid=\"" options:0 range:movesRange];
        movesRange.length = [htmlString length] - movesRange.location - 10;
        movesRange.location = movesRange.location + 10;
        NSRange movesRangeEnd = [[htmlString substringWithRange:movesRange] rangeOfString:@"\""];
        movesRange.length = movesRangeEnd.location;
        [[player.nonActiveGames objectAtIndex:indexPath.row] setSetID:[htmlString substringWithRange:movesRange]];

        NSString *post = [NSString stringWithFormat:@"sid=%@&command=request&mobile=",[[player.nonActiveGames objectAtIndex:indexPath.row] setID]];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
//        [request setValue:[NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/cancel?command=confirm&sid=%@&gid=%@&message=", [[player.nonActiveGames objectAtIndex:indexPath.row] setID], [[player.nonActiveGames objectAtIndex:indexPath.row] gameID]]  forHTTPHeaderField:@"referer"];
        [request setURL:[NSURL URLWithString:@"https://www.pente.org/gameServer/tb/cancel"]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        NSURLResponse *response;
//        NSError *error;
//        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        movesRange = NSMakeRange(0,[dashboardString length]);
        movesRange = [dashboardString rangeOfString: @"Error: Cancel request already exists." options:0 range:movesRange];
        if (movesRange.location != NSNotFound) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"A cancel request already exists." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            self.tableView.layer.borderWidth = 0.0;
            [self.tableView setEditing:FALSE animated:TRUE];
        } else {
            [self dashboardParse];
            
        }

    }

//    }
}


-(void) dashboardParse {
    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.05];
    self.tableView.layer.borderWidth = 1.5;
    
    [NSThread detachNewThreadSelector:@selector(parseDashboard) toTarget:self withObject:nil];

}


-(void) parseDashboard {
    
    [self.pullToReloadHeaderView setStatusString:@"Loading Games..." animated:YES];
    [self.pullToReloadHeaderView layoutSubviews];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    username = [defaults objectForKey:usernameKey];
    password = [defaults objectForKey:passwordKey];
    self.tableView.layer.borderWidth = 1.5;
    
  
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url;
    NSURLResponse *response;
    NSError *error;
    NSData *responseData;
    
    // connect to the game server
    url =  [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobile/index.jsp?name=%@&password=%@",username,password];
//    url =  [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobile/index.jsp?name=%@&password=%@&checkname=rbhjury",username,password];
//    url =  [NSString stringWithFormat:@"https://development.pente.org/gameServer/mobile/index.jsp?name=%@&password=%@",username,password];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

    dispatch_async(dispatch_get_main_queue(), ^{
        [CATransaction begin];
        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock: ^{
            self.tableView.layer.borderWidth = 0.0;
            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
//            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.05];
            [self performSelector:@selector(pullDownToReloadActionFinished) withObject:nil];
        }];
        
        
    [self.tableView setUserInteractionEnabled:NO];
    
    if ([dashboardString rangeOfString:@"Invitations received"].location == NSNotFound) {
        self.tableView.layer.borderWidth = 0.0;
        [self.tableView setUserInteractionEnabled:YES];
        return;
    }

    showAds = ([dashboardString rangeOfString:@"No Ads"].location == NSNotFound) || ([dashboardString rangeOfString:@"No Ads"].location > 30);
    [player setShowAds: showAds];
    [player setSubscriber: ([dashboardString rangeOfString:@"tb GamesLimit"].location == NSNotFound) || ([dashboardString rangeOfString:@"tb GamesLimit"].location > 30)];
    if (([dashboardString rangeOfString:@"Unlimited Games"].location != NSNotFound) && ([dashboardString rangeOfString:@"Unlimited Games"].location < 30)) {
        gamesLimit = INT_MAX;
    }
    if (!showAds) {
        [bannerView removeFromSuperview];
        [self.tableView setTableFooterView:nil];
    }
    
    NSArray *splitDash = [dashboardString componentsSeparatedByString:@"\n"];
    NSString *dashLine;
    NSArray *splitLine;
//            NSLog(@"result: %@",dashboardString);
    
        NSMutableArray *sectionItems;
        NSMutableArray *indexSet;
    int dashIDX = 0;
    while ((dashIDX < [splitDash count]) && (![[splitDash objectAtIndex:dashIDX] isEqualToString: @"EndOfSettingsParameters"])) {
        if ([[splitDash objectAtIndex:dashIDX] rangeOfString:@"tbGamesLimit"].location != NSNotFound) {
            dashLine = [splitDash objectAtIndex:dashIDX];
            splitLine = [dashLine componentsSeparatedByString:@";"];
            gamesLimit = [[splitLine objectAtIndex:1] intValue];
            if (gamesLimit == 0) {
                gamesLimit = 200;
            }
//            NSLog(@"kitty");
        }
        dashIDX++;
    }
        
        sectionItems = [[NSMutableArray alloc] init];
        while ((dashIDX < [splitDash count]) && (![[splitDash objectAtIndex:dashIDX] isEqualToString: @"King of the Hill"])) {
            dashIDX++;
        }
        if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"King of the Hill"]) {
            dashIDX++;
            while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Rating Stats"]) && (dashIDX < [splitDash count])) {
                dashLine = [splitDash objectAtIndex:dashIDX];
                splitLine = [dashLine componentsSeparatedByString:@";"];
                KingOfTheHill *hill = [[KingOfTheHill alloc] init];
                [hill setGame: [splitLine objectAtIndex: 0]];
                [hill setNumPlayers: [splitLine objectAtIndex: 1]];
                [hill setMember: [[splitLine objectAtIndex: 2] isEqualToString:@"1"]];
                [hill setKing: [[splitLine objectAtIndex: 3] isEqualToString:@"1"]];
                [hill setCurrentKing: [splitLine objectAtIndex: 4]];
                [sectionItems addObject:hill];
                dashIDX++;
            }
        }
        if ([sectionItems count] != [[player hills] count]) {
            if (!kothCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player hills] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: KOTHSECTION]];
                [player setHills:[[NSMutableArray alloc] init]];
                [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
            [player setHills:sectionItems];
            if (!kothCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player hills] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: KOTHSECTION]];
                [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
        } else {
            [player setHills:sectionItems];
        }

        while ((dashIDX < [splitDash count]) && (![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Rating Stats"])) {
            dashIDX++;
        }
        if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"Rating Stats"]) {
            [[player ratingStats] removeAllObjects];
            dashIDX++;
            while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Invitations received"]) && (dashIDX < [splitDash count])) {
                dashLine = [splitDash objectAtIndex:dashIDX];
                splitLine = [dashLine componentsSeparatedByString:@";"];
                RatingStat *ratingStat = [[RatingStat alloc] init];
                [ratingStat setGame: [splitLine objectAtIndex: 0]];
                [ratingStat setRating: [splitLine objectAtIndex: 1]];
                [ratingStat setTotalGames: [splitLine objectAtIndex: 2]];
                [ratingStat setLastPlayed: [splitLine objectAtIndex: 4]];
                [ratingStat setCrown: [[splitLine objectAtIndex: 3] intValue]];
                [[player ratingStats] addObject:ratingStat];
                dashIDX++;
            }
        }
        sectionItems = [[NSMutableArray alloc] init];
    while ((dashIDX < [splitDash count]) && (![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Invitations received"])) {
        dashIDX++;
    }
    if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"Invitations received"]) {
        dashIDX++;
        while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Invitations sent"]) && (dashIDX < [splitDash count])) {
            dashLine = [splitDash objectAtIndex:dashIDX];
            splitLine = [dashLine componentsSeparatedByString:@";"];
            Game *game = [[Game alloc] init];
            [game setGameID: [splitLine objectAtIndex:0]];
            [game setGameType:[splitLine objectAtIndex:1]];
            [game setOpponentName:[splitLine objectAtIndex:2]];
            [game setOpponentRating:[splitLine objectAtIndex:3]];
            [game setMyColor:[splitLine objectAtIndex:4]];
            [game setRemainingTime:[splitLine objectAtIndex:5]];
            [game setRatedNot:[splitLine objectAtIndex:6]];
            [game setNameColor: UIColorFromRGB([[splitLine objectAtIndex:7] intValue])];
            [game setCrown:[[splitLine objectAtIndex:8] intValue]];
            [sectionItems addObject:game];
            dashIDX++;
        }
    }
        if ([sectionItems count] != [[player invitations] count]) {
            if (!invitationsReceivedCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player invitations] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: INVITATIONSSECTION]];
                [player setInvitations:[[NSMutableArray alloc] init]];
                [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
            [player setInvitations:sectionItems];
            if (!invitationsReceivedCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player invitations] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: INVITATIONSSECTION]];
                [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
        } else {
            [player setInvitations:sectionItems];
        }
        //        [self.tableView reloadData];

    
    sectionItems = [[NSMutableArray alloc] init];
    if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"Invitations sent"]) {
        dashIDX++;
        while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Active Games - My Turn"]) && (dashIDX < [splitDash count])) {
            dashLine = [splitDash objectAtIndex:dashIDX];
            splitLine = [dashLine componentsSeparatedByString:@";"];
            Game *game = [[Game alloc] init];
            [game setGameID: [splitLine objectAtIndex:0]];
            [game setGameType:[splitLine objectAtIndex:1]];
            [game setOpponentName:[splitLine objectAtIndex:2]];
            [game setOpponentRating:[splitLine objectAtIndex:3]];
            [game setMyColor:[splitLine objectAtIndex:4]];
            [game setRemainingTime:[splitLine objectAtIndex:5]];
            [game setRatedNot:[splitLine objectAtIndex:6]];
            [game setNameColor: UIColorFromRGB([[splitLine objectAtIndex:7] intValue])];
            [game setCrown:[[splitLine objectAtIndex:8] intValue]];
            [sectionItems addObject:game];
            dashIDX++;
        }
    }
        if ([sectionItems count] != [[player sentInvitations] count]) {
            if (!sentInvitationsCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player sentInvitations] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: SENTINVITATIONSSECTION]];
                [player setSentInvitations:[[NSMutableArray alloc] init]];
                [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
            [player setSentInvitations:sectionItems];
            if (!sentInvitationsCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player sentInvitations] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: SENTINVITATIONSSECTION]];
                [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
        } else {
            [player setSentInvitations:sectionItems];
        }
        //        [self.tableView reloadData];

        //    [self.tableView reloadData];
    //    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:.63f];
    //    [self performSelectorOnMainThread:@selector(scrollViewDidScroll:) withObject: self.tableView waitUntilDone:YES];
    
    //    [self.tableView beginUpdates];
    //    [self.tableView endUpdates];
    
    
    //    [CATransaction commit];
    
    sectionItems = [[NSMutableArray alloc] init];
    if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"Active Games - My Turn"]) {
        dashIDX++;
        while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Active Games - Opponents Turn"]) && (dashIDX < [splitDash count])) {
            dashLine = [splitDash objectAtIndex:dashIDX];
            splitLine = [dashLine componentsSeparatedByString:@";"];
//                        NSLog(@"kitty %@", splitLine);
            Game *game = [[Game alloc] init];
            [game setGameID: [splitLine objectAtIndex:0]];
            [game setGameType:[splitLine objectAtIndex:1]];
            [game setOpponentName:[splitLine objectAtIndex:2]];
            [game setOpponentRating:[splitLine objectAtIndex:3]];
            [game setMyColor:[[splitLine objectAtIndex:4] substringToIndex:5]];
            [game setRemainingTime:[splitLine objectAtIndex:6]];
            [game setRatedNot:[splitLine objectAtIndex:7]];
            [game setNameColor: UIColorFromRGB([[splitLine objectAtIndex:8] intValue])];
            [game setCrown:[[splitLine objectAtIndex:9] intValue]];
            [sectionItems addObject:game];
            dashIDX++;
        }
    }
        if ([sectionItems count] != [[player activeGames] count]) {
            if (!activeGamesCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player activeGames] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: ACTIVEGAMESSECTION]];
                [player setActiveGames:[[NSMutableArray alloc] init]];
                [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
            [player setActiveGames:sectionItems];
            if (!activeGamesCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player activeGames] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: ACTIVEGAMESSECTION]];
                [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
        } else {
            [player setActiveGames:sectionItems];
        }
        //        [self.tableView reloadData];
    //    [self.tableView reloadData];
    //    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:.63f];
    //    [self performSelectorOnMainThread:@selector(scrollViewDidScroll:) withObject: self.tableView waitUntilDone:YES];
    sectionItems = [[NSMutableArray alloc] init];
    if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"Active Games - Opponents Turn"]) {
        dashIDX++;
        while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Open Invitation Games"]) && (dashIDX < [splitDash count])) {
            dashLine = [splitDash objectAtIndex:dashIDX];
            splitLine = [dashLine componentsSeparatedByString:@";"];
            //                        NSLog(@"kitty %@", splitLine);
            Game *game = [[Game alloc] init];
            [game setGameID: [splitLine objectAtIndex:0]];
            [game setGameType:[splitLine objectAtIndex:1]];
            [game setOpponentName:[splitLine objectAtIndex:2]];
            [game setOpponentRating:[splitLine objectAtIndex:3]];
            [game setMyColor:[[splitLine objectAtIndex:4] substringToIndex:5]];
            [game setRemainingTime:[splitLine objectAtIndex:6]];
            [game setRatedNot:[splitLine objectAtIndex:7]];
            [game setNameColor: UIColorFromRGB([[splitLine objectAtIndex:8] intValue])];
            [game setCrown:[[splitLine objectAtIndex:9] intValue]];
            [sectionItems addObject:game];
            dashIDX++;
        }
    }
        if ([sectionItems count] != [[player nonActiveGames] count]) {
            if (!nonActiveGamesCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player nonActiveGames] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: NONACTIVEGAMESSECTION]];
                [player setNonActiveGames:[[NSMutableArray alloc] init]];
                //    [self performSelectorOnMainThread:@selector(scrollViewDidScroll:) withObject: self.tableView waitUntilDone:YES];
                //                dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
            [player setNonActiveGames:sectionItems];
            if (!nonActiveGamesCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player nonActiveGames] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: NONACTIVEGAMESSECTION]];
                [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
        } else {
            [player setNonActiveGames:sectionItems];
        }
        //        [self.tableView reloadData];
        [self.pullToReloadHeaderView setStatusString:@"Loading Open Invitations..." animated:YES];
        [self.pullToReloadHeaderView layoutSubviews];

        
    //    [self.tableView beginUpdates];
    //    [self.tableView endUpdates];
    
    //    [CATransaction commit];
    
    //    [self.tableView reloadData];
    //    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:.33f];
    //    [self performSelectorOnMainThread:@selector(scrollViewDidScroll:) withObject: self.tableView waitUntilDone:YES];
    
    // load the public games
    
    
    sectionItems = [[NSMutableArray alloc] init];
    if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"Open Invitation Games"]) {
        dashIDX++;
        while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Messages"]) && (dashIDX < [splitDash count])) {
            dashLine = [splitDash objectAtIndex:dashIDX];
            splitLine = [dashLine componentsSeparatedByString:@";"];
            Game *game = [[Game alloc] init];
            [game setGameID: [splitLine objectAtIndex:0]];
            [game setGameType:[splitLine objectAtIndex:1]];
            [game setOpponentName:[splitLine objectAtIndex:2]];
            [game setOpponentRating:[splitLine objectAtIndex:3]];
            [game setMyColor:[splitLine objectAtIndex:4]];
            [game setRemainingTime:[splitLine objectAtIndex:5]];
            [game setRatedNot:[splitLine objectAtIndex:6]];
            [game setNameColor: UIColorFromRGB([[splitLine objectAtIndex:7] intValue])];
            [game setCrown:[[splitLine objectAtIndex:8] intValue]];
            [sectionItems addObject:game];
            dashIDX++;
        }
    }
        if ([sectionItems count] != [[player publicInvitations] count]) {
            if (!publicInvitationsCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player publicInvitations] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: PUBLICINVITATIONSSECTION]];
                [player setPublicInvitations:[[NSMutableArray alloc] init]];
                [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
            [player setPublicInvitations:sectionItems];
            if (!publicInvitationsCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player publicInvitations] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: PUBLICINVITATIONSSECTION]];
                [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
        } else {
            [player setPublicInvitations:sectionItems];
        }
        //        [self.tableView reloadData];
        
        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:.33f];
        [self.pullToReloadHeaderView setStatusString:@"Loading Messages..." animated:YES];
        [self.pullToReloadHeaderView layoutSubviews];


    //    [CATransaction begin];
    //    [CATransaction setCompletionBlock:^{
    //        //    [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    //        [self.tableView reloadData];
    //        //        [self performSelectorOnMainThread:@selector(scrollViewDidScroll:) withObject: self.tableView waitUntilDone:YES];
    //        [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:.65f];
    //    }];
    
    
    sectionItems = [[NSMutableArray alloc] init];
    int unreadMsgs = 0, readMsgs = 0;
    if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"Messages"]) {
        dashIDX++;
        while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @""]) && (dashIDX < [splitDash count]) && ![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Tournaments"]) {
            dashLine = [splitDash objectAtIndex:dashIDX];
            splitLine = [dashLine componentsSeparatedByString:@";"];
            Message *message = [[Message alloc] init];
            [message setMessageID: [splitLine objectAtIndex:0]];
            [message setUnread: [splitLine objectAtIndex:1]];
            [[message unread] isEqualToString:@"read"] ? readMsgs++ : unreadMsgs++;
            [message setSubject: [splitLine objectAtIndex:2]];
            [message setAuthor: [splitLine objectAtIndex:3]];
            [message setTimeStamp: [splitLine objectAtIndex:4]];
            [message setNameColor: UIColorFromRGB([[splitLine objectAtIndex:5] intValue])];
            [message setCrown:[[splitLine objectAtIndex:6] intValue]];
            [sectionItems addObject:message];
            dashIDX++;
        }
    }
        if ([sectionItems count] != [[player messages] count]) {
            NSMutableArray *indexSet;
            if (!messagesCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player messages] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: MESSAGESSECTION]];
                [player setMessages:[[NSMutableArray alloc] init]];
                [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
            [player setMessages:sectionItems];
            if (!messagesCollapsed) {
                indexSet = [[NSMutableArray alloc] init];
                for(int i = 0; i < [[player messages] count]; ++i)
                    [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: MESSAGESSECTION]];
                [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
            }
        } else {
            [player setMessages:sectionItems];
        }

    while ((dashIDX < [splitDash count]) && ![[splitDash objectAtIndex:dashIDX] isEqualToString: @"Tournaments"]) {
        dashIDX++;
    }
    sectionItems = [[NSMutableArray alloc] init];
    if ((dashIDX+1 < [splitDash count]) && [[splitDash objectAtIndex:dashIDX] isEqualToString: @"Tournaments"]) {
        dashIDX++;
        while ((dashIDX < [splitDash count]) && (![[splitDash objectAtIndex:dashIDX] isEqualToString: @""])) {
            dashLine = [splitDash objectAtIndex:dashIDX];
            splitLine = [dashLine componentsSeparatedByString:@";"];
            Tournament *tournament = [[Tournament alloc] init];
            [tournament setName: [splitLine objectAtIndex:0]];
            [tournament setTournamentID: [splitLine objectAtIndex:1]];
            [tournament setRound: [splitLine objectAtIndex:2]];
            [tournament setGame: [splitLine objectAtIndex:3]];
            [tournament setTournamentState: [splitLine objectAtIndex:4]];
            [tournament setDate:[splitLine objectAtIndex:5]];
            [sectionItems addObject: tournament];
            dashIDX++;
        }
    }
    if ([sectionItems count] != [[player tournaments] count]) {
        NSMutableArray *indexSet;
        if (!tournamentsCollapsed) {
            indexSet = [[NSMutableArray alloc] init];
            for(int i = 0; i < [[player tournaments] count]; ++i)
                [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: TOURNAMENTSSECTION]];
            [player setTournaments:[[NSMutableArray alloc] init]];
            [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
        }
        [player setTournaments:sectionItems];
        if (!tournamentsCollapsed) {
            indexSet = [[NSMutableArray alloc] init];
            for(int i = 0; i < [[player tournaments] count]; ++i)
                [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: TOURNAMENTSSECTION]];
            [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
        }
    } else {
        [player setTournaments: sectionItems];
    }
        
        
        
        [self.tableView endUpdates];
        [CATransaction commit];
        [self parseMessages];

    });
}


-(void) messagesParse {
//    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.05];
    self.tableView.layer.borderWidth = 1.5;
    [NSThread detachNewThreadSelector:@selector(parseMessages) toTarget:self withObject:nil];
}


-(void) parseMessages {
    
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    if (navController.receivedNotification) {
//        NSLog(@"kitty  %@", navController.receivedNotification);
        
        Game *notificationGame;
        if ([[navController receivedNotification] objectForKey:@"gameID"]) {
            Game *notificationGame;
            for ( notificationGame in [player activeGames] ) {
                if ([[notificationGame gameID] isEqualToString:[[navController receivedNotification] objectForKey:@"gameID"]]) {
                    break;
                }
            }
            if ([[notificationGame gameID] isEqualToString:[[navController receivedNotification] objectForKey:@"gameID"]]) {
                    [self performSegueWithIdentifier:@"gameTap" sender:self];
                    [boardController setShowAds: showAds];
                    [boardController setGame:notificationGame];
                    [boardController setActiveGame:YES];
                    [boardController replayGame];
                    [[boardController boardTapRecognizer] setEnabled:YES];
            }
        } else if ([[navController receivedNotification] objectForKey:@"setID"]) {
            long idx = 0;
            for ( notificationGame in [player invitations] ) {
                if ([[notificationGame gameID] isEqualToString:[[navController receivedNotification] objectForKey:@"setID"]]) {
                    break;
                }
                idx++;
            }
            if (idx < [[player invitations] count]) {
                if (invitationsReceivedCollapsed) {
                    invitationsReceivedCollapsed = !invitationsReceivedCollapsed;
                    [[NSUserDefaults standardUserDefaults] setBool:invitationsReceivedCollapsed forKey:@"invitationsReceivedCollapsed"];
                    NSMutableArray *indexSet = [[NSMutableArray alloc] init];
                    for(int i = 0; i < [[player invitations] count]; ++i){
                        [indexSet addObject:[NSIndexPath indexPathForRow:i inSection: INVITATIONSSECTION]];
                    }
                    [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
                    [self.tableView performSelector:@selector(reloadData) withObject: nil afterDelay:0.275];
                    [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.315];
                    
                    [[self.tableView headerViewForSection: INVITATIONSSECTION] setNeedsDisplay];
                }
                if (selectedPublicInvitationIndexPath) {
                    [self removeButtonsFromPublicInvitationsCell];
                    [self.tableView beginUpdates];
                    selectedPublicInvitationIndexPath = nil;
                    selectedPublicInvitationCell = nil;
                    [self.tableView endUpdates];
                }
                GameTableViewCell *cell = (GameTableViewCell *) [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow: idx inSection: INVITATIONSSECTION]];
                if (selectedInvitationIndexPath) {
                    if ((selectedInvitationIndexPath.section != INVITATIONSSECTION) || (selectedInvitationIndexPath.row != idx)) {
                        [self removeButtonsFromCell];
                        GameTableViewCell *tmpCell = (GameTableViewCell *) [self.tableView cellForRowAtIndexPath:selectedInvitationIndexPath];
                        [tmpCell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
                        
                        [cell setAccessoryType:UITableViewCellAccessoryNone];
                        [cell layoutSubviews];
                        [self.tableView beginUpdates];
                        selectedInvitationIndexPath = [NSIndexPath indexPathForRow: idx inSection: INVITATIONSSECTION];
                        [self.tableView endUpdates];
                        
                        [self addButtonsToCell:cell];
                        selectedInvitationCell = cell;
                    }
                } else {
                    [cell setAccessoryType:UITableViewCellAccessoryNone];
                    [self.tableView beginUpdates];
                    selectedInvitationIndexPath = [NSIndexPath indexPathForRow: idx inSection: INVITATIONSSECTION];
                    [self.tableView endUpdates];
                    
                    [self addButtonsToCell:cell];
                    selectedInvitationCell = cell;
                }
                selectedGame = [[player invitations] objectAtIndex: idx];
            }
        } else if ([[navController receivedNotification] objectForKey:@"msgID"]) {

            Message *notificationMessage;
            long idx = 0;
            for ( notificationMessage in [player messages] ) {
                if ([[notificationMessage messageID] isEqualToString:[[navController receivedNotification] objectForKey:@"msgID"]]) {
                    break;
                }
                idx++;
            }
            if (idx < [[player messages] count]) {
                if ([[notificationMessage messageID] isEqualToString:[[navController receivedNotification] objectForKey:@"msgID"]]) {
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
                    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                    [navControllor setDeletedMessageRow: (int) idx];
                    
                    [self performSegueWithIdentifier:@"messagesTap" sender:self];
                    
                    [messagesViewController setMessageID:[[[player messages] objectAtIndex: idx] messageID]];
                    [messagesViewController setAuthor:[[[player messages] objectAtIndex: idx] author]];
                    [messagesViewController setSubject:[[[player messages] objectAtIndex: idx] subject]];
                    if ([[[[player messages] objectAtIndex: idx] unread] isEqualToString:@"unread"]) {
                        [[[player messages] objectAtIndex: idx] setUnread:@"read"];
//                            [self.tableView reloadData];
                    }
                }
            }

        }
    } else {
        if (navController.loggedIn) {
            if ([[player activeGames] count] + [[player nonActiveGames] count] + [[player sentInvitations] count] == 0) {
                if (!alreadyAskedAboutInvitations) {
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    if (![defaults boolForKey:@"doNotRemindOpenInvitation"]) {
                            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Nothing to see here" message:@"You have no ongoing games, shall we post an open invitation and get you started?" delegate:self cancelButtonTitle:@"Remind me next time." otherButtonTitles:@"Sure!", @"Do not remind me again.", nil];
                            [alert setTag: 0];
                            [alert show];
                    }
                }
            }
        }
    }
    [navController setReceivedNotification:nil];
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    long badgeNr = [[player activeGames] count] + [[player invitations] count];
    for (Message *message in [player messages]) {
        if ([message.unread isEqualToString:@"unread"]) {
            badgeNr++;
        }
    }
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:badgeNr];
    self.tableView.layer.borderWidth = 0.0;
    [self.tableView setUserInteractionEnabled:YES];


}


-(void) showActions {
    NSMutableArray *buttonsArray = [[NSMutableArray alloc] init];
    CGRect frame = CGRectMake(0, 0, 45, 45);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [button setImage:[UIImage imageNamed:@"newmessage.png"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(toComposer) forControlEvents:UIControlEventTouchUpInside];
    [button setFrame:frame];
    [buttonsArray addObject: button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"showstats.png"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(showStats) forControlEvents:UIControlEventTouchUpInside];
    [button setFrame:frame];
    [buttonsArray addObject: button];
    
    actionPopoverView = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width - 20, 0) inView:self.view withViewArray: buttonsArray delegate:self];
    
}


-(void) toComposer {
    [actionPopoverView dismiss];
    [self performSegueWithIdentifier:@"messagesTap" sender:self];
//    [self performSegueWithIdentifier:@"inviteAItap" sender:self];
}

-(void) showStats {
    [actionPopoverView dismiss];
    
    RatingStatsView *ratingView = [[RatingStatsView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*4/5, 44*[[player ratingStats] count])];
    [ratingView setDelegate: ratingView];
    [ratingView setDataSource: ratingView];
    [ratingView setRatingStats: [player ratingStats]];
//    [ratingView setUserInteractionEnabled:NO];
    [ratingView setScrollEnabled: NO];
    [ratingView setVc: self];
    
    actionPopoverView = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width - 20, 0) inView:self.view withTitle: @"rating stats" withContentView: ratingView delegate:self];
    [actionPopoverView layoutSubviews];
//    [ratingView setFrame: frame];
}

-(void) showInvitationActions {
    NSMutableArray *buttonsArray = [[NSMutableArray alloc] init];
    CGRect frame = CGRectMake(0, 0, 45, 45);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"server.png"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(toAIInvitations) forControlEvents:UIControlEventTouchUpInside];
    [button setFrame: frame];
    [buttonsArray addObject: button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"computer.png"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(toMMAI) forControlEvents:UIControlEventTouchUpInside];
    [button setFrame: frame];
    [buttonsArray addObject: button];
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    [button setImage:[UIImage imageNamed:@"person.png"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(toRegularInvitations) forControlEvents:UIControlEventTouchUpInside];
    [button setFrame: frame];
    [buttonsArray addObject: button];
    
    actionPopoverView = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width - 80, 0) inView:self.view withViewArray: buttonsArray delegate:self];
    
}

-(void) toRegularInvitations {
    [actionPopoverView dismiss];
    [self performSegueWithIdentifier:@"addInvitationsTap" sender: self];
    //    [self performSegueWithIdentifier:@"inviteAItap" sender:self];
}
-(void) toMMAI {
    [actionPopoverView dismiss];
    [self performSegueWithIdentifier:@"MMAItap" sender:self];
}
-(void) toAIInvitations {
    [actionPopoverView dismiss];
    [self performSegueWithIdentifier:@"inviteAItap" sender:self];
}



- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 0) {
        alreadyAskedAboutInvitations = YES;
        if (buttonIndex == 0) {
//            NSLog(@"button 0");
        }
        else if (buttonIndex == 1) {
//            NSLog(@"button 1");
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"How to?" message:@"Pick any game but leave the opponent field empty and everyone will see your invitation." delegate:self cancelButtonTitle:@"Got it!" otherButtonTitles:nil, nil];
            [alert setTag: 1];
            [alert show];
        } else if (buttonIndex == 2) {
//            NSLog(@"button 2");
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:YES forKey:@"doNotRemindOpenInvitation"];
        }
    } else if (alertView.tag == 1) {
        [self performSegueWithIdentifier:@"addInvitationsTap" sender:self];
    }
}


-(NSString *) replaceWithSmileys: (NSString *) inStr {
    NSString *tmpStrComma = [inStr stringByReplacingOccurrencesOfString:@"\\1" withString: @","];
    NSString *tmpStrSmiley = [tmpStrComma stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/happy.gif\" alt=\"\">" withString: @":)"];
    NSString *tmpStrWink = [tmpStrSmiley stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/wink.gif\" alt=\"\">" withString: @";)"];
    NSString *tmpStrTongue = [tmpStrWink stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/silly.gif\" alt=\"\">" withString: @":p"];
    NSString *tmpStrGrin = [tmpStrTongue stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/grin.gif\" alt=\"\">" withString: @":D"];
    NSString *tmpStrSad = [tmpStrGrin stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/sad.gif\" alt=\"\">" withString: @":("];
    NSString *tmpStrLove = [tmpStrSad stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/love.gif\" alt=\"\">" withString: @"<3"];
    NSString *tmpStrMischief = [tmpStrLove stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/mischief.gif\" alt=\"\">" withString: @";\\"];
    NSString *tmpStrCool = [tmpStrMischief stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/cool.gif\" alt=\"\">" withString: @"B)"];
    NSString *tmpStrDevil = [tmpStrCool stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/devil.gif\" alt=\"\">" withString: @">:)"];
    NSString *tmpStrAngry = [tmpStrDevil stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/angry.gif\" alt=\"\">" withString: @"X("];
    NSString *tmpStrLaugh = [tmpStrAngry stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/laugh.gif\" alt=\"\">" withString: @":^O"];
    NSString *tmpStrBlush = [tmpStrLaugh stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/blush.gif\" alt=\"\">" withString: @":8)"];
    NSString *tmpStrCry = [tmpStrBlush stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/cry.gif\" alt=\"\">" withString: @":'("];
    NSString *tmpStrConfused = [tmpStrCry stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/confused.gif\" alt=\"\">" withString: @"?:|"];
    NSString *tmpStrShocked = [tmpStrConfused stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/shocked.gif\" alt=\"\">" withString: @":O"];
    return [tmpStrShocked stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/plain.gif\" alt=\"\">" withString: @":|"];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    NSArray *trustedHosts = [NSArray arrayWithObjects:@"mytrustedhost",nil];
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
        if ([trustedHosts containsObject:challenge.protectionSpace.host]) {
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        }
    }
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}


- (void)viewDidUnload {
    [super viewDidUnload];
}


@end



@implementation GameTableViewCell
@synthesize ratingLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        ratingLabel = [[UILabel alloc] init];
        [ratingLabel setTextAlignment:NSTextAlignmentRight];
        [self.ratingLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.f]];
        [self.contentView addSubview: ratingLabel];
    }
    return self;
}


- (void) layoutSubviews {
    [super layoutSubviews];
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    CGFloat imageWidth = 0;
    if (self.imageView) {
        imageWidth = self.imageView.frame.size.width;
    }
    CGFloat accessoryWidth;
    if (self.accessoryType == UITableViewCellAccessoryDisclosureIndicator) {
        accessoryWidth = 20;
    } else {
        accessoryWidth = 0;
    }
    if ([self.reuseIdentifier isEqualToString: @"tournament"]) {
        [self.textLabel setFrame:CGRectMake(10, 2, (screenWidth - accessoryWidth - 10), 22)];
        [self.detailTextLabel setFrame:CGRectMake(10, 24, screenWidth - accessoryWidth - 20, 18)];
//        [self.imageView setFrame:CGRectMake(0, 0, imageWidth, imageWidth)];
    } else {
        [self.textLabel setFrame:CGRectMake(imageWidth + 10, 2, (screenWidth - imageWidth - accessoryWidth + 60)/2, 22)];
        [self.ratingLabel setFrame:CGRectMake(imageWidth + 10 + (screenWidth - imageWidth - accessoryWidth - 20)/2, 2, (screenWidth - imageWidth - accessoryWidth - 60)/2, 22)];
        [self.detailTextLabel setFrame:CGRectMake(imageWidth + 10, 24, screenWidth - imageWidth - accessoryWidth - 20, 18)];
        [self.imageView setFrame:CGRectMake(0, 0, imageWidth, imageWidth)];
    }
    
//        NSLog(@"kittenfont ");
}

//- (void) replaceButton {
//    if ([(UITableView *)self.superview.superview indexPathForCell: self].section == 3) {
//        UIView *deleteButtonView;
//        for (UIView *subview in self.subviews) {
//            //            NSLog(@"kitty2 %@", NSStringFromClass([subview class]));
//            for (UIView *subsubview in subview.subviews) {
////                NSLog(@"kitty1 %@", NSStringFromClass([subsubview class]));
//                if ([NSStringFromClass([subsubview class]) isEqualToString:@"UITableViewCellDeleteConfirmationView"]) {
//                    //                if ([NSStringFromClass([subsubview class]) isEqualToString:@"UIButton"]) {
//                    
//                    deleteButtonView = (UIView *) subsubview;
//                    //                    deleteButtonView.backgroundColor = [UIColor greenColor];
//                    UIImageView *image = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"acceptButton"]];
//                    [image setFrame:CGRectMake(0,0,deleteButtonView.frame.size.width, deleteButtonView.frame.size.height)];
//                    [deleteButtonView addSubview:image];
//                }
//            }
//        }
//    }
//}

@end


