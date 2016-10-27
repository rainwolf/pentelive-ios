//
//  ViewController.m
//  test1
//
//  Created by Walied Othman on 23/07/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_RETINA ([[UIScreen mainScreen] scale] >= 2.0)

#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define SCREEN_MAX_LENGTH (MAX(SCREEN_WIDTH, SCREEN_HEIGHT))
#define SCREEN_MIN_LENGTH (MIN(SCREEN_WIDTH, SCREEN_HEIGHT))

#define IS_IPHONE_4_OR_LESS (IS_IPHONE && SCREEN_MAX_LENGTH < 568.0)
#define IS_IPHONE_5 (IS_IPHONE && SCREEN_MAX_LENGTH == 568.0)
#define IS_IPHONE_6 (IS_IPHONE && SCREEN_MAX_LENGTH == 667.0)
#define IS_IPHONE_6P (IS_IPHONE && SCREEN_MAX_LENGTH == 736.0)


#import "DatabaseViewController.h"
#import "DBBoardView.h"
#import <GoogleMobileAds/GoogleMobileAds.h>
//#import "GADBannerView.h"
#import <QuartzCore/QuartzCore.h>
#import "PopoverView.h"
#import "SVWebViewController.h"
#import "TSMessage.h"
#import "TSMessageView.h"
#import "MMAI.h"
#import "BoardViewController.h"




//GADBannerView *bannerView_;

@implementation DatabaseViewController {
    int abstractBoard[19][19];
    int finalMove, whiteCaptures, blackCaptures, lastMove;
    char coordinateLetters[19];
    BOOL aiThinking;
}
@synthesize aiPlayer;
@synthesize board;
@synthesize zoomedBoard;
@synthesize stone;
@synthesize zoomedStone;
@synthesize whiteCapturesCountLabel;
@synthesize whiteStoneCaptures;
@synthesize blackCapturesCountLabel;
@synthesize blackStoneCaptures;
@synthesize spinner;
@synthesize bannerView;
@synthesize showedAd;
@synthesize horizontalLine;
@synthesize verticalLine;
@synthesize movesList, captures;
@synthesize messagePopover;
@synthesize activeGame;
@synthesize playerStats;
@synthesize showAds;
@synthesize moveStatsString;
@synthesize playerStatsBaseString;
@synthesize setupView;
@synthesize progressView;

BoardViewController *boardController;

struct Capture {
    int color;
    int position;
};



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    showedAd = NO;
    
    aiThinking = NO;
    
    
    coordinateLetters[0] = 'A';
    coordinateLetters[1] = 'B';
    coordinateLetters[2] = 'C';
    coordinateLetters[3] = 'D';
    coordinateLetters[4] = 'E';
    coordinateLetters[5] = 'F';
    coordinateLetters[6] = 'G';
    coordinateLetters[7] = 'H';
    coordinateLetters[8] = 'J';
    coordinateLetters[9] = 'K';
    coordinateLetters[10] = 'L';
    coordinateLetters[11] = 'M';
    coordinateLetters[12] = 'N';
    coordinateLetters[13] = 'O';
    coordinateLetters[14] = 'P';
    coordinateLetters[15] = 'Q';
    coordinateLetters[16] = 'R';
    coordinateLetters[17] = 'S';
    coordinateLetters[18] = 'T';
    
    UIBarButtonItem *setupButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed:@"settings.png"] style: UIBarButtonItemStylePlain target:self action: @selector(showSetup)];
    [self.navigationItem setRightBarButtonItem:setupButton];
    
    [self setTitle:@"Database & AI"];
    [self setTitle:@"Database"];
    
    
    [board setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width)];
    [zoomedBoard setFrame:CGRectMake(0, 0, 2*self.view.bounds.size.width, 2*self.view.bounds.size.width)];
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"MMAIGame"] isEqualToString:@"Keryo-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
    } else {
        [board setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
    }
    [board setLastMove: -1];
    [zoomedBoard setLastMove: -1];
    
    CGRect rect;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [button setTitle:@"  search  " forState:UIControlStateNormal];
    [button addTarget:self action:@selector(searchDB:) forControlEvents:UIControlEventTouchUpInside];
    rect = button.frame;
    rect.size = [button intrinsicContentSize];
    rect.origin.y = board.frame.size.height + 2;
    rect.origin.x = self.view.bounds.size.width/2 - rect.size.width /2;
    button.frame = rect;
    [self.view addSubview: button];

    
    rect = whiteCapturesCountLabel.frame;
    rect.origin.y = board.frame.size.height + 2;
    whiteCapturesCountLabel.frame = rect;
    rect = whiteStoneCaptures.frame;
    rect.origin.y = board.frame.size.height + 2 + 2;
    whiteStoneCaptures.frame = rect;
    rect = blackCapturesCountLabel.frame;
    rect.origin.y = whiteCapturesCountLabel.frame.size.height + whiteCapturesCountLabel.frame.origin.y + 1;
    blackCapturesCountLabel.frame = rect;
    rect = blackStoneCaptures.frame;
    rect.origin.y = whiteCapturesCountLabel.frame.size.height + whiteCapturesCountLabel.frame.origin.y + 1 + 2;
    blackStoneCaptures.frame = rect;

    
    playerStatsBaseString = @"";
    playerStats = [[UIWebView alloc] initWithFrame:CGRectMake(2, blackStoneCaptures.frame.origin.y + 3, self.view.bounds.size.width - 4,  blackStoneCaptures.frame.origin.y - 3)];
    [playerStats setAlpha:0.90];
    [playerStats setBackgroundColor:[UIColor colorWithRed:0.98f green:0.98f blue:0.98f alpha:0.95]];
    playerStats.clipsToBounds = YES;
    playerStats.layer.cornerRadius = 1.0f;
    playerStats.layer.borderWidth = 1.0f;
    playerStats.layer.borderColor = [[UIColor grayColor] CGColor];
    //    receivedMessageView.contentInset = UIEdgeInsetsMake(7.0,7.0,0,0.0);
    [playerStats setDataDetectorTypes:UIDataDetectorTypeLink];
    [playerStats setUserInteractionEnabled:YES];
//    [playerStats.scrollView setScrollEnabled:NO];
    [playerStats setDelegate:self];
    //    playerStats.contentInset = UIEdgeInsetsMake(-5.0,0.0,0,0.0);
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat newOriginY = screenHeight - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height;
    if (showAds) {
        //        playerStats = [[UIWebView alloc] initWithFrame:CGRectMake(2, submitButton.frame.origin.y + submitButton.frame.size.height + 3, self.view.bounds.size.width - 4, 84)];
        playerStats.frame = CGRectMake(2, blackStoneCaptures.frame.origin.y + 3 + blackStoneCaptures.frame.size.height, self.view.bounds.size.width - 4,  newOriginY - blackStoneCaptures.frame.origin.y - GAD_SIZE_320x50.height -5 -  blackStoneCaptures.frame.size.height);
    } else {
        playerStats.frame = CGRectMake(2, blackStoneCaptures.frame.origin.y +  3 + blackStoneCaptures.frame.size.height, self.view.bounds.size.width - 4, newOriginY - blackStoneCaptures.frame.origin.y - 5 -  blackStoneCaptures.frame.size.height);
//        playerStats = [[UIWebView alloc] initWithFrame:CGRectMake(2, submitButton.frame.origin.y + 3, self.view.bounds.size.width - 4, 135)];
    }
    [self.view addSubview: playerStats];
    if (showAds) {
        CGPoint origin = CGPointMake(0.0, self.view.frame.size.height - self.navigationController.navigationBar.frame.size.height - kGADAdSizeBanner.size.height);
        bannerView = [[GADBannerView alloc] initWithAdSize:kGADAdSizeBanner origin:origin];
        bannerView.rootViewController = self;
        [bannerView setDelegate: self];
        CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
        CGFloat newOriginY = screenHeight - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height - bannerView.frame.size.height;
        CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
        //        NSLog(@"kitty %f", newOriginY);
        bannerView.frame = newBannerViewFrame;
        bannerView.adUnitID = @"ca-app-pub-3326997956703582/6122026245";
        GADRequest *request = [GADRequest request];
        [bannerView loadRequest:request];
        [self.view addSubview:bannerView];
    }

    
    movesList = [[NSMutableArray alloc] init];
    [self resetState];
    self.progressView = [[ICDMaterialActivityIndicatorView alloc]initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) activityIndicatorStyle:ICDMaterialActivityIndicatorViewStyleLarge];
    [self.progressView setBackgroundColor:[UIColor whiteColor]];
    [self.progressView setAlpha:0.75];
}

