//
//  KOTHTableViewController.m
//  penteLive
//
//  Created by rainwolf on 02/07/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "KOTHTableViewController.h"
#import "PenteNavigationViewController.h"
#import "penteLive-Swift.h"
@import TSMessages;

@interface PlayerTableViewCell : UITableViewCell {
    UILabel *ratingLabel;
}
@property(nonatomic, retain, readwrite) UILabel *ratingLabel;
@end
@implementation PlayerTableViewCell
@synthesize ratingLabel;



- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        ratingLabel = [[UILabel alloc] init];
        [ratingLabel setTextAlignment:NSTextAlignmentRight];
        [self.ratingLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.f]];
        [self.textLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.f]];
        [self.contentView addSubview: ratingLabel];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.clipsToBounds = YES;
    }
    return self;
}


- (void) layoutSubviews {
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
    [self.textLabel setFrame:CGRectMake(imageWidth + 10, 3, (screenWidth - imageWidth - accessoryWidth + 60)/2, 22)];
    [self.ratingLabel setFrame:CGRectMake(imageWidth + 10 + (screenWidth - imageWidth - accessoryWidth - 20)/2, 2, (screenWidth - imageWidth - accessoryWidth - 60)/2, 22)];
    [self.detailTextLabel setFrame:CGRectMake(imageWidth + 10, 24, screenWidth - imageWidth - accessoryWidth - 20, 18)];
    [self.imageView setFrame:CGRectMake(0, 0, imageWidth, imageWidth)];
}
@end



@implementation Player
@synthesize name, rating, lastGame, numberOfGames;
@synthesize canBeChallenged;
@synthesize crown, color;
-(NSAttributedString *) attributedName: (BOOL) dark {
    NSMutableAttributedString *txtStr;
    if ([name isEqualToString:@"Anyone"]) {
        txtStr = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Anyone", nil)];
    } else {
        txtStr = [[NSMutableAttributedString alloc] initWithString:name];
    }
    if (color != 0) {
        [txtStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [txtStr length])];
        [txtStr addAttribute:NSForegroundColorAttributeName value:UIColorFromRGB(color) range:NSMakeRange(0, [txtStr length])];
    } else if (dark) {
        [txtStr addAttribute:NSForegroundColorAttributeName value:[UIColor blackColor] range:NSMakeRange(0, [txtStr length])];
    }
    [txtStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
    if (crown > 0) {
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
            default:
                if (crown > 3) {
                    textAttachment.image = [UIImage imageNamed: [NSString stringWithFormat:@"kothcrown%i", crown-3]];
                }
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        [txtStr appendAttributedString:crownStr];
    }
    return txtStr;
}

-(NSAttributedString *) ratingString: (BOOL) dark {
    int ratingInt = [rating intValue];
    UIColor *ratingColor;
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
    NSMutableAttributedString *txtStr = [[NSMutableAttributedString alloc] initWithString:@"\u25A0 "];
    [txtStr addAttribute:NSForegroundColorAttributeName value: ratingColor range: NSMakeRange(0, 1)];
    if ([rating length]<4) {
        [txtStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"  "]];
    }
    [txtStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Bold" size:12.f] range: NSMakeRange(0, 1)];
    [txtStr appendAttributedString:[[NSAttributedString alloc] initWithString:rating]];
    if (dark) {
        if (@available(iOS 13.0, *)) {
            if (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                [txtStr addAttribute:NSForegroundColorAttributeName value: [UIColor blackColor] range:NSMakeRange(2, [txtStr length] - 2)];
            }
        }
    }
    return txtStr;
}
@end
@interface Hill : NSObject {
    NSMutableArray<NSMutableArray<Player *> *> *steps;
}
@property(nonatomic, retain, readwrite) NSMutableArray<NSMutableArray<Player *> *> *steps;
@end
@implementation Hill
@synthesize steps;
@end





