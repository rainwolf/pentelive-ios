//
//  KOTHTableViewController.m
//  penteLive
//
//  Created by rainwolf on 02/07/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "KOTHTableViewController.h"
#import "PenteNavigationViewController.h"
#import "SVWebViewController.h"

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
    [self.textLabel setFrame:CGRectMake(imageWidth + 10, 2, (screenWidth - imageWidth - accessoryWidth + 60)/2, 22)];
    [self.ratingLabel setFrame:CGRectMake(imageWidth + 10 + (screenWidth - imageWidth - accessoryWidth - 20)/2, 2, (screenWidth - imageWidth - accessoryWidth - 60)/2, 22)];
    [self.detailTextLabel setFrame:CGRectMake(imageWidth + 10, 24, screenWidth - imageWidth - accessoryWidth - 20, 18)];
    [self.imageView setFrame:CGRectMake(0, 0, imageWidth, imageWidth)];
}
@end



@interface Player : NSObject {
    NSString *name, *rating, *lastGame;
    BOOL canBeChallenged;
    int crown, color;
}
@property(retain, nonatomic, readwrite) NSString *name, *rating, *lastGame;
@property(assign, atomic, readwrite) BOOL canBeChallenged;
@property(assign, atomic, readwrite) int crown, color;
@end
@implementation Player
@synthesize name, rating, lastGame;
@synthesize canBeChallenged;
@synthesize crown, color;
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


-(void) viewDidLoad {
    [super viewDidLoad];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.backgroundColor = [UIColor purpleColor];
    self.refreshControl.tintColor = [UIColor whiteColor];
    [self.refreshControl addTarget:self
                            action:@selector(loadKoth)
                  forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(loadWebsiteHill)];
    [self.navigationItem setRightBarButtonItem:barButton];
    hill = [[Hill alloc] init];
    [self loadKoth];
    
    
    
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
//    [super scrollViewDidScroll:scrollView];
    if ([player showAds]) {
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
    bannerView = ((PenteNavigationViewController *) self.navigationController).bannerView;
    bannerView.rootViewController = self;
    [bannerView setDelegate: self];
    if ([player showAds]) {
        CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
        CGFloat newOriginY = screenHeight - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height - bannerView.frame.size.height;
        CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
        bannerView.frame = newBannerViewFrame;
        [self.tableView setTableFooterView:bannerView];
        [self.tableView bringSubviewToFront:bannerView];
        [self scrollViewDidScroll: self.tableView];
    }
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
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"username"] isEqualToString:[[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] name]]) {
            cell = (PlayerTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"myKothCell"];
            if (!cell) {
                cell = [[PlayerTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"myKothCell"];
            }
            cell.imageView.image = [UIImage imageNamed:@"unread.png"];
        } else {
            cell = (PlayerTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"kothCell"];
            if (!cell) {
                cell = [[PlayerTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"kothCell"];
            }
            cell.imageView.image = nil;
        }
    }
    if (indexPath.section == 0) {
        cell.textLabel.text = [NSString stringWithFormat:@"Tap to %@ this hill", [hillSummary member]?@"leave":@"join"];
        if (![player subscriber] && ![hillSummary member]) {
            cell.detailTextLabel.text = @"Warning: only subscribers can join multiple hills";
        }
        [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
    } else {
        [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        NSMutableString *txtStr = [[NSMutableString alloc] initWithString: [[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] name]];
        int crown = [[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] crown];
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
        if ([[[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] rating] length] == 3) {
            [ratingStr appendString:@"  "];
        }
        [ratingStr appendString: [[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] rating]];
        NSMutableAttributedString *tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
        [self addColorOfRating: [[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] rating] toString: tmpStr];
        ((PlayerTableViewCell *) cell).ratingLabel.attributedText = tmpStr;
        
        tmpStr = [[NSMutableAttributedString alloc] initWithString: txtStr];
        [tmpStr addAttribute:NSForegroundColorAttributeName value:UIColorFromRGB([[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] color]) range:NSMakeRange(0, [[[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] name] length])];
        [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
        if ([[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] color] != 0) {
            [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] name] length])];
        }
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
        [tmpStr appendAttributedString:crownStr];
        cell.textLabel.attributedText = tmpStr;
//        if ([[[[player invitations] objectAtIndex:indexPath.row] ratedNot] isEqualToString:@"Rated"]) {
//            txtStr = (NSMutableString *) [NSString stringWithFormat:@"%@ (%@) - %@", [[[player invitations] objectAtIndex:indexPath.row] gameType], [[[player invitations] objectAtIndex:indexPath.row] ratedNot], [[[player invitations] objectAtIndex:indexPath.row] remainingTime]];
//        } else {
//            txtStr = (NSMutableString *) [NSString stringWithFormat:@"%@ (%@, %@) - %@", [[[player invitations] objectAtIndex:indexPath.row] gameType], [[[player invitations] objectAtIndex:indexPath.row] ratedNot], [[[[player invitations] objectAtIndex:indexPath.row] myColor] substringWithRange: NSMakeRange(0,5)], [[[player invitations] objectAtIndex:indexPath.row] remainingTime]];
//        }
        cell.detailTextLabel.text = [NSString stringWithFormat: @"Last game played on %@", [[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] lastGame]];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        if ([[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] canBeChallenged]) {
            cell.backgroundColor = [UIColor colorWithRed: 222.0/256 green:236.0/256 blue:222.0/256 alpha:1];
            [cell setUserInteractionEnabled: YES];
        } else {
            cell.backgroundColor = [UIColor whiteColor];
            [cell setUserInteractionEnabled: NO];
        }

    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        [self joinLeave];
    } else {
        CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
        
        challengeView = [[KOTHChallengeView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*2/3, 103)];
        [challengeView setScrollEnabled:NO];
        [challengeView setGameStr:[self getGameString:[hillSummary game]]];
        [challengeView setInvitee:[[[[hill steps] objectAtIndex: indexPath.section - 1] objectAtIndex:indexPath.row] name]];
        [challengeView setDelegate: challengeView];
        [challengeView setDataSource: challengeView];
        actionPopoverView = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width/2, cellRect.origin.y + cellRect.size.height/2) inView:self.view withTitle: [NSString stringWithFormat: @"challenge %@", challengeView.invitee] withContentView: challengeView delegate:self];
        [challengeView setPopoverView: actionPopoverView];
        [actionPopoverView layoutSubviews];
        ((PenteNavigationViewController *) self.navigationController).didMove = YES;
    }
    
}



- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return [NSString stringWithFormat:@"King of the Hill - %@", [hillSummary game]];
    } else if (section == 1) {
        return @"top of the hill";
    } else {
        return [NSString stringWithFormat:@"step %lu", [hill.steps count] - section + 1] ;
    }
}



- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    [[challengeView  timoutCell] doResign];
    [self loadKoth];
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

-(void) joinLeave {

    NSString *gameString = [self getGameString:[hillSummary game]];

    NSString *url;
    NSURLResponse *response;
    NSError *error;
    NSData *responseData;
    
    // connect to the game server
    url =  @"https://www.pente.org/gameServer/koth";
//    url =  @"https://development.pente.org/gameServer/koth";

    NSString *postString = [NSString stringWithFormat:@"%@&game=%@",[hillSummary member]?@"leave=":@"join=", gameString];
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
    
    ((PenteNavigationViewController *) self.navigationController).didMove = YES;
    
    [self loadKoth];
}

-(void) loadKoth {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *username = [defaults objectForKey: @"username"];
    NSString *gameString = [self getGameString:[hillSummary game]];

    self.tableView.layer.borderWidth = 1.5;
    
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url;
    NSURLResponse *response;
    NSError *error;
    NSData *responseData;
    
    // connect to the game server
    url =  [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobile/koth.jsp?name=%@&game=%@",username, gameString];
//    url =  [NSString stringWithFormat:@"https://development.pente.org/gameServer/mobile/koth.jsp?name=%@&game=%@",username, gameString];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    

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
        NSMutableArray *indexSet;
        int dashIDX = 0;

        hill = [[Hill alloc] init];
        hill.steps = [[NSMutableArray alloc] init];

        sectionItems = [[NSMutableArray alloc] init];
        while ((dashIDX < [splitDash count]) && ([[splitDash objectAtIndex:dashIDX] isEqualToString: @""])) {
            dashIDX++;
        }
        if ((dashIDX < [splitDash count])) {
            while ((![[splitDash objectAtIndex:dashIDX] isEqualToString: @""]) && (dashIDX < [splitDash count])) {
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
                        [step addObject:kothPlayer];
                    }
                }
                if ([step count] > 0) {
                    [[hill steps] insertObject:step atIndex:0];
                }
                dashIDX++;
            }
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


-(NSString *) getGameString: (NSString *) inStr {
    NSString *gameString;
    if ([inStr isEqualToString:@"Pente"])
        gameString = @"51";
    if ([inStr isEqualToString:@"Gomoku"])
        gameString = @"55";
    if ([inStr isEqualToString:@"D-Pente"])
        gameString = @"57";
    if ([inStr isEqualToString:@"G-Pente"])
        gameString = @"59";
    if ([inStr isEqualToString:@"Boat-Pente"])
        gameString = @"65";
    if ([inStr isEqualToString:@"Poof-Pente"])
        gameString = @"61";
    if ([inStr isEqualToString:@"Connect6"])
        gameString = @"63";
    if ([inStr isEqualToString:@"Keryo-Pente"])
        gameString = @"53";
    
    return gameString;
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
        for(Player *player in [[hill steps] objectAtIndex: section - 1]) {
            if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"username"] isEqualToString:[player  name]]) {
                [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:1.0 green:(129.0/255) blue:0.0 alpha:1.0]];
                break;
            }
        }
        collapsedLabel.text = [NSString stringWithFormat:@"(%lu)", [[hill.steps objectAtIndex: section - 1] count]] ;
    } else {
        collapsedLabel.text = [NSString stringWithFormat:@"(%@)", [hillSummary numPlayers]];
        [sectionHeaderView setBackgroundColor:[UIColor colorWithRed:(8.0/255) green:(52.0/255) blue:(29.0/255) alpha:1.0]];
    }
    
    
    return sectionHeaderView;
}

-(void) loadWebsiteHill {
    NSString *urlString = [NSString stringWithFormat:@"https://www.pente.org/gameServer/stairs.jsp?game=%@", [self getGameString: hillSummary.game]];
    SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress: urlString];
    [self.navigationController pushViewController:webViewController animated:YES];
}

@end