- (void)viewWillAppear:(BOOL)animated {
    //    NSLog(@"kittyAppear %i", finalMove);
    [super viewWillAppear:animated];
    if (!showedAd) {
        [zoomedBoard setHidden:YES];
        [zoomedStone setHidden:YES];
        [stone setHidden:YES];
        [stone setBounds:CGRectMake(0, 0, 1.2*self.board.bounds.size.width/19,1.2*self.board.bounds.size.width/19)];
        [zoomedStone setBounds:CGRectMake(0, 0, 1.2*1.5*2*self.board.bounds.size.width/19,1.2*1.5*2*self.board.bounds.size.width/19)];
        finalMove = -1;
        [whiteStoneCaptures setStoneColor:[UIColor whiteColor]];
        [blackStoneCaptures setStoneColor:[UIColor blackColor]];
        [horizontalLine setHidden:YES];
        [verticalLine setHidden:YES];
    } else {
        showedAd = NO;
    }
    
}


- (void)viewDidAppear:(BOOL)animated {
    if ([movesList count] < 2) {
        [self showSetup];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [bannerView removeFromSuperview];
}

- (void)adViewWillPresentScreen:(GADBannerView *)bannerView {
    showedAd = YES;
}

//- (void)adViewWillDismissScreen:(GADBannerView *)bannerView {
//}


- (void)viewDidUnload
{
    [self setBoard:nil];
    [self setZoomedBoard:nil];
    [self setStone:nil];
    [self setZoomedStone:nil];
    [self setWhiteCapturesCountLabel:nil];
    [self setBlackCapturesCountLabel:nil];
    [self setWhiteStoneCaptures:nil];
    [self setBlackStoneCaptures:nil];
    [self setSpinner:nil];
    [self setVerticalLine:nil];
    [self setHorizontalLine:nil];
    [self setMovesList: nil];
    [self setBoardTapRecognizer:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return ((interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown)
            && (interfaceOrientation != UIInterfaceOrientationLandscapeLeft) && (interfaceOrientation != UIInterfaceOrientationLandscapeRight));
}
-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
    //    return UIInterfaceOrientationLandscapeLeft | UIInterfaceOrientationLandscapeRight | UIInterfaceOrientationPortrait;
}

//-(void) startGame: (id) sender {
//    aiThinking = NO;
//    [((UIButton *) sender) setTitle:@"restart game" forState:UIControlStateNormal];
//    if (aiPlayer == nil) {
////        NSLog(@"kitty");
//        aiPlayer = [[MMAI alloc] init];
//    }
//    [aiPlayer reset];
////    [aiPlayer setLevel:[setupView.difficultyCell.detailTextLabel.text intValue]];
////    [aiPlayer setSeat: ([setupView.colorCell.detailTextLabel.text isEqualToString:@"white"]?2:1)];
////    NSLog(@"kitty %@", setupView.colorCell.detailTextLabel.text);
//    [aiPlayer addMove:180];
//    [aiPlayer setGame: ([setupView.gameCell.detailTextLabel.text isEqualToString:@"Pente"]?1:2)];
//    if (aiPlayer.seat == 1) {
//        [stone setStoneColor: [UIColor blackColor]];
//        [zoomedStone setStoneColor: [UIColor blackColor]];
//        activeGame = YES;
//        [self replayGame:[[aiPlayer moves] count]];
//    } else {
//        [stone setStoneColor: [UIColor whiteColor]];
//        [zoomedStone setStoneColor: [UIColor whiteColor]];
//        [self getNewAImove];
//    }
//    [stone setNeedsDisplay];
//    [zoomedStone setNeedsDisplay];
//    
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setInteger:[aiPlayer level] forKey:@"MMAILevel"];
////    [defaults setObject: setupView.colorCell.detailTextLabel.text forKey: @"MMAIColor"];
//    [defaults setObject: setupView.gameCell.detailTextLabel.text forKey: @"MMAIGame"];
//}