@implementation KOTHTableViewController
@synthesize hill;
@synthesize hillSummary;
@synthesize player;
@synthesize bannerView;
@synthesize actionPopoverView;
@synthesize challengeView;

CGFloat bottomOffst = 0;



-(void) viewDidLoad {
    [super viewDidLoad];
    bottomOffst = 0;
    if([[UIDevice currentDevice]userInterfaceIdiom]==UIUserInterfaceIdiomPhone) {
        if ((int)[[UIScreen mainScreen] nativeBounds].size.height == 2436) {
            bottomOffst = 34;
        }
    }

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor purpleColor];
    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self
                            action:@selector(loadKoth)
                  forControlEvents:UIControlEventValueChanged];

//    if ([hillSummary canSendOpen] && hillSummary.gameId > 50) {
    if (hillSummary.member && hillSummary.gameId > 50) {
        UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(loadWebsiteHill)];
        UIBarButtonItem *inviteButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed:@"person.png"] style: UIBarButtonItemStylePlain target:self action: @selector(showOpenChallengeView)];
        //    statsButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItem target:self action: @selector(showStats)];
        //    friendsButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed:@"friends.png"] style: UIBarButtonItemStylePlain target:self action:@selector(toFriends)];
        [self.navigationItem setRightBarButtonItem:nil];
        [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:barButton, inviteButton, nil]];
    } else {
        UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(loadWebsiteHill)];
        [self.navigationItem setRightBarButtonItem:barButton];
    }
    hill = [[Hill alloc] init];
    [self loadKoth];
    
    if ([player showAds]) {
//        NSLog(@"kitty");
        CGPoint origin = CGPointMake(0.0, self.view.frame.size.height - self.navigationController.navigationBar.frame.size.height - kGADAdSizeBanner.size.height);
        bannerView = [[GADBannerView alloc] initWithAdSize:kGADAdSizeSmartBannerPortrait origin:origin];
        bannerView.rootViewController = self;
        [bannerView setDelegate: self];
        CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
        CGFloat newOriginY = screenHeight - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height - bannerView.frame.size.height;
        CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
        bannerView.frame = newBannerViewFrame;
        bannerView.adUnitID = @"ca-app-pub-3326997956703582/7598759449";
        GADRequest *request = [GADRequest request];
        PentePlayer *player = ((PenteNavigationViewController *)self.navigationController).player;
        if (!player.personalizeAds) {
            GADExtras *extras = [[GADExtras alloc] init];
            extras.additionalParameters = @{@"npa": @"1"};
            [request registerAdNetworkExtras:extras];
        }
        [bannerView loadRequest:request];
        [self.view addSubview:bannerView];
        [self.tableView setTableFooterView:bannerView];
        [self.tableView bringSubviewToFront:bannerView];
        [self scrollViewDidScroll: self.tableView];
    }
    
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
//    [super scrollViewDidScroll:scrollView];
    if ([player showAds]) {
        if (bannerView) {
            CGFloat newOriginY = self.tableView.contentOffset.y + self.tableView.frame.size.height - bannerView.frame.size.height - bottomOffst;
            CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
            bannerView.frame = newBannerViewFrame;
        }
    } else if (bannerView) {
        [bannerView removeFromSuperview];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self scrollViewDidScroll: self.tableView];
}

