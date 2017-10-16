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
#import "TSMessage.h"
#import "TSMessageView.h"
#import "MMAI.h"
#import "BoardViewController.h"
#import "penteLive-Swift.h"




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
@synthesize playerStatsBaseString,game;
@synthesize setupView;
@synthesize progressView;
@synthesize aiButton;
@synthesize aiSetupView;

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
    
    [self setTitle:NSLocalizedString(@"Database & AI",nil)];
    [self setTitle:NSLocalizedString(@"Database",nil)];
    
    
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
    [board setAbstractBoard: abstractBoard];
    [zoomedBoard setAbstractBoard: abstractBoard];
    
    CGRect rect;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [button setTitle:NSLocalizedString(@"  search  ",nil) forState:UIControlStateNormal];
    [button addTarget:self action:@selector(searchDB:) forControlEvents:UIControlEventTouchUpInside];
    rect = button.frame;
    rect.size = [button intrinsicContentSize];
    rect.origin.y = board.frame.size.height + 2;
    rect.origin.x = self.view.bounds.size.width/2 - rect.size.width /2;
    button.frame = rect;
    [self.view addSubview: button];
    aiButton = [UIButton buttonWithType:UIButtonTypeCustom];
    aiButton.backgroundColor = [UIColor clearColor];
    aiButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [aiButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
//    [aiButton setTitle:NSLocalizedString(@"  search  ",nil) forState:UIControlStateNormal];
    [aiButton setImage:[UIImage imageNamed:@"computer"] forState:UIControlStateNormal];
    [aiButton addTarget:self action:@selector(askAI:) forControlEvents:UIControlEventTouchUpInside];
    rect = button.frame;
    rect.size = [aiButton intrinsicContentSize];
    rect.origin.x = self.view.bounds.size.width - rect.size.width - 15;
    aiButton.frame = rect;
    [self.view addSubview: aiButton];

    
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

    setupView = [[DBSetupView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*4/5, 308)];
    setupView.layer.cornerRadius = 5.0f;
    setupView.layer.borderWidth = 1.0f;
    [setupView setScrollEnabled:NO];
    [setupView setDelegate: setupView];
    [setupView setDataSource: setupView];
    [setupView setBoard: board];
    [setupView setZBoard:zoomedBoard];
    
    if (movesList == nil) {
        movesList = [[NSMutableArray alloc] init];
        [self resetState];
    }
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
//    if ([movesList count] < 2 && game == nil) {
    if (game == nil) {
        [self showSetup];
    } else {
        [self setBoardColor];
        [self replayGame];
        [self searchDB:nil];
    }
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [bannerView removeFromSuperview];
    [super viewWillDisappear:animated];
}

- (void)adViewWillPresentScreen:(GADBannerView *)bannerView {
    showedAd = YES;
}