- (IBAction)goBackOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    if ([movesList count] > 1) {
        [movesList removeLastObject];
        [self replayGame];
        [board setDbOptions:nil];
        [zoomedBoard setDbOptions:nil];
    }
//    if ([[aiPlayer moves] count] > 1 && !aiThinking) {
//        [[aiPlayer moves] removeLastObject];
////        [self replayGame:[[aiPlayer moves] count]];
//        if (aiPlayer.seat == 1 + [[aiPlayer moves] count]%2) {
//            activeGame = NO;
//        } else {
//            activeGame = YES;
//        }
//    }
}

- (IBAction)boardTap:(UILongPressGestureRecognizer *)recognizer {
    int i, j;
    CGPoint currentPoint = [recognizer locationInView: self.board];
    float cellSize = self.board.bounds.size.width / 19;
    j = (int) floorf(currentPoint.x/cellSize);
    i = (int) floorf(currentPoint.y/cellSize);
    
    switch ([recognizer state]) {
        case UIGestureRecognizerStateBegan:
            if ([movesList count]%2 == 1) {
                [stone setStoneColor:[UIColor blackColor]];
                [zoomedStone setStoneColor:[UIColor blackColor]];
            } else {
                [stone setStoneColor:[UIColor whiteColor]];
                [zoomedStone setStoneColor:[UIColor whiteColor]];
            }
            [stone setNeedsDisplay];
            [zoomedStone setNeedsDisplay];
            [zoomedBoard setHidden: NO];
            [stone setHidden: YES];
            if (abstractBoard[i][j] == 0) {
                [zoomedStone setHidden: NO];
                [horizontalLine setHidden:NO];
                [verticalLine setHidden:NO];
            }
            break;
        case UIGestureRecognizerStateEnded:
            [zoomedBoard setHidden: YES];
            if (abstractBoard[i][j] == 0) {
                stone.center = CGPointMake(cellSize*j + cellSize/2, cellSize*i + cellSize/2);
                [zoomedStone setHidden: YES];
                [horizontalLine setHidden:YES];
                [verticalLine setHidden:YES];

                finalMove = 19*i + j;
                
//                [aiPlayer addMove: finalMove];
//                [self replayGame:[[aiPlayer moves] count]];
//                if (activeGame) {
//                    activeGame = NO;
//                    spinner.center = stone.center;
//                    [spinner setColor: ([[aiPlayer moves] count]%2 == 1) ? [UIColor blackColor]:[UIColor whiteColor]];
//                    [spinner setHidden:NO];
//                    [spinner startAnimating];
//                    aiThinking = YES;
//                    [NSThread detachNewThreadSelector:@selector(getNewAImove) toTarget:self withObject:nil];
//                }
                
//                [self detectCaptureOfOpponent:(([[stone stoneColor] isEqual: [UIColor blackColor]]) ? 1 : 2) atPosition: finalMove];
                abstractBoard[i][j] = 1 + ([movesList count]%2);
                [movesList addObject:[NSNumber numberWithInt:finalMove]];
                NSString *game = setupView.gameCell.detailTextLabel.text;
                if (![game isEqualToString:@"Gomoku"]) {
                    int color = 2 - ([movesList count] % 2), opponentColor = (color == 2) ? 1 : 2;
                    if ([game isEqualToString:@"Poof-Pente"]) {
                        [self detectPoof:color atPosition:finalMove];
                    }
                    [self detectCaptureOfOpponent:opponentColor atPosition:finalMove];
                    if ([game isEqualToString:@"Keryo-Pente"]) {
                        [self detectKeryoCaptureOfOpponent:opponentColor atPosition:finalMove];
                    }
                    if ([game isEqualToString:@"G-Pente"] && [movesList count] == 2) {
                        for(int i = 7; i < 12; ++i) {
                            for(int j = 7; j < 12; ++j) {
                                if (abstractBoard[i][j] == 0) {
                                    abstractBoard[i][j] = -1;
                                }
                            }
                        }
                        for(int i = 1; i < 3; ++i) {
                            if (abstractBoard[9][11 + i] == 0) {
                                abstractBoard[9][11 + i] = -1;
                            }
                            if (abstractBoard[9][7 - i] == 0) {
                                abstractBoard[9][7 - i] = -1;
                            }
                            if (abstractBoard[11 + i][9] == 0) {
                                abstractBoard[11 + i][9] = -1;
                            }
                            if (abstractBoard[7 - i][9] == 0) {
                                abstractBoard[7 - i][9] = -1;
                            }
                        }
                    } else if ([game isEqualToString:@"G-Pente"] && [movesList count] == 3) {
                        for(int i = 7; i < 12; ++i) {
                            for(int j = 7; j < 12; ++j) {
                                if (abstractBoard[i][j] == -1) {
                                    abstractBoard[i][j] = 0;
                                }
                            }
                        }
                        for(int i = 1; i < 3; ++i) {
                            if (abstractBoard[9][11 + i] == -1) {
                                abstractBoard[9][11 + i] = 0;
                            }
                            if (abstractBoard[9][7 - i] == -1) {
                                abstractBoard[9][7 - i] = 0;
                            }
                            if (abstractBoard[11 + i][9] == -1) {
                                abstractBoard[11 + i][9] = 0;
                            }
                            if (abstractBoard[7 - i][9] == -1) {
                                abstractBoard[7 - i][9] = 0;
                            }
                        }
                    }
                }
                if (([movesList count]%2) == 1) {
                    [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%lu.</b> ", ([movesList count] >> 1) + 1]];
                } else {
                    [moveStatsString appendString: @" - "];
                }
                [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[finalMove % 19], 19 - (finalMove / 19)]];
                [playerStats loadHTMLString: [playerStatsBaseString stringByAppendingString:moveStatsString] baseURL:nil];
                [board setAbstractBoard: abstractBoard];
                [zoomedBoard setAbstractBoard: abstractBoard];
                [board setDbOptions:nil];
                [zoomedBoard setDbOptions:nil];
                [board setNeedsDisplay];
                [zoomedBoard setNeedsDisplay];
                [self updateCaptures];
            }
            break;
        default: break;
    }
    if ((currentPoint.x < 0) || (currentPoint.x > self.board.bounds.size.width) || (currentPoint.y < 0) || (currentPoint.y > self.board.bounds.size.height)) {
        [zoomedBoard setHidden: YES];
        [zoomedStone setHidden:YES];
        [horizontalLine setHidden:YES];
        [verticalLine setHidden:YES];
    } else {
        if ([zoomedBoard isHidden] && ([recognizer state] != UIGestureRecognizerStateEnded) && (abstractBoard[i][j] == 0)) {
            if (activeGame) {
                [zoomedBoard setHidden: NO];
                [zoomedStone setHidden: NO];
                [stone setHidden: YES];
                [horizontalLine setHidden:NO];
                [verticalLine setHidden:NO];
            } else {
                [zoomedBoard setHidden: NO];
            }
        }
        // re-center the zoomed board.
        zoomedBoard.center = CGPointMake(board.center.x - (currentPoint.x-board.center.x),board.center.y - (currentPoint.y-board.center.y));
        // re-center the stone, re-snap if needed.
        float cellSize = self.zoomedBoard.bounds.size.width / 19;
        if ((fabs(zoomedStone.center.x - 2*currentPoint.x) >= cellSize/2) || (fabs(zoomedStone.center.y - 2*currentPoint.y) >= cellSize/2)) {
            
            zoomedStone.center = CGPointMake(cellSize*j + cellSize/2, cellSize*i + cellSize/2);
            verticalLine.center = CGPointMake(cellSize*j + cellSize/2, zoomedBoard.bounds.size.width/2);
            horizontalLine.center = CGPointMake(zoomedBoard.bounds.size.height/2, cellSize*i + cellSize/2);
            if (abstractBoard[i][j] == 0) {
                [zoomedStone setHidden:NO];
                [horizontalLine setHidden:NO];
                [verticalLine setHidden:NO];
            } else {
                [stone setHidden:YES];
                [zoomedStone setHidden:YES];
                [horizontalLine setHidden:YES];
                [verticalLine setHidden:YES];
            }
        }
    }
}