-(void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [TSMessage dismissActiveNotification];
    [actionPopoverView dismiss];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
//    NSLog(@"kitty %lu", [[hill steps] count]);
    return 1 + [[hill steps] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        return [[[hill steps] objectAtIndex: section - 1] count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if (indexPath.section == 0) {
        cell = (UITableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"joinLeaveCell"];
        if (!cell) {
//            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"joinLeaveCell"];
            if ([player subscriber]) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"joinLeaveCell"];
            } else {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"joinLeaveCell"];
            }
        }
    } else {
        Player *playr = [[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row];
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"username"] isEqualToString:[playr name]]) {
            cell = (PlayerTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"myKothCell"];
            if (!cell) {
                cell = [[PlayerTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"myKothCell"];
            }
            NSString *opponent = [playr name];
            UIImage *imgV = [player.avatars objectForKey: opponent];
            if (imgV != nil) {
                cell.imageView.image = imgV;
            } else {
                cell.imageView.image = [UIImage imageNamed:@"unread.png"];
            }
        } else {
            cell = (PlayerTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"kothCell"];
            if (!cell) {
                cell = [[PlayerTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"kothCell"];
            }
            NSString *opponent = [playr name];
            UIImage *imgV = [player.avatars objectForKey: opponent];
            cell.imageView.image = imgV;
        }
    }
    if (indexPath.section == 0) {
        if (hillSummary.gameId < 50) {
            cell.textLabel.text = NSLocalizedString(@"join by playing in the live KotH room",nil);
        } else {
            if ([hillSummary member]) {
                cell.textLabel.text = NSLocalizedString(@"Tap to leave this hill",nil);
            } else {
                cell.textLabel.text = NSLocalizedString(@"Tap to join this hill",nil);
            }
        }
        if (![player subscriber] && ![hillSummary member]) {
            cell.detailTextLabel.text = NSLocalizedString(@"Warning: only subscribers can join multiple hills",nil);
        }
        [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
    } else {
        Player *playr = [[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row];
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        ((PlayerTableViewCell *) cell).ratingLabel.attributedText = [playr ratingString: [playr canBeChallenged]];
        cell.textLabel.attributedText = [player markIfOnline:[playr name] andAttributedName:[playr attributedName: [playr canBeChallenged]]];
        NSMutableAttributedString *detailStr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat: NSLocalizedString(@"Last game played on %@",nil), [playr lastGame]]];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        if ([playr canBeChallenged]) {
            cell.backgroundColor = [UIColor colorWithRed: 222.0/256 green:236.0/256 blue:222.0/256 alpha:1];
            [detailStr addAttribute:NSForegroundColorAttributeName value: [UIColor blackColor] range:NSMakeRange(0, [detailStr length])];
        } else {
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor systemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor whiteColor];
            }
        }
        cell.detailTextLabel.attributedText = detailStr;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (hillSummary.gameId < 50 && indexPath.section == 0) {
        return;
    }
    [TSMessage dismissActiveNotification];
    if (indexPath.section == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TSMessage showNotificationInViewController:self
                                                  title: NSLocalizedString(@"Tap again here to confirm",nil)
                                               subtitle: nil
                                                  image:nil
                                                   type: TSMessageNotificationTypeWarning
                                               duration:TSMessageNotificationDurationEndless
                                               callback: ^{
                                                   [TSMessage dismissActiveNotification];
                                                   [self joinLeave];
                                               }
                                            buttonTitle: NSLocalizedString(@"cancel",nil)
                                         buttonCallback:^{
                                             [TSMessage dismissActiveNotification];
                                         }
                                             atPosition:TSMessageNotificationPositionTop
                                   canBeDismissedByUser:YES];
            
        });
    } else {
        Player *playr = [[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row];
        if (hillSummary.gameId > 50 && [playr canBeChallenged]) {
            CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
            
            challengeView = [[KOTHChallengeView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*2/3, 103)];
            [challengeView setScrollEnabled:NO];
            [challengeView setGameId:[hillSummary gameId]];
            [challengeView setInvitee:[playr name]];
            [challengeView setDelegate: challengeView];
            [challengeView setDataSource: challengeView];
            actionPopoverView = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width/2, cellRect.origin.y + cellRect.size.height/2) inView:self.view withTitle: [NSString stringWithFormat: @"challenge %@", challengeView.invitee] withContentView: challengeView delegate:self];
            [challengeView setPopoverView: actionPopoverView];
            [actionPopoverView layoutSubviews];
            ((PenteNavigationViewController *) self.navigationController).didMove = YES;
        } else {
            NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:@"username"];
            NSString *password = [[NSUserDefaults standardUserDefaults] objectForKey:@"password"];
            NSString *url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/profile?viewName=%@&name2=%@&password2=%@", playr.name, username, password];
            if (development) {
                url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/profile?viewName=%@&name2=%@&password2=%@", playr.name, username, password];
            }
            PenteWebViewController *webVC = [[PenteWebViewController alloc] initWithAddress:url];
            [self.navigationController pushViewController:webVC animated:YES];
        }
    }
    
}



- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [NSString stringWithFormat:NSLocalizedString(@"King of the Hill - %@",nil), [hillSummary game]];
    } else if (section == 1) {
        return NSLocalizedString(@"top of the hill",nil);
    } else {
        return [NSString stringWithFormat:NSLocalizedString(@"step %lu",nil), [hill.steps count] - section + 1] ;
    }
}



- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    [challengeView dismissPicker: nil];
    [self loadKoth];
}


-(void) showOpenChallengeView {
    if (![hillSummary canSendOpen] && !player.subscriber) {
//    if (YES) {
        UIAlertController *alertDialog = [UIAlertController
                                                        alertControllerWithTitle:NSLocalizedString(@"KotH limit", nil)
                                                        message: NSLocalizedString(@"Free players can play, at most, 2 KotH sets at a time, this includes sent and received invitations, you can post invitations again after you finish a set.\n Subscribers don't have this limit.", nil)
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            //            NSLog(@"Cancel action");
        }];
        UIAlertAction *subscribeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"subscription info", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            ((PenteNavigationViewController *) self.navigationController).showSubscribe = YES;
            [self.navigationController popToRootViewControllerAnimated:YES];
        }];
        [alertDialog addAction:cancelAction];
        [alertDialog addAction:subscribeAction];
        
        if (alertDialog.popoverPresentationController != nil) {
            alertDialog.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems[1];
        }
        
        [self presentViewController:alertDialog animated:NO completion:nil];
    } else if ([hillSummary canSendOpen]) {
        challengeView = [[KOTHChallengeView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*4/5, 147)];
        [challengeView setScrollEnabled:NO];
        [challengeView setGameId:[hillSummary gameId]];
        [challengeView setInvitee:@""];
        [challengeView setDelegate: challengeView];
        [challengeView setDataSource: challengeView];
        actionPopoverView = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width/2, [self.tableView contentOffset].y + 66) inView:self.view withTitle: NSLocalizedString(@"send open challenge",nil) withContentView: challengeView delegate:self];
        [challengeView setPopoverView: actionPopoverView];
        [actionPopoverView layoutSubviews];
        ((PenteNavigationViewController *) self.navigationController).didMove = YES;
    }
}