//- (void)adViewWillDismissScreen:(GADBannerView *)bannerView {
//}
-(void) setBoardColor {
    
    if ([game containsString:@"Keryo-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
    } else if ([game containsString:@"Gomoku"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
    } else if ([game containsString:@"D-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
    } else if ([game containsString:@"G-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
    } else if ([game containsString:@"Poof-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    } else if ([game containsString:@"Connect6"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    } else if ([game containsString:@"Boat-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
    } else if ([game containsString:@"DK-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:1 green:165.0/255.0 blue:0 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:1 green:165.0/255.0 blue:0 alpha:1]];
    } else if ([game containsString:@"Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
    }
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
    if (game) {
        if ([game isEqualToString:@"Pente"] || [game isEqualToString:@"Speed Pente"] || [game containsString:@"Keryo-Pente"]) {
            [aiButton setHidden:NO];
        } else {
            [aiButton setHidden:YES];
        }
    }

}


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


- (IBAction)goBackOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    [board setLastMove: -1];
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
            [board setLastMove: -1];
            if ([game containsString:@"Connect6"]) {
                if ((([movesList count] % 4) == 0) || (([movesList count] % 4) == 3)) {
                    [stone setStoneColor:[UIColor whiteColor]];
                    [zoomedStone setStoneColor:[UIColor whiteColor]];
                } else {
                    [stone setStoneColor:[UIColor blackColor]];
                    [zoomedStone setStoneColor:[UIColor blackColor]];
                }
            } else if ([movesList count]%2 == 1) {
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
                
                
//                [self detectCaptureOfOpponent:(([[stone stoneColor] isEqual: [UIColor blackColor]]) ? 1 : 2) atPosition: finalMove];
                if ([game containsString:@"Connect6"]) {
                    abstractBoard[i][j] = ((([movesList count] % 4) == 0) || (([movesList count] % 4) == 3)) ? 1 : 2;
                } else {
                    abstractBoard[i][j] = 1 + ([movesList count]%2);
                }
                [movesList addObject:[NSNumber numberWithInt:finalMove]];
                if (game == nil) {
                    game = setupView.gameCell.detailTextLabel.text;
                }
                if (![game containsString:@"Gomoku"] && ![game containsString:@"Connect6"]) {
                    int color = 2 - ([movesList count] % 2), opponentColor = (color == 2) ? 1 : 2;
                    if ([game containsString:@"Poof-Pente"]) {
                        [self detectPoof:color atPosition:finalMove];
                    }
                    [self detectCaptureOfOpponent:opponentColor atPosition:finalMove];
                    if ([game containsString:@"Keryo-Pente"] || [game containsString:@"DK-Pente"]) {
                        [self detectKeryoCaptureOfOpponent:opponentColor atPosition:finalMove];
                    }
                    if ([game containsString:@"G-Pente"] && [movesList count] == 2) {
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
                    } else if ([game containsString:@"G-Pente"] && [movesList count] == 3) {
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
                if ([game containsString:@"Connect6"]) {
                    if ((([movesList count]-3)%4) == 0) {
                        [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%lu.</b> ", ([movesList count] >> 2) + 2]];
                    } else if ((([movesList count]-3)%4) == 2 || [movesList count] == 1) {
                        [moveStatsString appendString: @" - "];
                    } else {
                        [moveStatsString appendString: @"-"];
                    }
                } else if (([movesList count]%2) == 1) {
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
    [board setLastMove: -1];
    [self.progressView startAnimating];
    [self.view addSubview:self.progressView];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
        NSMutableString *movesStr = [[NSMutableString alloc] init];
        for (NSNumber *move in movesList) {
            int moveInt = [move intValue];
            [movesStr appendString:[NSString stringWithFormat:@"%c%d,", coordinateLetters[moveInt % 19], 19 - (moveInt / 19)]];
        }
        NSString *winnerStr = @"0";
        if (setupView.winnerCell.detailTextLabel.text) {
            if ([setupView.winnerCell.detailTextLabel.text isEqualToString:@"player 1"]) {
                winnerStr = @"1";
            } else if ([setupView.winnerCell.detailTextLabel.text isEqualToString:@"player 2"]) {
                winnerStr = @"2";
            }
        }
        NSString *afterStr = setupView.afterCell.textField.text, *beforeStr = setupView.beforeCell.textField.text;
        if (afterStr && ![afterStr isEqualToString:@""]) {
            afterStr = [NSString stringWithFormat:@"&after_date=%@", afterStr];
        } else {
            afterStr = @"";
        }
        if (beforeStr && ![beforeStr isEqualToString:@""]) {
            beforeStr = [NSString stringWithFormat:@"&before_date=%@", beforeStr];
        } else {
            beforeStr = @"";
        }
        NSString *p1Str = [setupView.player1Cell.textField.text lowercaseString];
        if (p1Str == nil) {
            p1Str = @"";
        }
        NSString *p2Str = [setupView.player2Cell.textField.text lowercaseString];
        if (p2Str == nil) {
            p2Str = @"";
        }
        NSString *gameStr;
        if (game) {
            gameStr = game;
        } else {
            gameStr = setupView.gameCell.detailTextLabel.text;
        }
        NSString *getStr = [NSString stringWithFormat:@"moves=%@&response_format=org.pente.gameDatabase.SimpleHtmlGameStorerSearchResponseFormat&response_params=%@&results_order=%i&filter_data=%@",[self URLEncodedString_ch:movesStr],
                            [self URLEncodedString_ch:@"zippedPartNumParam=1"],[setupView.sortCell.detailTextLabel.text isEqualToString:@"popularity"]?1:2,
                            [self URLEncodedString_ch:[NSString stringWithFormat:@"start_game_num=0&end_game_num=100&player_1_name=%@&player_2_name=%@&game=%@&site=All%%20Sites&event=All%%20Events&round=All%%20Rounds&section=All%%20Sections&winner=%@%@%@", p1Str, p2Str, gameStr, winnerStr, afterStr, beforeStr]]];
        
//        NSLog(@"\ngetkittyyyyyyString -\n%@-", [self URLEncodedString_ch:getStr]);
//        NSLog(@"\n\ngetkittyyyyyyString -\n%@-", getStr);
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        NSString *url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobileController/search?format_name=org.pente.gameDatabase.SimpleGameStorerSearchRequestFormat&format_data=%@", [self URLEncodedString_ch:getStr]];
        if (development) {
            url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/mobileController/search?format_name=org.pente.gameDatabase.SimpleGameStorerSearchRequestFormat&format_data=%@", [self URLEncodedString_ch:getStr]];
        }
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"GET"];
        [request setTimeoutInterval:7.0];
        NSURLResponse *response;
        NSError *error;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//            NSLog(@"kittyyyyyyString -\n%@-", dashboardString);
        
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            //        [alert show];
            [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
            [self.progressView stopAnimating];
            [self.progressView removeFromSuperview];
            return;
        }
        
        moveStatsString = [[NSMutableString alloc] init];
        for (int i = 0; i < [movesList count]; ++i) {
            int rowCol = [[movesList objectAtIndex:i] intValue];
            if (i == 0) {
                [moveStatsString appendString: @"<center><b>1.</b> "];
            } else {
                if ([game containsString:@"Connect6"]) {
                    if (((i-3)%4) == 0) {
                        [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%i.</b> ", (i >> 2) + 2]];
                    } else if (((i-3)%4) == 2 || i == 1) {
                        [moveStatsString appendString: @" - "];
                    } else {
                        [moveStatsString appendString: @"-"];
                    }
                } else {
                    if ((i%2) == 0) {
                        [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%i.</b> ", (i >> 1) + 1]];
                    } else {
                        [moveStatsString appendString: @" - "];
                    }
                }
            }
            [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % 19], 19 - (rowCol / 19)]];
        }
        
        NSMutableArray<NSNumber *> *moves = [[NSMutableArray alloc] init];
        NSMutableArray<UIColor *> *colors = [[NSMutableArray alloc] init];
        
        for (NSString *line in [dashboardString componentsSeparatedByString:@"\n"]) {
            if ([line rangeOfString:@"moves="].location == 0) {
//                            NSLog(line);
//                if ([line rangeOfString:@","].location != NSNotFound) {
                if ([line length] > 6) {
                    for (NSString *moveString in [[line substringFromIndex:6] componentsSeparatedByString:@","]) {
                        [moves addObject:[NSNumber numberWithInt:[moveString intValue]]];
                    }
                }
            }
            if ([line rangeOfString:@"occurrence="].location == 0) {
//                            NSLog(line);
                double max = 0.0, min = DBL_MAX;
//                if ([line rangeOfString:@";"].location != NSNotFound) {
                if ([line length] > 11) {
                    for (NSString *moveString in [[line substringFromIndex:11] componentsSeparatedByString:@";"]) {
                        double dblValue = [moveString doubleValue];
                        if (max < dblValue) {
                            max = dblValue;
                        }
                        if (min > dblValue) {
                            min = dblValue;
                        }
                    }
                    if (max == min) {
                        max = 100.0;
                        min = 0.0;
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
        if ([moves count] == 0 && ![dashboardString containsString:@"https://www.pente.org/gameServer/viewLiveGame?mobile&g="]) {
            dashboardString = NSLocalizedString(@"No search results",nil);
        } else {
            NSString *p1Str = [setupView.player1Cell.textField.text lowercaseString], *p2Str = [setupView.player2Cell.textField.text lowercaseString];
            if ((p1Str || p2Str) && !([p1Str isEqualToString:@""] && [p2Str isEqualToString:@""])) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    NSMutableArray *invitedHistory =  [[defaults objectForKey:@"invitedHistory"] mutableCopy];
                    if (invitedHistory) {
                        int i = 0;
                        for ( i = 0; i < [invitedHistory count]; ++i) {
                            if (p1Str && ![p1Str isEqualToString:@""] && [[invitedHistory objectAtIndex:i] localizedCaseInsensitiveCompare:p1Str] == NSOrderedDescending) {
                                if (![invitedHistory containsObject:p1Str]) {
                                    [invitedHistory insertObject:p1Str atIndex:i];
                                }
                            }
                            if (p2Str && ![p2Str isEqualToString:@""] && [[invitedHistory objectAtIndex:i] localizedCaseInsensitiveCompare:p2Str] == NSOrderedDescending) {
                                if (![invitedHistory containsObject:p2Str]) {
                                    [invitedHistory insertObject:p2Str atIndex:i];
                                }
                            }
                        }
                    } else {
                        if (p1Str && ![p1Str isEqualToString:@""]) {
                            invitedHistory = [NSMutableArray arrayWithObject:p1Str];
                        }
                        if (p2Str && ![p2Str isEqualToString:@""]) {
                            if (invitedHistory) {
                                if ([[invitedHistory objectAtIndex:0] localizedCaseInsensitiveCompare:p2Str] == NSOrderedDescending) {
                                    if (![invitedHistory containsObject:p2Str]) {
                                        [invitedHistory insertObject:p2Str atIndex:0];
                                    } else {
                                        [invitedHistory addObject:p2Str];
                                    }
                                }
                            } else {
                                invitedHistory = [NSMutableArray arrayWithObject:p2Str];
                            }
                        }
                    }
                [defaults setObject:invitedHistory forKey:@"invitedHistory"];
                [setupView.player1Cell setInvitedHistory:invitedHistory];
                [setupView.player2Cell setInvitedHistory:invitedHistory];
            }
        }
        NSMutableDictionary<NSNumber *, UIColor *> *dbOptions = [[NSMutableDictionary alloc] init];
        for ( int i = 0; i < [moves count];  ++i ) {
            [dbOptions setObject: [colors objectAtIndex:i] forKey:[moves objectAtIndex: i]];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [playerStats loadHTMLString: [[moveStatsString stringByAppendingString:@"</center><br>"] stringByAppendingString:dashboardString] baseURL:nil];
            //    dbOptions = [NSDictionary dictionaryWithObjects:colors forKeys:moves count:[moves count]];
            [board setDbOptions:dbOptions];
            [zoomedBoard setDbOptions:dbOptions];
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
            [self.progressView stopAnimating];
            [self.progressView removeFromSuperview];
        });
    });
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
            [self performSegueWithIdentifier:@"viewGameSegue" sender:self];
            Game *gameObj = [[Game alloc] init];
            [gameObj setGameID: gameStr];
            [gameObj setRemainingTime:@"0 days"];

            [boardController setShowAds: showAds];
            [boardController setActiveGame:NO];
            [boardController setGame:gameObj];
            [boardController replayGame];
            [[boardController boardTapRecognizer] setEnabled: NO];
            return NO;
            
        }
        PenteWebViewController *webViewController = [[PenteWebViewController alloc] initWithAddress: urlString];
        [self.navigationController pushViewController:webViewController animated:YES];
        return NO;
    }
    
    return YES;
}


-(void) startThinking {
    [messagePopover dismiss];
    if (aiPlayer == nil) {
//        NSLog(@"kitty");
        aiPlayer = [[MMAI alloc] init];
    }
    [aiPlayer reset];
    [aiPlayer setLevel:[aiSetupView.difficultyCell.detailTextLabel.text intValue]];
    [aiPlayer setSeat: 1 + ([movesList count] % 2)];
    [aiPlayer setMoves:movesList];
    if (game) {
        if ([game isEqualToString:@"Pente"] || [game isEqualToString:@"Speed Pente"]) {
            [aiPlayer setGame:1];
        } else if ([game containsString:@"Keryo-Pente"]) {
            [aiPlayer setGame:2];
        }
    } else {
        [aiPlayer setGame: ([setupView.gameCell.detailTextLabel.text containsString:@"Keryo-Pente"]?2:1)];
    }
    [self.progressView startAnimating];
    [self.view addSubview:self.progressView];
    [NSThread detachNewThreadSelector:@selector(getNewAImove) toTarget:self withObject:nil];
}


-(void) getNewAImove {
    finalMove = [aiPlayer getMove];
    [self performSelectorOnMainThread:@selector(stopThinking) withObject:nil waitUntilDone:NO];
}
-(void) stopThinking {
    int i = finalMove / 19;
    int j = finalMove % 19;
    [board setLastMove:finalMove];
    
    //                [self detectCaptureOfOpponent:(([[stone stoneColor] isEqual: [UIColor blackColor]]) ? 1 : 2) atPosition: finalMove];
    abstractBoard[i][j] = 1 + ([movesList count]%2);
    [movesList addObject:[NSNumber numberWithInt:finalMove]];
    if (game == nil) {
        game = setupView.gameCell.detailTextLabel.text;
    }
    int color = 2 - ([movesList count] % 2), opponentColor = (color == 2) ? 1 : 2;
    [self detectCaptureOfOpponent:opponentColor atPosition:finalMove];
    if ([game containsString:@"Keryo-Pente"]) {
        [self detectKeryoCaptureOfOpponent:opponentColor atPosition:finalMove];
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

    [progressView stopAnimating];
    [progressView removeFromSuperview];
}



- (void) updateCaptures {
    [whiteCapturesCountLabel setText:[NSString stringWithFormat:@"x %i",whiteCaptures]];
    [whiteCapturesCountLabel setNeedsDisplay];
    [blackCapturesCountLabel setText:[NSString stringWithFormat:@"x %i",blackCaptures]];
    [blackCapturesCountLabel setNeedsDisplay];
}


-(void) replayGame {
    [self resetBoard];
    int i = 0;
    if (game == nil) {
        game = setupView.gameCell.detailTextLabel.text;
    }
    for (NSNumber *move in movesList) {
        int rowCol = [move intValue];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        if ([game containsString:@"Connect6"]) {
            color = (((i % 4) == 0) || ((i % 4) == 3)) ? 1 : 2;
        }
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        i+=1;
        if (![game containsString:@"Gomoku"] && ![game containsString:@"Connect6"]) {
            if ([game containsString:@"Poof-Pente"]) {
                [self detectPoof:color atPosition:rowCol];
            }
            [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
            if ([game containsString:@"Keryo-Pente"] || [game containsString:@"DK-Pente"]) {
                [self detectKeryoCaptureOfOpponent:opponentColor atPosition:rowCol];
            }
        } else {
            continue;
        }
    }
    if ([game containsString:@"G-Pente"] && [movesList count] == 2) {
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
    } else if ([game containsString:@"G-Pente"] && [movesList count] == 3) {
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
            if ([game containsString:@"Connect6"]) {
                if (((i-3)%4) == 0) {
                    [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%i.</b> ", (i >> 2) + 2]];
                } else if (((i-3)%4) == 2 || i == 1) {
                    [moveStatsString appendString: @" - "];
                } else {
                    [moveStatsString appendString: @"-"];
                }
            } else {
                if ((i%2) == 0) {
                    [moveStatsString appendString: [NSString stringWithFormat:@"&nbsp; <b>%i.</b> ", (i >> 1) + 1]];
                } else {
                    [moveStatsString appendString: @" - "];
                }
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


//-(BOOL) detectPenteOf: (int) color atPosition: (int) rowCol {
//    BOOL pente = NO;
//    int penteCounter = 1;
//    int row = rowCol / 19, col = rowCol % 19, i, j;
//    i = row - 1;
//    j = col;
//    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
//        if (color == abstractBoard[i][j]) {
//            penteCounter += 1;
//            pente = (penteCounter > 4);
//        } else {
//            break;
//        }
//        i -= 1;
//    }
//    i = row + 1;
//    j = col;
//    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
//        if (color == abstractBoard[i][j]) {
//            penteCounter += 1;
//            pente = (penteCounter > 4);
//        } else {
//            break;
//        }
//        i += 1;
//    }
//    if (pente) {
//        return pente;
//    }
//    penteCounter = 1;
//    i = row;
//    j = col - 1;
//    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
//        if (color == abstractBoard[i][j]) {
//            penteCounter += 1;
//            pente = (penteCounter > 4);
//        } else {
//            break;
//        }
//        j -= 1;
//    }
//    i = row;
//    j = col + 1;
//    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
//        if (color == abstractBoard[i][j]) {
//            penteCounter += 1;
//            pente = (penteCounter > 4);
//        } else {
//            break;
//        }
//        j += 1;
//    }
//    if (pente) {
//        return pente;
//    }
//    penteCounter = 1;
//    i = row - 1;
//    j = col - 1;
//    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
//        if (color == abstractBoard[i][j]) {
//            penteCounter += 1;
//            pente = (penteCounter > 4);
//        } else {
//            break;
//        }
//        j -= 1;
//        i -= 1;
//    }
//    i = row + 1;
//    j = col + 1;
//    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
//        if (color == abstractBoard[i][j]) {
//            penteCounter += 1;
//            pente = (penteCounter > 4);
//        } else {
//            break;
//        }
//        i += 1;
//        j += 1;
//    }
//    if (pente) {
//        return pente;
//    }
//    penteCounter = 1;
//    i = row - 1;
//    j = col + 1;
//    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
//        if (color == abstractBoard[i][j]) {
//            penteCounter += 1;
//            pente = (penteCounter > 4);
//        } else {
//            break;
//        }
//        j += 1;
//        i -= 1;
//    }
//    i = row + 1;
//    j = col - 1;
//    while (i > 0 && i < 19 && j > 0 && j < 19 && !pente) {
//        if (color == abstractBoard[i][j]) {
//            penteCounter += 1;
//            pente = (penteCounter > 4);
//        } else {
//            break;
//        }
//        i += 1;
//        j -= 1;
//    }
//
//    return pente;
//}

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
    game = nil;
    messagePopover = [PopoverView showPopoverAtPoint: CGPointMake(self.view.bounds.size.width - 20, 0) inView:self.view withTitle: NSLocalizedString(@"search parameters",nil) withContentView: setupView delegate:self];
    [messagePopover layoutSubviews];
}

-(void) askAI: (UIButton *) sender {
    if (!aiSetupView) {
        aiSetupView = [[DBAISetupView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width*2/3, 147)];
//        aiSetupView.layer.cornerRadius = 5.0f;
//        aiSetupView.layer.borderWidth = 1.0f;
        [aiSetupView setScrollEnabled:NO];
        [aiSetupView setDelegate: aiSetupView];
        [aiSetupView setDataSource: aiSetupView];
        [aiSetupView setVc:self];
    }
    messagePopover = [PopoverView showPopoverAtPoint: CGPointMake(aiButton.center.x, aiButton.frame.origin.y) inView:self.view withTitle: NSLocalizedString(@"ask the AI",nil) withContentView: aiSetupView delegate:self];
    [messagePopover layoutSubviews];
}

- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    NSString *str = game;
    if (!str) {
        str = setupView.gameCell.detailTextLabel.text;
    }
    if ([str containsString:@"Gomoku"] || [str containsString:@"Connect6"]) {
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
    if ([str isEqualToString:@"Pente"] || [game isEqualToString:@"Speed Pente"] || [str containsString:@"Keryo-Pente"]) {
        [aiButton setHidden:NO];
    } else {
        [aiButton setHidden:YES];
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