-(void) searchDB: (UIButton *) sender {
    [self.progressView startAnimating];
    [self.view addSubview:self.progressView];
    NSMutableString *movesStr = [[NSMutableString alloc] init];
    for (NSNumber *move in movesList) {
        int moveInt = [move intValue];
        [movesStr appendString:[NSString stringWithFormat:@"%c%d,", coordinateLetters[moveInt % 19], 19 - (moveInt / 19)]];
    }
    NSString *getStr = [NSString stringWithFormat:@"moves=%@&response_format=org.pente.gameDatabase.SimpleHtmlGameStorerSearchResponseFormat&response_params=%@&results_order=%i&filter_data=%@",[self URLEncodedString_ch:movesStr],
                        [self URLEncodedString_ch:@"zippedPartNumParam=1"],[setupView.sortCell.detailTextLabel.text isEqualToString:@"popularity"]?1:2,
                         [self URLEncodedString_ch:[NSString stringWithFormat:@"start_game_num=0&end_game_num=100&player_1_name=&player_2_name=&game=%@&site=All%%20Sites&event=All%%20Events&round=All%%20Rounds&section=All%%20Sections&winner=0",setupView.gameCell.detailTextLabel.text]]];
    
//    NSLog(@"getkittyyyyyyString -\n%@-", [self URLEncodedString_ch:getStr]);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobileController/search?format_name=org.pente.gameDatabase.SimpleGameStorerSearchRequestFormat&format_data=%@", [self URLEncodedString_ch:getStr]];
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    NSURLResponse *response;
    NSError *error;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//    NSLog(@"kittyyyyyyString -\n%@-", dashboardString);

    [self.progressView stopAnimating];
    [self.progressView removeFromSuperview];
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Reason: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        //        [alert show];
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
        return;
    }
    
    moveStatsString = [[NSMutableString alloc] init];
    for (int i = 0; i < [movesList count]; ++i) {
        int rowCol = [[movesList objectAtIndex:i] intValue];
        if (i == 0) {
            [moveStatsString appendString: @"<center><b>1.</b> "];
        } else {
            if ((i%2) == 0) {
                [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%i.</b> ", (i >> 1) + 1]];
            } else {
                [moveStatsString appendString: @" - "];
            }
        }
        [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % 19], 19 - (rowCol / 19)]];
    }

    NSMutableArray<NSNumber *> *moves = [[NSMutableArray alloc] init];
    NSMutableArray<UIColor *> *colors = [[NSMutableArray alloc] init];
    
    for (NSString *line in [dashboardString componentsSeparatedByString:@"\n"]) {
        if ([line rangeOfString:@"moves="].location == 0) {
//            NSLog(line);
            if ([line rangeOfString:@","].location != NSNotFound) {
                for (NSString *moveString in [[line substringFromIndex:6] componentsSeparatedByString:@","]) {
                    [moves addObject:[NSNumber numberWithInt:[moveString intValue]]];
                }
            }
        }
        if ([line rangeOfString:@"occurrence="].location == 0) {
//            NSLog(line);
            double max = 0.0, min = DBL_MAX;
            if ([line rangeOfString:@";"].location != NSNotFound) {
                for (NSString *moveString in [[line substringFromIndex:11] componentsSeparatedByString:@";"]) {
                    double dblValue = [moveString doubleValue];
                    if (max < dblValue) {
                        max = dblValue;
                    }
                    if (min > dblValue) {
                        min = dblValue;
                    }
                }
    //            double i = 0.0;
                for (NSString *moveString in [[line substringFromIndex:11] componentsSeparatedByString:@";"]) {
                    double dblValue = ([moveString doubleValue]-min)/(max-min);
                    if (dblValue <= 0.5) {
                        [colors addObject: [UIColor colorWithRed:1.0 green:(dblValue/0.5) blue:0 alpha:1]];
                    } else {
                        [colors addObject: [UIColor colorWithRed:(1.0-dblValue)/0.5 green:1 blue:0 alpha:1]];
                    }
    //                if (i < [moves count]/2) {
    //                    [colors addObject: [UIColor colorWithRed:(2.0*i/[moves count]) green:1.0 blue:0 alpha:1]];
    //                } else {
    //                    [colors addObject: [UIColor colorWithRed:1.0 green:(2.0*(i-[moves count]/2.0)/[moves count]) blue:0 alpha:1]];
    //                }
    //                i+=1;
    //                [colors addObject: [UIColor colorWithHue:(dblValue-min)/(2*max) saturation:1.0 brightness:1.0 alpha:1.0]];
    //                NSLog(@"%f", dblValue);
                }
            }
            break;
        }
    }
    if ([moves count] == 0) {
        dashboardString = @"No search results";
    }
    [playerStats loadHTMLString: [[moveStatsString stringByAppendingString:@"</center><br>"] stringByAppendingString:dashboardString] baseURL:nil];

    NSMutableDictionary<NSNumber *, UIColor *> *dbOptions = [[NSMutableDictionary alloc] init];
    for ( int i = 0; i < [moves count];  ++i ) {
        [dbOptions setObject: [colors objectAtIndex:i] forKey:[moves objectAtIndex: i]];
    }