-(void) addColorOfRating: (NSString *) rating toString: (NSMutableAttributedString *) str {
    int ratingInt = [rating intValue];
    UIColor *ratingColor;
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

-(void) joinLeave {


    NSString *url;
    NSURLResponse *response;
    NSError *error;
//    NSData *responseData;
    
    // connect to the game server
    url =  @"https://www.pente.org/gameServer/koth";
    if (development) {
        url =  @"https://development.pente.org/gameServer/koth";
    }

    NSString *postString = [NSString stringWithFormat:@"%@&game=%i",[hillSummary member]?@"leave=":@"join=", hillSummary.gameId];
    NSData *postData = [postString dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    

    
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Reason: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        //        [alert show];
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
        return;
    }
    
    ((PenteNavigationViewController *) self.navigationController).didMove = YES;
    
    [self loadKoth];
}

-(void) loadKoth {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *username = [defaults objectForKey: @"username"];
    NSString *password = [defaults objectForKey: @"password"];
    int gameId = [hillSummary gameId];

    self.tableView.layer.borderWidth = 1.5;
    
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url;
    NSURLResponse *response;
    NSError *error;
    NSData *responseData;
    
    // connect to the game server
    url =  [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobile/koth.jsp?name=%@&game=%i&name2=%@&password2=%@",username, gameId, username, password];
    if (development) {
        username = @"iostest";
        url =  [NSString stringWithFormat:@"https://development.pente.org/gameServer/mobile/koth.jsp?name=%@&game=%i&name2=%@&password2=%@",username, gameId, username, password];
    }
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Reason: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        //        [alert show];
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
        self.tableView.layer.borderWidth = 0.0;
        return;
    }
    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];

    BOOL wantsToSeeAvatars = [defaults boolForKey:@"wantToSeeAvatars"];

    [hillSummary setMember:[dashboardString rangeOfString:username].location != NSNotFound];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [CATransaction begin];
//        [self.tableView beginUpdates];
        [CATransaction setCompletionBlock: ^{
            self.tableView.layer.borderWidth = 0.0;
//            [self performSelector:@selector(scrollViewDidScroll:) withObject: self.tableView afterDelay:0.01];
        }];
        
        
//        [self.tableView setUserInteractionEnabled:NO];
        
//        if ([dashboardString rangeOfString:@"Invitations received"].location == NSNotFound) {
//            self.tableView.layer.borderWidth = 0.0;
//            [self.tableView setUserInteractionEnabled:YES];
//            return;
//        }
        
        NSArray *splitDash = [dashboardString componentsSeparatedByString:@"\n"];
        NSString *dashLine;
        NSArray *splitLine;
//                    NSLog(@"result: %@",dashboardString);
        
        NSMutableArray *sectionItems;
//        NSMutableArray *indexSet;
        int dashIDX = 0;

        hill = [[Hill alloc] init];
        hill.steps = [[NSMutableArray alloc] init];

        sectionItems = [[NSMutableArray alloc] init];
//        while ((dashIDX < [splitDash count]) && ([[splitDash objectAtIndex:dashIDX] isEqualToString: @""])) {
//            dashIDX++;
//        }
//        if ((dashIDX < [splitDash count])) {
//            while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @""]) && (dashIDX < [splitDash count])) {
            while (dashIDX < [splitDash count]) {
                dashLine = [splitDash objectAtIndex:dashIDX];
                splitLine = [dashLine componentsSeparatedByString:@";"];
                NSMutableArray<Player *> *step = [[NSMutableArray alloc] init];
                if ([splitLine count] > 0) {
                    for (NSString *playerStr in splitLine) {
                        NSArray<NSString *> *playerDetails = [playerStr componentsSeparatedByString:@","];
                        if ([playerDetails count] < 3) {
                            continue;
                        }
                        Player *kothPlayer = [[Player alloc] init];
                        [kothPlayer setName: [playerDetails objectAtIndex:0]];
                        [kothPlayer setRating: [playerDetails objectAtIndex:1]];
                        [kothPlayer setCanBeChallenged: [[playerDetails objectAtIndex: 2] isEqualToString:@"yes"]];
                        [kothPlayer setColor:[[playerDetails objectAtIndex: 3] intValue]];
                        [kothPlayer setCrown:[[playerDetails objectAtIndex: 4] intValue]];
                        [kothPlayer setLastGame: [playerDetails objectAtIndex:5]];
                        if (wantsToSeeAvatars && kothPlayer.color != 0) {
                            [player addUser:[kothPlayer name]];
                        }
                        [step addObject:kothPlayer];
                    }
                }
//                if ([step count] > 0) {
//                    [[hill steps] insertObject:step atIndex:0];
//                }
                [[hill steps] insertObject:step atIndex:0];
                dashIDX++;
            }
//        }
        while ([[hill steps] count]>0 && [[[hill steps] firstObject] count] == 0) {
            [[hill steps] removeObjectAtIndex:0];
        }

                   //        indexSet = [[NSMutableArray alloc] init];
//        for(int i = 0; i < [[player hills] count]; ++i)
//            [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: KOTHSECTION]];
//        [player setHills:[[NSMutableArray alloc] init]];
//        [self.tableView deleteRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
//        [player setHills:sectionItems];
//        indexSet = [[NSMutableArray alloc] init];
//        for(int i = 0; i < [[player hills] count]; ++i)
//            [indexSet addObject:[NSIndexPath indexPathForRow: i inSection: KOTHSECTION]];
//        [self.tableView insertRowsAtIndexPaths:indexSet withRowAnimation:UITableViewRowAnimationFade];
        
        
        
  
        [self.tableView reloadData];
//        [self.tableView endUpdates];
        [CATransaction commit];
 
        
        [self.refreshControl endRefreshing];
        
        
    });
    
}



- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    //    NSLog(@"kitttttttyyyyyyyyy %i", section);
    
   
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
        
        headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 2, tableView.bounds.size.width-60, 18)];
        headerLabel.backgroundColor = [UIColor clearColor];
        headerLabel.textColor = [UIColor whiteColor];
        headerLabel.shadowColor = [UIColor darkGrayColor];
        headerLabel.shadowOffset = CGSizeMake(0, 1);
        headerLabel.font = [UIFont systemFontOfSize:15.0f];
        headerLabel.text = [self tableView:tableView titleForHeaderInSection:section];
        headerLabel.tag = 0;
        collapsedLabel = [[UILabel alloc] initWithFrame:CGRectMake(tableView.bounds.size.width-70, 2, 70, 18)];
        collapsedLabel.center = CGPointMake(tableView.bounds.size.width-40, 11);
        collapsedLabel.backgroundColor = [UIColor clearColor];
        collapsedLabel.textColor = [UIColor whiteColor];
        collapsedLabel.shadowColor = [UIColor darkGrayColor];
        collapsedLabel.shadowOffset = CGSizeMake(0, 1);
        [collapsedLabel setTextAlignment:NSTextAlignmentRight];
        //    collapsedLabel.font = [UIFont boldSystemFontOfSize:18];
        [collapsedLabel setFont:[UIFont fontWithName:@"CourierNewPS-BoldMT" size:17.0f]];
        collapsedLabel.tag = 1;
        
        
        [sectionHeaderView addSubview:backgroundImageView];
        [sectionHeaderView addSubview:headerLabel];
        [sectionHeaderView addSubview:collapsedLabel];
    }
    
//    for (UIView *label in sectionHeaderView.subviews){
//        if([label isKindOfClass:[UILabel class]]){
//            if (label.tag == 0) {
//                headerLabel = (UILabel *) label;
//            } else if (label.tag == 1) {
//                collapsedLabel = (UILabel *) label;
//            }
//        }
//    }
//    
    
    if (section > 0) {
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:(8.0/255) green:(52.0/255) blue:(29.0/255) alpha:1.0]];
        for(Player *playr in [[hill steps] objectAtIndex: section - 1]) {
            if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"username"] isEqualToString:[playr  name]]) {
                [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0 green:(129.0/255) blue:0.0 alpha:1.0]];
                break;
            }
        }
        collapsedLabel.text = [NSString stringWithFormat:@"(%lu)", (unsigned long)[[hill.steps objectAtIndex: section - 1] count]] ;
    } else {
        collapsedLabel.text = [NSString stringWithFormat:@"(%@)", [hillSummary numPlayers]];
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:(8.0/255) green:(52.0/255) blue:(29.0/255) alpha:1.0]];
    }
    
    
    return sectionHeaderView;
}

-(void) loadWebsiteHill {
    NSString *urlString = [NSString stringWithFormat:@"https://www.pente.org/gameServer/stairs.jsp?game=%i", hillSummary.gameId];
    if (development) {
        urlString = [NSString stringWithFormat:@"https://development.pente.org/gameServer/stairs.jsp?game=%i", hillSummary.gameId];
    }
    PenteWebViewController *webViewController = [[PenteWebViewController alloc] initWithAddress: urlString];
    [self.navigationController pushViewController:webViewController animated:YES];
}

@end