//    dbOptions = [NSDictionary dictionaryWithObjects:colors forKeys:moves count:[moves count]];
    [board setDbOptions:dbOptions];
    [zoomedBoard setDbOptions:dbOptions];
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
}


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([segue.identifier isEqualToString:@"viewGameSegue"]){
        boardController = (BoardViewController *)segue.destinationViewController;
        return;
    }
}
-(void)webViewDidFinishLoad:(UIWebView *)webView {
//    NSInteger height = [[webView stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight;"] intValue];
//    NSString* javascript = [NSString stringWithFormat:@"window.scrollBy(0, %ld);", (long)height];
//    [webView stringByEvaluatingJavaScriptFromString:javascript];
    //    NSLog(@"kitty");
    playerStats.scrollView.contentOffset = CGPointMake(0, 0);
}



-(BOOL) webView:(UIWebView *)inWeb shouldStartLoadWithRequest:(NSURLRequest *)inRequest navigationType:(UIWebViewNavigationType)inType {
    if ( inType == UIWebViewNavigationTypeLinkClicked ) {
        NSString *urlString = [[inRequest URL] absoluteString];

        if ([urlString rangeOfString:@"mobile&g="].location != NSNotFound) {
            
            NSString *gameStr = [urlString substringFromIndex:[urlString rangeOfString:@"="].location + 1];
            if ([gameStr length] == 14 && [gameStr rangeOfString:@"5"].location != 0) {
                SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress: urlString];
                //        [webViewController setDelegate:self];
                [self.navigationController pushViewController:webViewController animated:YES];
                return NO;
            }
            [self performSegueWithIdentifier:@"viewGameSegue" sender:self];
            //        NSLog(@"kittyy %@", gameStr);
            Game *game = [[Game alloc] init];
            [game setGameID: gameStr];
            //        [game setGameType:@"Connect6"];
//            [game setOpponentName:author];
            [game setRemainingTime:@"0 days"];
            //        [game setOpponentRating:[splitLine objectAtIndex:3]];
            //        [game setMyColor:[splitLine objectAtIndex:4]];
            //        [game setRemainingTime:[splitLine objectAtIndex:5]];
            //        [game setRatedNot:[splitLine objectAtIndex:6]];
            //        [game setNameColor: UIColorFromRGB([[splitLine objectAtIndex:7] intValue])];
            
            [boardController setShowAds: showAds];
            [boardController setActiveGame:NO];
            [boardController setGame:game];
            [boardController replayGame];
            [[boardController boardTapRecognizer] setEnabled: NO];
            return NO;
            
        }
        //        if ([urlString rangeOfString:@"mobile&g="].location != NSNotFound) {
        //            [self performSegueWithIdentifier:@"viewGameTap" sender:self];
        //            BoardViewController *boardController = [[BoardViewController alloc] init];
        //
        //            NSString *gameStr = [urlString substringFromIndex:[urlString rangeOfString:@"="].location + 1];
        //            Game *game = [[Game alloc] init];
        //            [game setGameID: gameStr];
        ////            [game setOpponentName:author];
        //            [game setRemainingTime:@"0 days"];
        //
        //            [boardController setShowAds: showAds];
        //            [boardController setActiveGame:NO];
        //            [boardController setGame:game];
        //            [boardController replayGame];
        //            [[boardController boardTapRecognizer] setEnabled: NO];
        //            return NO;
        //
        //        }
        SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress: urlString];
        //        [webViewController setDelegate:self];
        [self.navigationController pushViewController:webViewController animated:YES];
        return NO;
    }
    
    return YES;
}



//-(void) getNewAImove {
//    [aiPlayer getMove];
////    NSLog(@"kitty move %i", newMove);
//    activeGame = YES;
//    [self replayGame:[[aiPlayer moves] count]];
//    aiThinking = NO;
//    [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
//}




- (void) updateCaptures {
    [whiteCapturesCountLabel setText:[NSString stringWithFormat:@"x %i",whiteCaptures]];
    [whiteCapturesCountLabel setNeedsDisplay];
    [blackCapturesCountLabel setText:[NSString stringWithFormat:@"x %i",blackCaptures]];
    [blackCapturesCountLabel setNeedsDisplay];
}


//-(void) replayGame: (unsigned long) untilMove {
//    if (aiPlayer.game == 1) {
//        [self replayPenteGame: untilMove];
//    } else {
//        [self replayKeryoPenteGame: untilMove];
//    }
//}

-(void) replayPenteGame: (unsigned long) untilMove {
    [self resetBoard];
    whiteCaptures = 0;
    blackCaptures = 0;
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [[[aiPlayer moves] objectAtIndex:i] intValue];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
    
    [board setAbstractBoard: abstractBoard];
    [board setLastMove: [[[aiPlayer moves] objectAtIndex:untilMove - 1] intValue]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove: [[[aiPlayer moves] objectAtIndex:untilMove - 1] intValue]];
    }
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
    [self updateCaptures];
    
    NSString *message = nil;
    BOOL iWin = YES;
    if ([self detectPenteOf: 2-([[aiPlayer moves] count]%2) atPosition: [[[aiPlayer moves] lastObject] intValue]]) {
        if (2-([[aiPlayer moves] count]%2) == 1) {
            message = @"White wins";
        } else {
            message = @"Black wins";
        }
    } else if (whiteCaptures == 10) {
        message = @"Black wins";
    } else if (blackCaptures == 10) {
        message = @"White wins";
    }
    if (message) {
        activeGame = NO;
        [TSMessage showNotificationInViewController:self.navigationController
                                              title: @"Game Over"
                                           subtitle: message
                                              image:nil
                                               type: (iWin?TSMessageNotificationTypeSuccess:TSMessageNotificationTypeError)
                                           duration:TSMessageNotificationDurationAutomatic
                                           callback: ^{
                                               [TSMessage dismissActiveNotification];
                                           }
                                        buttonTitle: nil
                                     buttonCallback:nil
                                         atPosition:TSMessageNotificationPositionBottom
                               canBeDismissedByUser:YES];
    }

    int i = 0;
    for (NSNumber *move in [aiPlayer moves]) {
        int rowCol = [move intValue];
        if (i == 0) {
            [moveStatsString appendString: @"<b>1.</b> "];
        } else {
            if ((i%2) == 0) {
                [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%i.</b> ", (i >> 1) + 1]];
            } else {
                [moveStatsString appendString: @" - "];
            }
        }
        [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % 19], 19 - (rowCol / 19)]];
        ++i;
    }
    [playerStats loadHTMLString: moveStatsString baseURL:nil];

}

-(void) replayKeryoPenteGame: (unsigned long) untilMove {
    [self resetBoard];
    whiteCaptures = 0;
    blackCaptures = 0;
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [[[aiPlayer moves] objectAtIndex:i] intValue];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
        [self detectKeryoCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
//    if ([[game ratedNot] isEqualToString:@"Rated"] && ([movesList count] == 2)) {
//        for(int i = 7; i < 12; ++i) {
//            for(int j = 7; j < 12; ++j) {
//                if (abstractBoard[i][j] == 0) {
//                    abstractBoard[i][j] = -1;
//                }
//            }
//        }
//    }
    
    
    //NSLog(@" kitty moves %i",abstractBoard[0][0]);
    [board setAbstractBoard: abstractBoard];
    [board setAbstractBoard: abstractBoard];
    [board setLastMove: [[[aiPlayer moves] objectAtIndex:untilMove - 1] intValue]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove: [[[aiPlayer moves] objectAtIndex:untilMove - 1] intValue]];
    }
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
    [self updateCaptures];

    NSString *message = nil;
    BOOL iWin = YES;
    if ([self detectPenteOf: 2-([[aiPlayer moves] count]%2) atPosition: [[[aiPlayer moves] lastObject] intValue]]) {
        if (2-([[aiPlayer moves] count]%2) == 1) {
            message = @"White wins";
        } else {
            message = @"Black wins";
        }
    } else if (whiteCaptures >= 15) {
        message = @"Black wins";
    } else if (blackCaptures >= 15) {
        message = @"White wins";
    }
    if (message) {
        activeGame = NO;
        [TSMessage showNotificationInViewController:self.navigationController
                                              title: @"Game Over"
                                           subtitle: message
                                              image:nil
                                               type: (iWin?TSMessageNotificationTypeSuccess:TSMessageNotificationTypeError)
                                           duration:TSMessageNotificationDurationAutomatic
                                           callback: ^{
                                               [TSMessage dismissActiveNotification];
                                           }
                                        buttonTitle: nil
                                     buttonCallback:nil
                                         atPosition:TSMessageNotificationPositionBottom
                               canBeDismissedByUser:YES];
    }
    
    int i = 0;
    for (NSNumber *move in [aiPlayer moves]) {
        int rowCol = [move intValue];
        if (i == 0) {
            [moveStatsString appendString: @"<b>1.</b> "];
        } else {
            if ((i%2) == 0) {
                [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%i.</b> ", (i >> 1) + 1]];
            } else {
                [moveStatsString appendString: @" - "];
            }
        }
        [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % 19], 19 - (rowCol / 19)]];
        ++i;
    }
    [playerStats loadHTMLString: moveStatsString baseURL:nil];
}


-(void) replayGame {
    [self resetBoard];
    int i = 0;
    NSString *game = setupView.gameCell.detailTextLabel.text;
    for (NSNumber *move in movesList) {
        int rowCol = [move intValue];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        i+=1;
        if (![game isEqualToString:@"Gomoku"]) {
            if ([game isEqualToString:@"Poof-Pente"]) {
                [self detectPoof:color atPosition:rowCol];
            }
            [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
            if ([game isEqualToString:@"Keryo-Pente"]) {
                [self detectKeryoCaptureOfOpponent:opponentColor atPosition:rowCol];
            }
        } else {
            continue;
        }
    }
    if ([game isEqualToString:@"G-Pente"] && [movesList count] == 2) {
        for(int i = 7; i < 12; ++i) {
            for(int j = 7; j < 12; ++j) {
                if (abstractBoard[i][j] == 0) {
                    abstractBoard[i][j] = -1;
                }
            }
        }
        for(int i = 1; i < 3; ++i) {
            if (abstractBoard[9][11 + i] == 0) {
                abstractBoard[9][11 + i] = -1;
            }
            if (abstractBoard[9][7 - i] == 0) {
                abstractBoard[9][7 - i] = -1;
            }
            if (abstractBoard[11 + i][9] == 0) {
                abstractBoard[11 + i][9] = -1;
            }
            if (abstractBoard[7 - i][9] == 0) {
                abstractBoard[7 - i][9] = -1;
            }
        }
    } else if ([game isEqualToString:@"G-Pente"] && [movesList count] == 3) {
        for(int i = 7; i < 12; ++i) {
            for(int j = 7; j < 12; ++j) {
                if (abstractBoard[i][j] == -1) {
                    abstractBoard[i][j] = 0;
                }
            }
        }
        for(int i = 1; i < 3; ++i) {
            if (abstractBoard[9][11 + i] == -1) {
                abstractBoard[9][11 + i] = 0;
            }
            if (abstractBoard[9][7 - i] == -1) {
                abstractBoard[9][7 - i] = 0;
            }
            if (abstractBoard[11 + i][9] == -1) {
                abstractBoard[11 + i][9] = 0;
            }
            if (abstractBoard[7 - i][9] == -1) {
                abstractBoard[7 - i][9] = 0;
            }
        }
    }

    [board setAbstractBoard: abstractBoard];
    [zoomedBoard setAbstractBoard: abstractBoard];
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
    [self updateCaptures];
    moveStatsString = [[NSMutableString alloc] init];
    for (int i = 0; i < [movesList count]; ++i) {
        int rowCol = [[movesList objectAtIndex:i] intValue];
        if (i == 0) {
            [moveStatsString appendString: @"<b>1.</b> "];
        } else {
            if ((i%2) == 0) {
                [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%i.</b> ", (i >> 1) + 1]];
            } else {
                [moveStatsString appendString: @" - "];
            }
        }
        [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % 19], 19 - (rowCol / 19)]];
    }
    [playerStats loadHTMLString: [playerStatsBaseString stringByAppendingString:moveStatsString] baseURL:nil];
    
}






-(void) detectCaptureOfOpponent: (int) opponentColor atPosition: (int) rowCol {
    int i = rowCol / 19, j = rowCol % 19, myColor = (opponentColor == 1) ? 2 : 1;
    if ((i-3) > -1) {
        if (abstractBoard[i-3][j] == myColor) {
            if ((abstractBoard[i-1][j] == opponentColor) && (abstractBoard[i-2][j] == opponentColor)) {
                abstractBoard[i-1][j] = 0;
                abstractBoard[i-2][j] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if (((i-3) > -1) && ((j-3) > -1)) {
        if (abstractBoard[i-3][j-3] == myColor) {
            if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i-2][j-2] == opponentColor)) {
                abstractBoard[i-1][j-1] = 0;
                abstractBoard[i-2][j-2] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if ((j-3) > -1) {
        if (abstractBoard[i][j-3] == myColor) {
            if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j-2] == opponentColor)) {
                abstractBoard[i][j-1] = 0;
                abstractBoard[i][j-2] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if (((i+3) < 19) && ((j-3) > -1)) {
        if (abstractBoard[i+3][j-3] == myColor) {
            if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor)) {
                abstractBoard[i+1][j-1] = 0;
                abstractBoard[i+2][j-2] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if ((i+3) < 19) {
        if (abstractBoard[i+3][j] == myColor) {
            if ((abstractBoard[i+1][j] == opponentColor) && (abstractBoard[i+2][j] == opponentColor)) {
                abstractBoard[i+1][j] = 0;
                abstractBoard[i+2][j] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if (((i+3) < 19) && ((j+3) < 19)) {
        if (abstractBoard[i+3][j+3] == myColor) {
            if ((abstractBoard[i+1][j+1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor)) {
                abstractBoard[i+1][j+1] = 0;
                abstractBoard[i+2][j+2] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if ((j+3) < 19) {
        if (abstractBoard[i][j+3] == myColor) {
            if ((abstractBoard[i][j+1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor)) {
                abstractBoard[i][j+1] = 0;
                abstractBoard[i][j+2] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
    if (((i-3) > -1) && ((j+3) < 19)) {
        if (abstractBoard[i-3][j+3] == myColor) {
            if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor)) {
                abstractBoard[i-1][j+1] = 0;
                abstractBoard[i-2][j+2] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
}


-(BOOL) detectPenteOf: (int) color atPosition: (int) rowCol {
    BOOL pente = NO;
    int penteCounter = 1;
    int row = rowCol / 19, col = rowCol % 19, i, j;
    i = row - 1;
    j = col;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        i -= 1;
    }
    i = row + 1;
    j = col;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        i += 1;
    }
    if (pente) {
        return pente;
    }
    penteCounter = 1;
    i = row;
    j = col - 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        j -= 1;
    }
    i = row;
    j = col + 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        j += 1;
    }
    if (pente) {
        return pente;
    }
    penteCounter = 1;
    i = row - 1;
    j = col - 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        j -= 1;
        i -= 1;
    }
    i = row + 1;
    j = col + 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        i += 1;
        j += 1;
    }
    if (pente) {
        return pente;
    }
    penteCounter = 1;
    i = row - 1;
    j = col + 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        j += 1;
        i -= 1;
    }
    i = row + 1;
    j = col - 1;
    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
        if (color == abstractBoard[i][j]) {
            penteCounter += 1;
            pente = (penteCounter > 4);
        } else {
            break;
        }
        i += 1;
        j -= 1;
    }

    return pente;
}

-(void) detectKeryoCaptureOfOpponent: (int) opponentColor atPosition: (int) rowCol {
    int i = rowCol / 19, j = rowCol % 19, myColor = (opponentColor == 1) ? 2 : 1;
    if ((i-4) > -1) {
        if (abstractBoard[i-4][j] == myColor) {
            if ((abstractBoard[i-1][j] == opponentColor) && (abstractBoard[i-2][j] == opponentColor) && (abstractBoard[i-3][j] == opponentColor)) {
                abstractBoard[i-1][j] = 0;
                abstractBoard[i-2][j] = 0;
                abstractBoard[i-3][j] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if (((i-4) > -1) && ((j-4) > -1)) {
        if (abstractBoard[i-4][j-4] == myColor) {
            if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i-2][j-2] == opponentColor) && (abstractBoard[i-3][j-3] == opponentColor)) {
                abstractBoard[i-1][j-1] = 0;
                abstractBoard[i-2][j-2] = 0;
                abstractBoard[i-3][j-3] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if ((j-4) > -1) {
        if (abstractBoard[i][j-4] == myColor) {
            if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j-2] == opponentColor) && (abstractBoard[i][j-3] == opponentColor)) {
                abstractBoard[i][j-1] = 0;
                abstractBoard[i][j-2] = 0;
                abstractBoard[i][j-3] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if (((i+4) < 19) && ((j-4) > -1)) {
        if (abstractBoard[i+4][j-4] == myColor) {
            if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor) && (abstractBoard[i+3][j-3] == opponentColor)) {
                abstractBoard[i+1][j-1] = 0;
                abstractBoard[i+2][j-2] = 0;
                abstractBoard[i+3][j-3] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if ((i+4) < 19) {
        if (abstractBoard[i+4][j] == myColor) {
            if ((abstractBoard[i+1][j] == opponentColor) && (abstractBoard[i+2][j] == opponentColor) && (abstractBoard[i+3][j] == opponentColor)) {
                abstractBoard[i+1][j] = 0;
                abstractBoard[i+2][j] = 0;
                abstractBoard[i+3][j] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if (((i+4) < 19) && ((j+4) < 19)) {
        if (abstractBoard[i+4][j+4] == myColor) {
            if ((abstractBoard[i+1][j+1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor) && (abstractBoard[i+3][j+3] == opponentColor)) {
                abstractBoard[i+1][j+1] = 0;
                abstractBoard[i+2][j+2] = 0;
                abstractBoard[i+3][j+3] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if ((j+4) < 19) {
        if (abstractBoard[i][j+4] == myColor) {
            if ((abstractBoard[i][j+1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor) && (abstractBoard[i][j+3] == opponentColor)) {
                abstractBoard[i][j+1] = 0;
                abstractBoard[i][j+2] = 0;
                abstractBoard[i][j+3] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
    if (((i-4) > -1) && ((j+4) < 19)) {
        if (abstractBoard[i-4][j+4] == myColor) {
            if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor) && (abstractBoard[i-3][j+3] == opponentColor)) {
                abstractBoard[i-1][j+1] = 0;
                abstractBoard[i-2][j+2] = 0;
                abstractBoard[i-3][j+3] = 0;
                if (opponentColor == 1) {
                    whiteCaptures += 3;
                } else {
                    blackCaptures += 3;
                }
            }
        }
    }
}


-(BOOL) detectPoof: (int) myColor atPosition: (int) rowCol {
    BOOL poof = NO;
    struct Capture capture;
    int i = rowCol / 19, j = rowCol % 19, opponentColor = (myColor == 1) ? 2 : 1, capturesLength = (int) [captures count];
    if (((i-2) > -1) && ((i+1) < 19)) {
        if (abstractBoard[i-1][j] == myColor) {
            if ((abstractBoard[i-2][j] == opponentColor) && (abstractBoard[i+1][j] == opponentColor)) {
                poof = YES;
                abstractBoard[i-1][j] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i-1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                
            }
        }
    }
    if (((i-2) > -1) && ((j-2) > -1) && ((i+1) < 19) && ((j+1) < 19)) {
        if (abstractBoard[i-1][j-1] == myColor) {
            if ((abstractBoard[i-2][j-2] == opponentColor) && (abstractBoard[i+1][j+1] == opponentColor)) {
                poof = YES;
                abstractBoard[i-1][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i-1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((j-2) > -1) && ((j+1) < 19)) {
        if (abstractBoard[i][j-1] == myColor) {
            if ((abstractBoard[i][j-2] == opponentColor) && (abstractBoard[i][j+1] == opponentColor)) {
                poof = YES;
                abstractBoard[i][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((i-1) > -1) && ((j-2) > -1) && ((i+2) < 19) && ((j+1) < 19)) {
        if (abstractBoard[i+1][j-1] == myColor) {
            if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor)) {
                poof = YES;
                abstractBoard[i+1][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((i+2) < 19) && ((i-1) > -1)) {
        if (abstractBoard[i+1][j] == myColor) {
            if ((abstractBoard[i+2][j] == opponentColor) && (abstractBoard[i-1][j] == opponentColor)) {
                poof = YES;
                abstractBoard[i+1][j] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((i-1) > -1) && ((j-1) > -1) && ((i+2) < 19) && ((j+2) < 19)) {
        if (abstractBoard[i+1][j+1] == myColor) {
            if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor)) {
                poof = YES;
                abstractBoard[i+1][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((j+2) < 19) && ((j-1) > -1)) {
        if (abstractBoard[i][j+1] == myColor) {
            if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor)) {
                poof = YES;
                abstractBoard[i][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    if (((i-2) > -1) && ((j-1) > -1) && ((i+1) < 19) && ((j+2) < 19)) {
        if (abstractBoard[i-1][j+1] == myColor) {
            if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor)) {
                poof = YES;
                abstractBoard[i-1][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    ++whiteCaptures;
                } else {
                    ++blackCaptures;
                }
                capture.color = myColor;
                capture.position = (i-1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
            }
        }
    }
    
    if (poof) {
        if (myColor == 1) {
            ++whiteCaptures;
        } else {
            ++blackCaptures;
        }
        capture.color = myColor;
        capture.position = i*19 + j;
        [captures insertObject:[NSValue value:&capture withObjCType:@encode(struct Capture)] atIndex: capturesLength];
    }
    return poof;
}


-(void) resetBoard {
    for(int i = 0; i < 19; ++i) {
        for(int j = 0; j < 19; ++j) {
            abstractBoard[i][j] = 0;
        }
    }
    [captures removeAllObjects];
    whiteCaptures = 0;
    blackCaptures = 0;
    [self updateCaptures];
}

-(void) resetState {
    moveStatsString = [[NSMutableString alloc] init];
    [moveStatsString appendString: @"<b>1.</b> K10"];
    [playerStats loadHTMLString: [playerStatsBaseString stringByAppendingString:moveStatsString] baseURL:nil];
    [self resetBoard];
    abstractBoard[9][9] = 1;
    [movesList removeAllObjects];
    [movesList addObject: [NSNumber numberWithInt:180]];
    [board setAbstractBoard: abstractBoard];
    [zoomedBoard setAbstractBoard: abstractBoard];
}


-(void) showSetup {
    
    setupView = [[DBSetupView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*2/3, 88)];
    [setupView setScrollEnabled:NO];
    [setupView setDelegate: setupView];
    [setupView setDataSource: setupView];
    [setupView setBoard: board];
    [setupView setZBoard:zoomedBoard];
    messagePopover = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width - 20, 0) inView:self.view withTitle: @"settings" withContentView: setupView delegate:self];
    [messagePopover layoutSubviews];
    
}

- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    if ([setupView.gameCell.detailTextLabel.text isEqualToString:@"Gomoku"]) {
        [whiteStoneCaptures setHidden:YES];
        [whiteCapturesCountLabel setHidden:YES];
        [blackStoneCaptures setHidden:YES];
        [blackCapturesCountLabel setHidden:YES];
    } else {
        [whiteStoneCaptures setHidden:NO];
        [whiteCapturesCountLabel setHidden:NO];
        [blackStoneCaptures setHidden:NO];
        [blackCapturesCountLabel setHidden:NO];
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




@end
