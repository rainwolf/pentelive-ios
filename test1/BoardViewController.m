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


#import "BoardViewController.h"
#import "BoardView.h"
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <QuartzCore/QuartzCore.h>
#import "PopoverView.h"
#import "DatabaseViewController.h"
#import <NSHash/NSString+NSHash.h>
#import "penteLive-Swift.h"
#import "TSMessage.h"

#define usernameKey @"username"
#define passwordKey @"password"


//GADBannerView *bannerView_;

@interface BoardViewController ()
@end

@implementation BoardViewController
@synthesize lockButton;
@synthesize game;
@synthesize board;
@synthesize zoomedBoard;
@synthesize stone;
@synthesize zoomedStone;
@synthesize submitButton;
@synthesize player1Button;
@synthesize player2Button;
@synthesize dPenteChoiceLabel;
//@synthesize gamesTable;
@synthesize whiteCapturesCountLabel;
@synthesize whiteStoneCaptures;
@synthesize blackCapturesCountLabel;
@synthesize blackStoneCaptures;
@synthesize spinner;
@synthesize bannerView;
@synthesize showedAd;
@synthesize horizontalLine;
@synthesize verticalLine;
@synthesize movesList;
@synthesize captures;
@synthesize receivedMessage;
@synthesize replyMessage;
@synthesize messageButtonImageView;
@synthesize messageButton;
@synthesize receivedMessageView;
@synthesize replyMessageView;
@synthesize messagePopover;
@synthesize receivedMessages;
@synthesize messagesHistory;
@synthesize activeGame;
@synthesize isLastMove;
@synthesize playerStats;
@synthesize showAds;
@synthesize moveStatsString;
@synthesize playerStatsBaseString;


int abstractBoard[19][19];
int abstractGoBoard[19][19];
int finalMove = -1, connect6Move1 = -1, connect6Move2 = -1, dPenteMove1 = -1, dPenteMove2 = -1, dPenteMove3 = -1, dPenteMove4 = -1,
whiteCaptures, blackCaptures, lastMove;
BOOL dPenteOpening = NO;
BOOL dPenteChoice = NO;
BOOL poofed = NO;
BOOL canHide = NO;
BOOL canUnHide = NO;
char coordinateLetters[19] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T'};
NSString *hideString, *cancelMsg;
struct Capture {
    int color;
    int position;
};

NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSNumber*>*> *goStoneGroupIDsByPlayer;
NSMutableDictionary<NSNumber*, NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>*> *goStoneGroupsByPlayerAndID;
int koMove = -1, gridSize = 19;
NSMutableArray<NSNumber*> *deadWhiteStones, *deadBlackStones, *whiteTerritory, *blackTerritory;
BOOL goMarkStones = NO, goEvaluateDeadStones = NO, go = NO, isGoGame = NO;
NSMutableDictionary<NSNumber*, NSNumber*> *goStoneGroupIDs;
NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*> *goStoneGroups;


- (void)viewDidLoad {
    [super viewDidLoad];
    
	// Do any additional setup after loading the view, typically from a nib.
    showedAd = NO;
    cancelMsg = @"";
    hideString = @"";
    messageButtonImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"messageBubble0.png"]];
    NSArray *images = [NSArray arrayWithObjects: [UIImage imageNamed:@"messageBubble0.png"], [UIImage imageNamed:@"messageBubble1.png"],nil];
    messageButtonImageView.animationImages = images;
    [messageButton addSubview:self.messageButtonImageView];
    
    messageButton.layer.cornerRadius = 5;
    messageButton.layer.masksToBounds = YES;
    [messageButtonImageView setCenter:CGPointMake(messageButton.bounds.size.width/2, messageButton.bounds.size.height/2)];
    [messageButton addTarget:self action:@selector(messageTap:) forControlEvents:UIControlEventTouchUpInside];
    
    
    [board setLastConnect6Move: -1];
    [zoomedBoard setLastConnect6Move: -1];
    [board setLastMove: -1];
    [zoomedBoard setLastMove: -1];

//    [self.navigationController.navigationBar setTranslucent:NO];
//    [self.navigationController setEdgesForExtendedLayout:UIRectEdgeNone];
    [board setFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.width)];
    [zoomedBoard setFrame:CGRectMake(0, 0, 2*self.view.bounds.size.width, 2*self.view.bounds.size.width)];
    CGRect rect;
    rect = submitButton.frame;
//    rect.origin.y = board.frame.size.height + 2 + submitButton.frame.size.height;
    rect.origin.y = board.frame.size.height + 2;
    rect.origin.x = (board.frame.size.width - submitButton.frame.size.width)/2;
    submitButton.frame = rect;
    
    lockButton = [[UIButton alloc] initWithFrame:rect];
    rect.size.width = rect.size.height;
    rect.origin.x = board.frame.size.width - rect.size.width - 10;
    [lockButton setTitle:nil forState:UIControlStateNormal];
    [lockButton setFrame:rect];
    [lockButton addTarget: self action:@selector(toggleBoardLock:) forControlEvents: UIControlEventTouchUpInside];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"notBack2Dash"]) {
        [lockButton setImage:[UIImage imageNamed:@"lock.png"] forState: UIControlStateNormal];
    } else {
        [lockButton setImage:[UIImage imageNamed:@"unlock.png"] forState: UIControlStateNormal];
    }
    [self.view addSubview: lockButton];

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

    rect = player1Button.frame;
    rect.origin.y = board.frame.size.height + 2 ;
    //    rect.origin.x = (board.frame.size.width - submitButton.frame.size.width)/2;
    player1Button.frame = rect;
    [player1Button setTitle:NSLocalizedString(@"white",nil) forState:UIControlStateNormal];
    rect = player2Button.frame;
    rect.origin.y = board.frame.size.height + 2;
    //    rect.origin.x = (board.frame.size.width - submitButton.frame.size.width)/2;
    player2Button.frame = rect;
    [player2Button setTitle:NSLocalizedString(@"black",nil) forState:UIControlStateNormal];
    rect = dPenteChoiceLabel.frame;
    rect.origin.y = (player1Button.frame.origin.y +3);
    dPenteChoiceLabel.frame = rect;

    playerStats = [[WKWebView alloc] initWithFrame:CGRectMake(2, submitButton.frame.origin.y + 3, self.view.bounds.size.width - 4,  submitButton.frame.origin.y - 3)];
    [playerStats setNavigationDelegate:self];
    [playerStats setAlpha:0.90];
    [playerStats setBackgroundColor:[UIColor colorWithRed:0.98f green:0.98f blue:0.98f alpha:0.95]];
    playerStats.clipsToBounds = YES;
    playerStats.layer.cornerRadius = 1.0f;
    playerStats.layer.borderWidth = 1.0f;
    playerStats.layer.borderColor = [[UIColor grayColor] CGColor];
    //    receivedMessageView.contentInset = UIEdgeInsetsMake(7.0,7.0,0,0.0);
    [playerStats setUserInteractionEnabled:YES];
    [playerStats.scrollView setScrollEnabled:NO];
    //    playerStats.contentInset = UIEdgeInsetsMake(-5.0,0.0,0,0.0);
    [self.view addSubview: playerStats];

    [submitButton setEnabled:NO];
    [submitButton setTitle:NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
    [submitButton setAlpha:0.5];
    [board setAbstractBoard: abstractBoard];
    [zoomedBoard setAbstractBoard: abstractBoard];
    


}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!showedAd) {
        [zoomedBoard setHidden:YES];
        [zoomedStone setHidden:YES];
        [stone setHidden:YES];
        finalMove = -1;
        connect6Move1 = -1;
        connect6Move2 = -1;
        dPenteMove1 = -1;
        dPenteMove2 = -1;
        dPenteMove3 = -1;
        dPenteMove4 = -1;
//        dPenteChoice = NO;
//        dPenteOpening = NO;
        poofed = NO;
        [whiteStoneCaptures setStoneColor:WHITE];
        [blackStoneCaptures setStoneColor:BLACK];
        [horizontalLine setHidden:YES];
        [verticalLine setHidden:YES];
        captures = [[NSMutableArray alloc] init];
        replyMessage = @"";
    } else {
        showedAd = NO;
    }
    
    UIBarButtonItem *negativeSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    negativeSpacer.width = -16.0;// it was -6 in iOS 6
    UIBarButtonItem *positiveSpacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    positiveSpacer.width = 16.0;// it was -6 in iOS 6
    UIBarButtonItem *messsageBarButton = self.navigationItem.rightBarButtonItem;
    if (isGoGame) {
        UIBarButtonItem *goItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"database"] style:UIBarButtonItemStylePlain target:self action:@selector(showScore)];
        UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"cancel.png"] style:UIBarButtonItemStylePlain target:self action:@selector(cancelResignHide)];
        [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects: messsageBarButton, negativeSpacer, goItem, negativeSpacer, cancelItem, positiveSpacer, nil] animated:YES];
    } else {
        [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects: messsageBarButton, negativeSpacer, [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"cancel.png"] style:UIBarButtonItemStylePlain target:self action:@selector(cancelResignHide)], positiveSpacer, nil] animated:YES];
    }
    dPenteChoiceLabel.text = NSLocalizedString(@"Play as",nil);

    CGFloat bottomOffset = 0;
    
    if([[UIDevice currentDevice]userInterfaceIdiom]==UIUserInterfaceIdiomPhone) {
        if ((int)[[UIScreen mainScreen] nativeBounds].size.height == 2436) {
            bottomOffset = 34;
        }
    }
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat newOriginY = screenHeight - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height;
    if (showAds) {
        playerStats.frame = CGRectMake(2, submitButton.frame.origin.y + 3 + submitButton.frame.size.height, self.view.bounds.size.width - 4,  newOriginY - submitButton.frame.origin.y - GAD_SIZE_320x50.height -5 -  submitButton.frame.size.height - bottomOffset);
    } else {
        playerStats.frame = CGRectMake(2, submitButton.frame.origin.y +  3 + submitButton.frame.size.height, self.view.bounds.size.width - 4, newOriginY - submitButton.frame.origin.y - 5 -  submitButton.frame.size.height - bottomOffset);
    }
    if (showAds) {
//        NSLog(@"showAds");
        CGPoint origin = CGPointMake(0.0, self.view.frame.size.height - self.navigationController.navigationBar.frame.size.height - kGADAdSizeBanner.size.height - bottomOffset);
        bannerView = [[GADBannerView alloc] initWithAdSize:kGADAdSizeSmartBannerPortrait origin:origin];
        bannerView.rootViewController = self;
        [bannerView setDelegate: self];
        newOriginY = screenHeight - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height - bannerView.frame.size.height - bottomOffset;
        CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
        bannerView.frame = newBannerViewFrame;
        bannerView.adUnitID = @"ca-app-pub-3326997956703582/5064095440";
//        bannerView.adUnitID = @"ca-app-pub-3326997956703582/8641559446";
//        bannerView.adUnitID = @"ca-app-pub-3940256099942544/2934735716";
        GADRequest *request = [GADRequest request];
        PentePlayer *player = ((PenteNavigationViewController *)self.navigationController).player;
        if (!player.personalizeAds) {
            GADExtras *extras = [[GADExtras alloc] init];
            extras.additionalParameters = @{@"npa": @"1"};
            [request registerAdNetworkExtras:extras];
        }
        [self.view addSubview:bannerView];
        [bannerView loadRequest:request];

        [self.view bringSubviewToFront:bannerView];
//                NSLog(@"%f", bannerView.frame.origin.y);
//                NSLog(@"%f", playerStats.frame.origin.y + playerStats.frame.size.height);
        //        [self.view addConstraints:@[
        //                                    [NSLayoutConstraint constraintWithItem:bannerView
        //                                                                 attribute:NSLayoutAttributeCenterX
        //                                                                 relatedBy:NSLayoutRelationEqual
        //                                                                    toItem:self.view
        //                                                                 attribute:NSLayoutAttributeCenterX
        //                                                                multiplier:1
        //                                                                  constant:0]
        //                                    ]];
    }
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
//    if (bannerView) {
//        [bannerView loadRequest:[GADRequest request]];
//    }
}

- (void)viewWillDisappear:(BOOL)animated {
//    [bannerView removeFromSuperview];
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    [navController setChallengeCancelled:YES];
    
//    [playerStats setText:@""];
    [super viewWillDisappear:animated];
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
    [self setSubmitButton:nil];
    [self setPlayer2Button:nil];
    [self setPlayer1Button:nil];
    [self setDPenteChoiceLabel:nil];
    [self setWhiteCapturesCountLabel:nil];
    [self setBlackCapturesCountLabel:nil];
    [self setWhiteStoneCaptures:nil];
    [self setBlackStoneCaptures:nil];
    [self setSpinner:nil];
    [self setVerticalLine:nil];
    [self setHorizontalLine:nil];
    [self setMovesList: nil];
    [self setCaptures:nil];
    [self setBoardTapRecognizer:nil];
    [self setReplyMessage:nil];
    [self setReceivedMessage:nil];
    [self setMessageButtonImageView:nil];
    [self setMessageButton:nil];
    [self setReceivedMessages:nil];
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

//-(void)createAdBannerView {
//    bannerView_ = [[GADBannerView alloc] initWithFrame:CGRectMake(0.0,self.view.frame.size.height - GAD_SIZE_320x50.height -44, GAD_SIZE_320x50.width, GAD_SIZE_320x50.height)];
//    bannerView.adUnitID = @"XXXXXXXXXXXX"; 
//}

- (IBAction)dPentePlayer1:(id)sender {
    [player1Button setHidden:YES];
    [player2Button setHidden:YES];
    [dPenteChoiceLabel setHidden:YES];
    [submitButton setAlpha:1];
    [submitButton setHidden:NO];
    [stone setStoneColor: WHITE];
    [stone setNeedsDisplay];
    [zoomedStone setStoneColor: WHITE];
    [zoomedStone setNeedsDisplay];
    activeGame = YES;
}

- (IBAction)dPentePlayer2:(id)sender {
    dPenteChoice = NO;
    finalMove = 0;
    spinner.center = stone.center;
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(submitMoveToServer) toTarget:self withObject:nil];
}

- (IBAction)goForwardOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    if (dPenteChoice || goMarkStones) {
        return;
    }
//    NSLog(@"SwipeRight %i", lastMove);
    if (lastMove < [movesList count]) {
        whiteCaptures = 0;
        blackCaptures = 0;
        ++lastMove;
        if ([[self.game gameType] isEqualToString:@"Connect6"]) {
            ++lastMove;
        }
        [self replayGame:lastMove];
        [board setNeedsDisplay];
        if (!activeGame) {
            [zoomedBoard setAbstractBoard: abstractBoard];
            [zoomedBoard setNeedsDisplay];
        }
    }
}

- (IBAction)goBackOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    if (dPenteChoice || goMarkStones) {
        return;
    }
    [board setBlackTerritory:nil];
    [board setWhiteTerritory:nil];
//    NSLog(@"SwipeLeft %i", lastMove);
    finalMove = -1;
    if (!submitButton.imageView.image && activeGame) {
        [submitButton setEnabled:NO];
        [submitButton setTitle:NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
        [submitButton setAlpha:0.5];
    }
    [stone setHidden:YES];
    if (connect6Move1 != -1) {
        connect6Move1 = -1;
        connect6Move2 = -1;
        [self replayGame:lastMove];
        [board setAbstractBoard: abstractBoard];
        [zoomedBoard setAbstractBoard: abstractBoard];
        [board setNeedsDisplay];
        [zoomedBoard setNeedsDisplay];
    } else if (dPenteOpening) {
        dPenteMove4 = -1;
        if (dPenteMove3 != -1) {
            abstractBoard[dPenteMove3 / 19][dPenteMove3 % 19] = 0;
            [board setAbstractBoard: abstractBoard];
            [zoomedBoard setAbstractBoard: abstractBoard];
            dPenteMove3 = -1;
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
            [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d",nil), coordinateLetters[dPenteMove1 % 19], 19 - (dPenteMove1 / 19), coordinateLetters[dPenteMove2 % 19], 19 - (dPenteMove2 / 19)] forState:UIControlStateDisabled];
        } else if (dPenteMove2 != -1) {
            abstractBoard[dPenteMove2 / 19][dPenteMove2 % 19] = 0;
            [board setAbstractBoard: abstractBoard];
            [zoomedBoard setAbstractBoard: abstractBoard];
            dPenteMove2 = -1;
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
            [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d",nil), coordinateLetters[dPenteMove1 % 19], 19 - (dPenteMove1 / 19)] forState:UIControlStateDisabled];
        } else if (dPenteMove1 != -1) {
            abstractBoard[dPenteMove1 / 19][dPenteMove1 % 19] = 0;
            [board setAbstractBoard: abstractBoard];
            [zoomedBoard setAbstractBoard: abstractBoard];
            dPenteMove1 = -1;
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
        }
    } else if (lastMove > 1) {
        whiteCaptures = 0;
        blackCaptures = 0;
        [stone setHidden:YES];
        --lastMove;
        if ([[self.game gameType] isEqualToString:@"Connect6"]) {
            --lastMove;
        }
        [self replayGame:lastMove];
        [board setNeedsDisplay];
        if (!activeGame) {
            [zoomedBoard setAbstractBoard: abstractBoard];
            [zoomedBoard setNeedsDisplay];
        }
    }
}

- (IBAction)boardTap:(UILongPressGestureRecognizer *)recognizer {
    if (dPenteChoice && [submitButton isHidden]) {
        return;
    }
    if (dPenteOpening) {
        if (dPenteMove1 == -1) {
            [stone setStoneColor: WHITE];
            [zoomedStone setStoneColor: WHITE];
        } else if (dPenteMove2 == -1) {
            [stone setStoneColor: BLACK];
            [zoomedStone setStoneColor: BLACK];
        } else if (dPenteMove3 == -1) {
            [stone setStoneColor: WHITE];
            [zoomedStone setStoneColor: WHITE];
        } else if (dPenteMove4 == -1) {
            [stone setStoneColor: BLACK];
            [zoomedStone setStoneColor: BLACK];
        }
        [stone setNeedsDisplay];
        [zoomedStone setNeedsDisplay];
    } else {
//        NSLog(@"kitty no");
    }
    
    int i, j;
    CGPoint currentPoint = [recognizer locationInView: self.board];
    NSNumber *finaMoveNumber;
    float cellSize = self.board.bounds.size.width / gridSize;
    j = (int) floorf(currentPoint.x/cellSize);
    i = (int) floorf(currentPoint.y/cellSize);
    
    switch ([recognizer state]) {
        case UIGestureRecognizerStateBegan:
            [stone setBounds:CGRectMake(0, 0, 1.2*self.board.bounds.size.width/gridSize,1.2*self.board.bounds.size.width/gridSize)];
            [zoomedStone setBounds:CGRectMake(0, 0, 1.2*1.5*2*self.board.bounds.size.width/gridSize,1.2*1.5*2*self.board.bounds.size.width/gridSize)];
            [stone setNeedsDisplay]; [zoomedStone setNeedsDisplay];
//            NSLog(@"hi start %i %i \n %@", lastMove, [movesList count], movesList);
            if (!goMarkStones &&  lastMove != [movesList count] && activeGame ) {
                whiteCaptures = 0;
                blackCaptures = 0;
                isLastMove = YES;
                lastMove = (int) [movesList count];
                [self replayGame:lastMove];
                [board setNeedsDisplay];
                [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.f]];
            }
            if (!goMarkStones && [captures count] != 0) {
                [self undoCaptures];
                [self updateCaptures];
                [board setNeedsDisplay];
            }
            finalMove = -1;
            [zoomedBoard setHidden: NO];
            [stone setHidden: YES];
            finaMoveNumber = [NSNumber numberWithInt:gridSize*i + j];
            if (activeGame && ((!goMarkStones && ((go && abstractGoBoard[i][j]==0) || (abstractBoard[i][j] == 0))) || (goMarkStones && (abstractBoard[i][j] != 0 || [deadBlackStones containsObject:finaMoveNumber] || [deadWhiteStones containsObject:finaMoveNumber])))) {
                [zoomedStone setHidden: NO];
                [horizontalLine setHidden:NO];
                [verticalLine setHidden:NO];
            }
            break;
        case UIGestureRecognizerStateEnded:
//            NSLog(@"hi ended");
            if ([zoomedBoard isHidden] && activeGame) {
                if (!isGoGame) {
                    [submitButton setEnabled:NO];
                    [submitButton setTitle:NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
                    [submitButton setAlpha:0.5];
                } else {
                    [submitButton setEnabled:YES];
                    [submitButton setTitle:NSLocalizedString(@"PASS",nil) forState:UIControlStateNormal];
                }
                break;
            }
            [zoomedBoard setHidden: YES];
            
            finalMove = gridSize*i + j;
            finaMoveNumber = [NSNumber numberWithInt:finalMove];
            if (goMarkStones && activeGame && (abstractBoard[i][j] != 0 || [deadBlackStones containsObject:finaMoveNumber] || [deadWhiteStones containsObject:finaMoveNumber])) {
                
                [self processDeadStone: finalMove];
                
            } else if (((go && abstractGoBoard[i][j]==0) || (!goMarkStones && abstractBoard[i][j] == 0)) && activeGame) {
                stone.center = CGPointMake(cellSize*j + cellSize/2, cellSize*i + cellSize/2);
                
                if (!([[self.game gameType] isEqualToString:@"Connect6"] && (connect6Move1 == -1)) && !(dPenteOpening && ([[self.game gameType] isEqualToString:@"D-Pente"] || [[self.game gameType] isEqualToString:@"DK-Pente"]) && (dPenteMove3 == -1))) {
                    [submitButton setEnabled:YES];
                    if ([[self.game gameType] isEqualToString:@"Connect6"]) {
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d",nil), coordinateLetters[connect6Move1 % 19], 19 - (connect6Move1 / 19), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateNormal];
                    } else if (([[self.game gameType] isEqualToString:@"D-Pente"] || [[self.game gameType] isEqualToString:@"DK-Pente"]) && dPenteOpening) {
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d-%c%d-%c%d",nil), coordinateLetters[dPenteMove1 % 19], 19 - (dPenteMove1 / 19), coordinateLetters[dPenteMove2 % 19], 19 - (dPenteMove2 / 19), coordinateLetters[dPenteMove3 % 19], 19 - (dPenteMove3 / 19), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateNormal];
                    } else {
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d",nil), coordinateLetters[finalMove % gridSize], gridSize - (finalMove / gridSize)] forState:UIControlStateNormal];
                    }
                    [submitButton setAlpha:1];
                }
                
                [stone setHidden: NO];
                if ([[self.game gameType] isEqualToString:@"Connect6"]) {
                    if (connect6Move1 == -1) {
                        connect6Move1 = finalMove;
                        if ([[self.game myColor] isEqualToString:@"white"]) {
                            abstractBoard[i][j] = 1;
                        } else {
                            abstractBoard[i][j] = 2;
                        }
                    } else {
                        connect6Move2 = finalMove;
                    }
                }
                if (dPenteOpening && ([[self.game gameType] isEqualToString:@"D-Pente"] || [[self.game gameType] isEqualToString:@"DK-Pente"])) {
                    if (dPenteMove1 == -1) {
                        dPenteMove1 = finalMove;
                        abstractBoard[i][j] = 1;
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d",nil), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateDisabled];
                        [submitButton setEnabled:NO];
                        [submitButton setAlpha:0.5];
                    } else if (dPenteMove2 == -1) {
                        dPenteMove2 = finalMove;
                        abstractBoard[i][j] = 2;
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d",nil), coordinateLetters[dPenteMove1 % 19], 19 - (dPenteMove1 / 19), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateDisabled];
                        [submitButton setEnabled:NO];
                        [submitButton setAlpha:0.5];
                    } else if (dPenteMove3 == -1) {
                        dPenteMove3 = finalMove;
                        abstractBoard[i][j] = 1;
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d-%c%d",nil), coordinateLetters[dPenteMove1 % 19], 19 - (dPenteMove1 / 19), coordinateLetters[dPenteMove2 % 19], 19 - (dPenteMove2 / 19),coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateDisabled];
                        [submitButton setEnabled:NO];
                        [submitButton setAlpha:0.5];
                    } else {
                        dPenteMove4 = finalMove;
                        [self detectCaptureOfOpponent:1 atPosition:finalMove];
                    }
                }
                if (isGoGame) {
                    if (finalMove != koMove) {
                        [self addGoMove:finalMove];
                        [self updateCaptures];
                    }
                } else if (!([[self.game gameType] isEqualToString:@"Connect6"] || [[self.game gameType] isEqualToString:@"Gomoku"])) {
                    if ([[self.game gameType] isEqualToString:@"Poof-Pente"] || [[self.game gameType] isEqualToString:@"O-Pente"]) {
                        if ([self detectPoof:(stone.stoneColor == BLACK ? 2 : 1) atPosition: finalMove]) {
                            [stone setHidden:YES];
                        }
                    }
                    if ([[self.game gameType] isEqualToString:@"O-Pente"]) {
                        if ([self detectKeryoPoof:(stone.stoneColor == BLACK ? 2 : 1) atPosition: finalMove]) {
                            [stone setHidden:YES];
                        }
                    }
                    [self detectCaptureOfOpponent:(stone.stoneColor == BLACK ? 1 : 2) atPosition: finalMove];
                    if ([[self.game gameType] isEqualToString:@"Keryo-Pente"] || [[self.game gameType] isEqualToString:@"DK-Pente"] || [[self.game gameType] isEqualToString:@"O-Pente"]) {
                        [self detectKeryoCaptureOfOpponent:(stone.stoneColor == BLACK ? 1 : 2) atPosition: finalMove];
                    }
                    if ([captures count] != 0) {
                        [self updateCaptures];
                        [board setAbstractBoard:abstractBoard];
                    }
                }
            } else if (!goMarkStones && activeGame) {
                finalMove = -1;
                if (!isGoGame) {
                    [submitButton setEnabled:NO];
                    [submitButton setTitle:NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
                    [submitButton setAlpha:0.5];
                } else {
                    [submitButton setTitle:NSLocalizedString(@"PASS",nil) forState:UIControlStateNormal];
                    finalMove = gridSize*gridSize;
                    [self copyGoBoardBack];
                }
            }
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
            break;
        default: break;
    }
    if ((currentPoint.x < 0) || (currentPoint.x > self.board.bounds.size.width) || (currentPoint.y < 0) || (currentPoint.y > self.board.bounds.size.height)) {
// out of board bounds
        [zoomedBoard setHidden: YES];
        [zoomedStone setHidden:YES];
        [horizontalLine setHidden:YES];
        [verticalLine setHidden:YES];
        finalMove = -1;
        finaMoveNumber = nil;
    } else {
        if ([zoomedBoard isHidden] && ([recognizer state] != UIGestureRecognizerStateEnded) && ((go && abstractGoBoard[i][j] == 0) || (!goMarkStones && abstractBoard[i][j] == 0) || (goMarkStones && (abstractBoard[i][j] != 0 || [deadBlackStones containsObject:finaMoveNumber] || [deadWhiteStones containsObject:finaMoveNumber])))) {
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
        float cellSize = self.zoomedBoard.bounds.size.width / gridSize;
        if ((fabs(zoomedStone.center.x - 2*currentPoint.x) >= cellSize/2) || (fabs(zoomedStone.center.y - 2*currentPoint.y) >= cellSize/2)) {
            
            zoomedStone.center = CGPointMake(cellSize*j + cellSize/2, cellSize*i + cellSize/2);
            verticalLine.center = CGPointMake(cellSize*j + cellSize/2, zoomedBoard.bounds.size.width/2);
            horizontalLine.center = CGPointMake(zoomedBoard.bounds.size.height/2, cellSize*i + cellSize/2);
            if (goMarkStones) {
                finaMoveNumber = [NSNumber numberWithInt:gridSize*i + j];
            }
            if (activeGame && ((!goMarkStones && ((go && abstractGoBoard[i][j] == 0) || (abstractBoard[i][j] == 0))) || (goMarkStones && (abstractBoard[i][j] != 0 || [deadBlackStones containsObject:finaMoveNumber] || [deadWhiteStones containsObject:finaMoveNumber])))) {
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





-(void) undoCaptures {
    int myColor = ([[self.game myColor] isEqualToString:@"white"]) ? 1 : 2;
    BOOL poof = NO, done = NO;
    struct Capture capture;
    if ([captures count] > 0) {
        for (id capturee in captures) {
            [capturee getValue:&capture];
            int i = capture.position / 19, j = capture.position % 19, color = capture.color;
            poof = poof || (color == myColor);
            if (poof && !done) {
                abstractBoard[i][j] = 0;
                done = YES;
            } else {
                abstractBoard[i][j] = color;
            }
            if (color == 1) {
                --whiteCaptures;
            } else {
                --blackCaptures;
            }
            
        }
//        if (poof) {
//            if (myColor == 1) {
//                --whiteCaptures;
//            } else {
//                --blackCaptures;
//            }
//        }
        [captures removeAllObjects];
        [board setAbstractBoard:abstractBoard];
        [board setNeedsDisplay];
    }
}

- (IBAction)submitMove:(id)sender {
    spinner.center = stone.center;
    [spinner setColor:[[self.game myColor] isEqualToString:@"white"] ? [UIColor blackColor]:[UIColor whiteColor]];
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(submitMoveToServer) toTarget:self withObject:nil];
}


-(NSString*) getDeadStonesString {
    NSMutableString *str = [[NSMutableString alloc] initWithString:[NSString stringWithFormat:@"%d",gridSize*gridSize]];
    for (NSNumber *move in deadBlackStones) {
        [str insertString:[NSString stringWithFormat:@"%i,", move.intValue] atIndex:0];
    }
    for (NSNumber *move in deadWhiteStones) {
        [str insertString:[NSString stringWithFormat:@"%i,", move.intValue] atIndex:0];
    }
    return str;
}

-(void) submitMoveToServer {
//    NSLog(@"kitty %d", finalMove);

    NSString *moveString;
    if ([[self.game gameType] isEqualToString:@"Connect6"] && (connect6Move1 != -1) && (connect6Move2 != -1)) {
        moveString = [NSString stringWithFormat:@"%i,%i", connect6Move1, connect6Move2];
    } else if (([[self.game gameType] isEqualToString:@"D-Pente"] || [[self.game gameType] isEqualToString:@"DK-Pente"]) && (dPenteMove1 != -1) && (dPenteMove2 != -1) && (dPenteMove3 != -1) && (dPenteMove4 != -1) && dPenteOpening) {
        moveString = [NSString stringWithFormat:@"%i,%i,%i,%i,", dPenteMove1, dPenteMove2, dPenteMove3, dPenteMove4];
    } else if (([[self.game gameType] isEqualToString:@"D-Pente"] || [[self.game gameType] isEqualToString:@"DK-Pente"]) && (finalMove != -1) && dPenteChoice) {
        moveString = [NSString stringWithFormat:@"1,%i", finalMove];
    } else if (finalMove != -1) {
        moveString = [NSString stringWithFormat:@"%i", finalMove];
    }
    
    if (isGoGame) {
        if (goMarkStones) {
            moveString = [self getDeadStonesString];
        } else {
            if (finalMove == -1) {
                moveString = [NSString stringWithFormat:@"%d", (gridSize*gridSize)];
            }
        }
    }

    //    NSLog(@"kitty %@", moveString);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url;
    NSURLResponse *response;
    NSError *error;
    NSData *responseData;
    //    NSLog(@"kittyLog %@", replyMessage);
    if ([replyMessage isEqualToString:@""]) {
        url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/game?command=move%@&mobile=&gid=%@&moves=%@&message=",hideString,[self.game gameID],moveString];
        if (development) {
            url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/tb/game?command=move%@&mobile=&gid=%@&moves=%@&message=",hideString,[self.game gameID],moveString];
        }
    } else {
        url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/game?command=move%@&mobile=&gid=%@&moves=%@&message=%@",hideString,[self.game gameID],moveString,[self URLEncodedString_ch:replyMessage]];
        if (development) {
            url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/tb/game?command=move%@&mobile=&gid=%@&moves=%@&message=%@",hideString,[self.game gameID],moveString,[self URLEncodedString_ch:replyMessage]];
        }
    }
    //    NSLog(@"kitty %@", url);
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    
//    [request setHTTPShouldUsePipelining: YES];
    
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

    [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        //        [alert show];
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
        return;
    }

    [self performSelectorOnMainThread:@selector(cleanUp) withObject:nil waitUntilDone:NO];
}


-(void) cleanUp {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"notBack2Dash"]) {
        finalMove = -1;
        activeGame = NO;
        [submitButton setEnabled:NO];
        [submitButton setTitle:NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
        [submitButton setAlpha:0.5];
        [zoomedStone setHidden:YES];
        [stone setHidden:YES];
        [self replayGame];
        return;
    }
    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
    [navControllor setDidMove: YES];
    [navControllor setActiveGameToRemove: [self.game gameID]];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void) updateCaptures {
    [whiteCapturesCountLabel setText:[NSString stringWithFormat:@"x %i",whiteCaptures]];
    [whiteCapturesCountLabel sizeToFit];
    [whiteCapturesCountLabel setNeedsDisplay];
    [blackCapturesCountLabel setText:[NSString stringWithFormat:@"x %i",blackCaptures]];
    [blackCapturesCountLabel sizeToFit];
    [blackCapturesCountLabel setNeedsDisplay];
}







-(void) replayGame {
    gridSize = 19;
    isGoGame = NO;
    [board setLastConnect6Move: -1];
    [zoomedBoard setLastConnect6Move: -1];
    whiteCaptures = 0;
    blackCaptures = 0;
    if ((!receivedMessageView) || (!replyMessageView)) {
        receivedMessageView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 44)];
        replyMessageView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 44)];
    }
    
    BOOL iAmP1 = NO;

    [self setReplyMessage:@""];
    [self setReceivedMessage:nil];
    messagesHistory = [[NSMutableDictionary alloc] init];
    isLastMove = YES;


    
    //    NSString *tmpStr = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tbpgn.jsp?g=%@",[self.game gameID]];
//    NSString *tmpStr = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/game?gid=%@&command=load",[self.game gameID]];
    NSString *tmpStr = [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobile/game.jsp?gid=%@",[self.game gameID]];
    if (development) {
        tmpStr = [NSString stringWithFormat:@"https://development.pente.org/gameServer/mobile/game.jsp?gid=%@",[self.game gameID]];
    }
//    tmpStr = [NSString stringWithFormat:@"https://development.pente.org/gameServer/mobile/game.jsp?gid=%@",[self.game gameID]];
    NSURL *url = [NSURL URLWithString: tmpStr];
    NSError *error;
    NSString *htmlString = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        //        [alert show];
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
        return;
    }

//    NSLog(@"kitty %@", htmlString);
//    NSLog(@"kitty %@", url);
    
    canHide = [htmlString containsString:@"can_hide=yes"];
    canUnHide = [htmlString containsString:@"can_unhide=yes"];
    
    NSArray *splitDash = [htmlString componentsSeparatedByString:@"\n"];
    NSString *dashLine;
//    NSArray *splitLine;
    NSMutableArray *messages, *atMoves;
    BOOL cancelRequest = NO, undoRequest = NO;
    
    int dashIDX = 0;
    NSString *myUsername = [[[NSUserDefaults standardUserDefaults] objectForKey:@"username"] lowercaseString], *p1Name, *p2Name;
//    myUsername = @"thomrr25"
    if (development) {
//        myUsername = @"iostest";
    }
    NSString *currentPlayer = @"";
    while (dashIDX < [splitDash count]) {
        dashLine = [splitDash objectAtIndex:dashIDX];
        @try {
            if ([dashLine hasPrefix:@"current_player="]) {
                currentPlayer = [[dashLine stringByReplacingOccurrencesOfString:@"current_player=" withString:@""] lowercaseString];
            } else if ([dashLine hasPrefix:@"sid="]) {
                [self.game setSetID:[dashLine substringFromIndex:4]];
            } else if ([dashLine containsString:@"undo=requested"]) {
                undoRequest = YES;
            } else if ([dashLine hasPrefix:@"gameName="]) {
                [self.game setGameType:[dashLine substringFromIndex:9]];
                isGoGame = ([self.game.gameType hasPrefix:@"Go"] && ![self.game.gameType hasPrefix:@"Gomoku"]) || ([self.game.gameType hasPrefix:@"Speed Go"] && ![self.game.gameType hasPrefix:@"Speed Gomoku"]);
            } else if ([dashLine hasPrefix:@"moves="]) {
//                NSLog(dashLine);
                if (dashLine.length > 6) {
                    movesList  = [NSMutableArray arrayWithArray:[[dashLine substringFromIndex:6] componentsSeparatedByString:@","]];
                } else {
                    movesList = [[NSMutableArray alloc] init];
                }
                lastMove = (int) [movesList count];
            } else if ([dashLine hasPrefix:@"messages="]) {
                messages = [NSMutableArray arrayWithArray:[[dashLine substringFromIndex:9] componentsSeparatedByString:@","]];
            } else if ([dashLine hasPrefix:@"private="]) {
                [self.game setPrivateGame:[dashLine substringFromIndex:8]];
            } else if ([dashLine hasPrefix:@"rated="]) {
                [self.game setRatedNot:[dashLine substringFromIndex:6]];
            } else if ([dashLine hasPrefix:@"cancel="]) {
                NSArray *playerRating = [NSArray arrayWithArray:[[dashLine substringFromIndex:7] componentsSeparatedByString:@","]];
                if (![[playerRating objectAtIndex:0] isEqualToString:myUsername]) {
                    cancelRequest = YES;
                    if ([[playerRating objectAtIndex:1] isEqualToString:@""]) {
                        cancelMsg = @"";
                    } else {
                        cancelMsg = [NSString stringWithFormat:@"/n and writes: %@",[playerRating objectAtIndex:1]];
                    }
                }
            } else if ([dashLine hasPrefix:@"player1="]) {
                NSArray *playerRating = [NSArray arrayWithArray:[[dashLine substringFromIndex:8] componentsSeparatedByString:@","]];
                p1Name = [playerRating objectAtIndex:0];
                if (![p1Name isEqualToString:myUsername]) {
                    iAmP1 = NO;
                    [self.game setOpponentName: [playerRating objectAtIndex:0]];
                    [self.game setOpponentRating: [playerRating objectAtIndex:1]];
                } else {
                    if (isGoGame) {
                        [self.game setMyColor:@"black"];
                    } else {
                        [self.game setMyColor:@"white"];
                    }
                }
            } else if ([dashLine hasPrefix:@"player2="]) {
                NSArray *playerRating = [NSArray arrayWithArray:[[dashLine substringFromIndex:8] componentsSeparatedByString:@","]];
                p2Name = [playerRating objectAtIndex:0];
                if (![p2Name isEqualToString:myUsername]) {
                    iAmP1 = YES;
                    [self.game setOpponentName: [playerRating objectAtIndex:0]];
                    [self.game setOpponentRating: [playerRating objectAtIndex:1]];
                } else {
                    if (!isGoGame) {
                        [self.game setMyColor:@"black"];
                    } else {
                        [self.game setMyColor:@"white"];
                    }
                }
            } else if ([dashLine hasPrefix:@"messageNums="]) {
                atMoves = [NSMutableArray arrayWithArray:[[dashLine substringFromIndex:12] componentsSeparatedByString:@","]];
            }
        } @catch (NSException *exception) {
            
        } @finally {
            dashIDX++;
        }
    }
    [self setTitle:[self.game gameType]];


    for (int i = 0; i < [messages count]; ++i) {
        NSString *tmpStrComma = [[messages objectAtIndex:i] stringByReplacingOccurrencesOfString:@"\\1" withString: @","];
        NSString *tmpStrQuote = [tmpStrComma stringByReplacingOccurrencesOfString:@"\\2" withString: @"\""];
        NSString *tmpStrAmp = [tmpStrQuote stringByReplacingOccurrencesOfString:@"&amp;#38;" withString: @"&"];
        NSString *tmpStrSmiley = [tmpStrAmp stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/happy.gif' alt=''>" withString: @":)"];
        NSString *tmpStrWink = [tmpStrSmiley stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/wink.gif' alt=''>" withString: @";)"];
        NSString *tmpStrTongue = [tmpStrWink stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/silly.gif' alt=''>" withString: @":p"];
        NSString *tmpStrGrin = [tmpStrTongue stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/grin.gif' alt=''>" withString: @":D"];
        NSString *tmpStrSad = [tmpStrGrin stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/sad.gif' alt=''>" withString: @":("];
        NSString *tmpStrLove = [tmpStrSad stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/love.gif' alt=''>" withString: @"<3"];
        NSString *tmpStrMischief = [tmpStrLove stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/mischief.gif' alt=''>" withString: @";\\"];
        NSString *tmpStrCool = [tmpStrMischief stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/cool.gif' alt=''>" withString: @"B)"];
        NSString *tmpStrDevil = [tmpStrCool stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/devil.gif' alt=''>" withString: @">:)"];
        NSString *tmpStrAngry = [tmpStrDevil stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/angry.gif' alt=''>" withString: @"X("];
        NSString *tmpStrLaugh = [tmpStrAngry stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/laugh.gif' alt=''>" withString: @":^O"];
        NSString *tmpStrBlush = [tmpStrLaugh stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/blush.gif' alt=''>" withString: @":8)"];
        NSString *tmpStrCry = [tmpStrBlush stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/cry.gif' alt=''>" withString: @":'("];
        NSString *tmpStrConfused = [tmpStrCry stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/confused.gif' alt=''>" withString: @"?:|"];
        NSString *tmpStrShocked = [tmpStrConfused stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/shocked.gif' alt=''>" withString: @":O"];
        NSString *tmpStrPlain = [tmpStrShocked stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/plain.gif' alt=''>" withString: @":|"];
        [messagesHistory setObject:[tmpStrPlain stringByReplacingOccurrencesOfString:@"\\1" withString: @","] forKey: [atMoves objectAtIndex:i]];
    }
    
    
    [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
    if ([messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]) {
        if (([[self.game myColor] isEqualToString:@"white"] && (([movesList count] % 2) == 1)) || ([[self.game myColor] isEqualToString:@"black"] && (([movesList count] % 2) == 0))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
        } else {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" %@: %@",[self.game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
        }
        if (([[self.game gameType] isEqualToString:@"Connect6"] && [[self.game myColor] isEqualToString:@"white"] && (([movesList count] % 4) == 1)) || ([[self.game gameType] isEqualToString:@"Connect6"] && [[self.game myColor] isEqualToString:@"black"] && (([movesList count] % 4) == 3))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
        } else if ([[self.game gameType] isEqualToString:@"Connect6"]) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" %@: %@",[self.game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
        }
        if (isGoGame) {
            if (([[self.game myColor] isEqualToString:@"black"] && (([movesList count] % 2) == 1)) || ([[self.game myColor] isEqualToString:@"white"] && (([movesList count] % 2) == 0))) {
                [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
                receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
            } else {
                [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
                receivedMessage = [NSString stringWithFormat:@" %@: %@",[self.game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
            }
        }
    } else {
        receivedMessage = @"";
        [replyMessageView setFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 88)];
    }
    
    [receivedMessageView setEditable:NO];
    [receivedMessageView setAlpha:0.90];
//    [receivedMessageView setBackgroundColor:[UIColor colorWithRed:0.98f green:0.98f blue:0.98f alpha:0.95]];
    receivedMessageView.clipsToBounds = YES;
    receivedMessageView.layer.cornerRadius = 5.0f;
    receivedMessageView.contentInset = UIEdgeInsetsMake(-10.0,0.0,0,0.0);
    [receivedMessageView setText:receivedMessage];
    CGRect frame = receivedMessageView.frame;
    frame.origin.y = 568;

    NSDictionary *fontAttributes = [NSDictionary dictionaryWithObject:[receivedMessageView font] forKey:NSFontAttributeName];
    [self.view addSubview:receivedMessageView];
    CGRect textFrame = [receivedMessage boundingRectWithSize:CGSizeMake(receivedMessageView.contentSize.width + receivedMessageView.contentOffset.x - receivedMessageView.contentInset.left - receivedMessageView.contentInset.right, receivedMessageView.font.lineHeight*5) options:(NSStringDrawingUsesLineFragmentOrigin|NSLineBreakByWordWrapping) attributes:fontAttributes context:nil];
    [receivedMessageView setText: receivedMessage];
//    CGFloat fontLineHeight = [[receivedMessageView font] lineHeight];
    [receivedMessageView setFrame:frame];
//    [self.view addSubview: receivedMessageView];

    
//    if (receivedMessageView.contentSize.height < (3*receivedMessageView.font.lineHeight)) {
    if (textFrame.size.height < (3*receivedMessageView.font.lineHeight)) {
        //        frame.size.height = receivedMessageView.contentSize.height;
        frame.size.height = textFrame.size.height;
    } else {
        frame.size.height = MIN((receivedMessageView.font.lineHeight * 5),textFrame.size.height - receivedMessageView.contentInset.top);
    }
    [receivedMessageView removeFromSuperview];
    [receivedMessageView setFrame:frame];

    [replyMessageView setFont:[UIFont systemFontOfSize:15]];
    frame = replyMessageView.frame;
    frame.size.height = replyMessageView.font.lineHeight*3;
    [replyMessageView setAlpha:0.90];
    [replyMessageView setEditable:YES];
    replyMessageView.clipsToBounds = YES;
    replyMessageView.layer.cornerRadius = 5.0f;
    replyMessageView.contentInset = UIEdgeInsetsMake(-7.0,0.0,0,0.0);
    [replyMessageView setFrame:frame];
//    [replyMessageView setAutocapitalizationType:UITextAutocapitalizationTypeNone];
//    [replyMessageView setAutocorrectionType:UITextAutocorrectionTypeNo];
    [replyMessageView setReturnKeyType:UIReturnKeyDone];
    [replyMessageView setDelegate:self];
    replyMessageView.layer.borderWidth = 2.0f;
    replyMessageView.layer.borderColor = [[UIColor grayColor] CGColor];

    NSString *locRating = NSLocalizedString(@"rating:",nil);
    NSString *remTime = NSLocalizedString(@"Remaining time:",nil);
    NSString *ratedPrivate = [NSString stringWithFormat:NSLocalizedString(@"This game is %@ and %@", nil), [self.game localizedRatedNot], [self.game privateGame]];
    
    if (![myUsername isEqualToString:p1Name] && ![myUsername isEqualToString:p2Name]) {
        playerStatsBaseString = [NSString stringWithFormat:@"<font size=\"3.5\"><a href=\"https://www.pente.org/gameServer/profile?viewName=%@\">%@</a> vs <a href=\"https://www.pente.org/gameServer/profile?viewName=%@\">%@</a>, %@ %@ <br> %@ %@ <br> %@ </font><hr>",p1Name, p1Name, p2Name, p2Name, locRating, [self.game opponentRating], remTime,[self.game localizedTimeString], ratedPrivate];
    } else {
        playerStatsBaseString = [NSString stringWithFormat:@"<font size=\"3.5\">Opponent: <a href=\"https://www.pente.org/gameServer/profile?viewName=%@\">%@</a>, %@ %@ <br> %@ %@ <br> %@</font><hr>",[self.game opponentName],[self.game opponentName],locRating,[self.game opponentRating],remTime,[self.game remainingTime],ratedPrivate];
    }

    
//    NSLog(@"kitty message %@", message);
    dPenteOpening = NO;
    whiteCaptures = 0;
    blackCaptures = 0;
    [self resetBoard];

    if ([[self.game gameType] isEqualToString:@"Pente"] || [[self.game gameType] isEqualToString:@"Boat-Pente"] || [[self.game gameType] isEqualToString:@"Speed Pente"] || [[self.game gameType] isEqualToString:@"Speed Boat-Pente"]) {
        [self replayPenteGame: (int) [movesList count]];
    }
    if ([[self.game gameType] isEqualToString:@"Keryo-Pente"] || [[self.game gameType] isEqualToString:@"Speed Keryo-Pente"]) {
        [self replayKeryoPenteGame: (int) [movesList count]];
    }
    if ([[self.game gameType] isEqualToString:@"O-Pente"] || [[self.game gameType] isEqualToString:@"Speed O-Pente"]) {
        [self replayOPenteGame: (int) [movesList count]];
    }
    if ([[self.game gameType] isEqualToString:@"G-Pente"] || [[self.game gameType] isEqualToString:@"Speed G-Pente"]) {
        [self replayGPenteGame: (int) [movesList count]];
    }
    if ([[self.game gameType] isEqualToString:@"D-Pente"] || [[self.game gameType] isEqualToString:@"Speed D-Pente"] || [[self.game gameType] isEqualToString:@"DK-Pente"] || [[self.game gameType] isEqualToString:@"Speed DK-Pente"]) {
        if ([[self.game gameType] isEqualToString:@"DK-Pente"] || [[self.game gameType] isEqualToString:@"Speed DK-Pente"]) {
            [self replayDKPenteGame: (int) [movesList count]];
        } else {
            [self replayDPenteGame: (int) [movesList count]];
        }

        dPenteChoice = NO;
        if ([movesList count] == 4) {
//            NSLog(@"kitty %@", htmlString);
            if ([htmlString rangeOfString:@"dPenteState=2"].location != NSNotFound && activeGame) {
//                            NSLog(@"kitty what");
                dPenteChoice = YES;
                [submitButton setHidden:YES];
                [player2Button setHidden:NO];
                [player1Button setHidden:NO];
                [self.view bringSubviewToFront:player1Button];
                [dPenteChoiceLabel setHidden:NO];
                [whiteStoneCaptures setHidden:YES];
                [whiteCapturesCountLabel setHidden:YES];
                [blackStoneCaptures setHidden:YES];
                [blackCapturesCountLabel setHidden:YES];
                [lockButton setHidden: YES];
            } else {
                [player1Button setHidden:YES];
                [player2Button setHidden:YES];
                [dPenteChoiceLabel setHidden:YES];
            }
        }
        
    }
    if ([[self.game gameType] isEqualToString:@"Poof-Pente"] || [[self.game gameType] isEqualToString:@"Speed Poof-Pente"]) {
        [self replayPoofPenteGame: (int) [movesList count]];
    }
    go = NO; goMarkStones = NO; goEvaluateDeadStones = NO;
    if (isGoGame) {
        if ([self.game.gameType containsString:@"(9x9)"]) {
            gridSize = 9;
        } else if ([self.game.gameType containsString:@"(13x13)"]) {
            gridSize = 13;
        }
        goMarkStones = [htmlString containsString:@"Go=MARK_DEAD_STONES"];
        goEvaluateDeadStones = [htmlString containsString:@"Go=EVALUATE_DEAD_STONES"];
        [self replayGoGame: (int) [movesList count]];
        [board setGo:YES];
        [zoomedBoard setGo:YES];
        if (!goMarkStones && !goEvaluateDeadStones) {
            [self copyGoBoard];
            [zoomedBoard setAbstractBoard:abstractGoBoard];
            go = YES;
        } else if (goMarkStones) {
            [self showTerritory:nil];
        } else if (goEvaluateDeadStones && activeGame) {
            [self evaluateDeadStones];
        }
    }
    if ([[self.game gameType] isEqualToString:@"Connect6"] || [[self.game gameType] isEqualToString:@"Speed Connect6"]) {
        [self replayConnect6Game: (int) [movesList count]];
    }
    [self updateCaptures];
    
    if ([[self.game gameType] isEqualToString:@"Gomoku"] || [[self.game gameType] isEqualToString:@"Speed Gomoku"]) {
        [self replayGomokuGame: (int) [movesList count]];
    }

    // Find out your color
    if ([[self.game myColor] isEqualToString:@"white"]) {
        [stone setStoneColor:WHITE];
    } else {
        [stone setStoneColor:BLACK];
    }
    [zoomedStone setStoneColor:[stone stoneColor]];
    if (goMarkStones) {
        [zoomedStone setStoneColor:RED];
        [zoomedStone setAlpha:0.7];
    }

    moveStatsString = [[NSMutableString alloc] init];
    for (int i = 0; i < lastMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        if (i == 0) {
            [moveStatsString appendString: @"<b>1.</b> "];
        } else if ([[self.game gameType] isEqualToString:@"Connect6"] || [[self.game gameType] isEqualToString:@"Speed Connect6"]) {
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
        if (rowCol < gridSize*gridSize) {
            [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % gridSize], gridSize - (rowCol / gridSize)]];
        } else {
            [moveStatsString appendString:@"PASS"];
        }
    }
    [playerStats loadHTMLString: [HEADERSTRING stringByAppendingString:[playerStatsBaseString stringByAppendingString:moveStatsString]] baseURL:nil];

    [board setGridSize:gridSize]; [zoomedBoard setGridSize:gridSize];
    [board setNeedsDisplay]; [zoomedBoard setNeedsDisplay];

    if (cancelRequest) {
        [self presentCancelReply];
    }

    if (![receivedMessage isEqualToString:@""]) {
        [self notifyNewMessage];
    }
    
    activeGame = [currentPlayer isEqualToString:myUsername];

    if ([[self.game opponentName] isEqualToString:@"computer"]) {
        NSString *message = nil;
        BOOL iWin = YES;
        if ([self detectPenteOf: 2-([movesList count]%2) atPosition: [[movesList lastObject] intValue]]) {
            if (2-([movesList count]%2) == 1) {
                message = NSLocalizedString(@"White wins",nil);
            } else {
                message = NSLocalizedString(@"Black wins",nil);
            }
        } else if (whiteCaptures == 10) {
            message = NSLocalizedString(@"Black wins",nil);
        } else if (blackCaptures == 10) {
            message = NSLocalizedString(@"White wins",nil);
        }
        if (message) {
            activeGame = NO;
            if ([message isEqualToString:@"White wins"]) {
                if ([[self.game myColor] isEqualToString:@"black"]) {
                    iWin = NO;
                }
            } else {
                if ([[self.game myColor] isEqualToString:@"white"]) {
                    iWin = NO;
                }
            }
            [TSMessage showNotificationInViewController:self.navigationController
                                                  title: NSLocalizedString(@"Game Over",nil)
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
    }
    if (![htmlString containsString:@"state=active"]) {
        activeGame = NO;
        PenteNavigationViewController *navC = (PenteNavigationViewController *) self.navigationController;
        if (navC.player.dbAccess) {
            [submitButton setImage:[UIImage imageNamed:@"database.png"] forState:UIControlStateNormal];
            [submitButton removeTarget:self action:@selector(submitMove:) forControlEvents:UIControlEventTouchUpInside];
            [submitButton addTarget:self action:@selector(toDB) forControlEvents:UIControlEventTouchUpInside];
            [submitButton setTitle:NSLocalizedString(@"   search",nil) forState:UIControlStateNormal];
            [submitButton setAlpha:1.0f];
            [submitButton setEnabled:YES];
            [submitButton setNeedsDisplay];
            [lockButton removeFromSuperview];
        }
    }
    if (undoRequest && activeGame) {
        [self presentUndoOptions];
    }
    if (goMarkStones && activeGame && ![[NSUserDefaults standardUserDefaults] boolForKey:@"doublePassInfo"]) {
        [self presentDoublePass];
    }
    if (([myUsername isEqualToString:p1Name] || [myUsername isEqualToString:p2Name]) && !activeGame
        && [htmlString containsString:@"state=active"] && ![htmlString containsString:@"dPenteState=2"] && ([movesList count] > 1 || ([movesList count]>0 && (isGoGame || [[self.game gameType] isEqualToString:@"D-Pente"] || [[self.game gameType] isEqualToString:@"DK-Pente"])))) {
        [submitButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        if (undoRequest) {
            [submitButton setTitle: NSLocalizedString(@"undo requested",nil) forState:UIControlStateDisabled];
            [submitButton setEnabled:NO];
            [submitButton setAlpha:0.85];
        } else {
            [submitButton setTitle: NSLocalizedString(@"request undo",nil) forState:UIControlStateNormal];
            [submitButton setEnabled:YES];
            [submitButton setAlpha:1];
            [submitButton addTarget:self action:@selector(requestUndo:) forControlEvents:UIControlEventTouchUpInside];
        }
    } else if (([myUsername isEqualToString:p1Name] || [myUsername isEqualToString:p2Name]) && activeGame) {
        [submitButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [submitButton addTarget:self action:@selector(submitMove:) forControlEvents:UIControlEventTouchUpInside];
        if (isGoGame) {
            if (goMarkStones) {
                [submitButton setTitle: NSLocalizedString(@"submit",nil) forState:UIControlStateNormal];
                [submitButton setEnabled:YES];
                [submitButton setAlpha:1.0];
            } else {
                [submitButton setTitle: NSLocalizedString(@"PASS",nil) forState:UIControlStateNormal];
                [submitButton setEnabled:YES];
                [submitButton setAlpha:1.0];
            }
        } else {
            [submitButton setTitle: NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
            [submitButton setEnabled:NO];
            [submitButton setAlpha:0.85];
        }
    }
//    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"username"] isEqualToString:@"rainwolf"] && !go) {
//        if ([[[@"samywamy-" stringByAppendingString:[[NSUserDefaults standardUserDefaults] objectForKey:@"password"]] SHA256] isEqualToString:@"1b7017087c9d8ff0d2b3ec1cb930273529d7efb52ce859e2dd1a824194ab7806"]) {
//            [lockButton setImage:[UIImage imageNamed:@"database.png"] forState:UIControlStateNormal];
//            [lockButton removeTarget:self action:@selector(toggleBoardLock:) forControlEvents:UIControlEventTouchUpInside];
//            [lockButton addTarget:self action:@selector(toDB) forControlEvents:UIControlEventTouchUpInside];
//            [lockButton setAlpha:1.0f];
//            [lockButton setEnabled:YES];
//            [lockButton setNeedsDisplay];
//        }
//    }
}

-(void) requestUndo: (UIButton*) sender {
    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
    if ([navControllor.player subscriber]) {
        UIAlertController *confirmController = [UIAlertController
                                                        alertControllerWithTitle:NSLocalizedString(@"Are you sure?", nil)
                                                        message: nil
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        }];
        UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"yes, request undo", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSError *error = nil;
            NSURLResponse *response;
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
            
            NSString *post = [NSString stringWithFormat:@"gid=%@&command=requestUndo&mobile=", [self.game gameID]];
            NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
            NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
            
            NSURL *url = [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/game"];
            if (development) {
                url = [NSURL URLWithString:@"https://development.pente.org/gameServer/tb/game"];
            }
            [request setURL:url];
            [request setHTTPMethod:@"POST"];
            [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
            [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            [request setHTTPBody: postData];
            [request setTimeoutInterval:7.0f];
            
            [request setHTTPShouldUsePipelining: YES];
            
            [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            if (error) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                //        [alert show];
                [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
                return;
            } else {
                [self.navigationController popToRootViewControllerAnimated:YES];
            }
        }];
        [confirmController addAction:cancelAction];
        [confirmController addAction:confirmAction];
        
        if (confirmController.popoverPresentationController != nil) {
            [confirmController.popoverPresentationController setSourceView: submitButton];
            [confirmController.popoverPresentationController setSourceRect: submitButton.bounds];
        }
        
        [self presentViewController:confirmController animated:YES completion:nil];

    } else {
        UIAlertController *subscribersOnlyController = [UIAlertController
                                                        alertControllerWithTitle:NSLocalizedString(@"Action not available", nil)
                                                        message: NSLocalizedString(@"Request undo is a feature available to subscribers only.", nil)
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        }];
        UIAlertAction *subscribeAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"subscription info", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            ((PenteNavigationViewController *) self.navigationController).showSubscribe = YES;
            [self.navigationController popToRootViewControllerAnimated:YES];
        }];
        [subscribersOnlyController addAction:cancelAction];
        [subscribersOnlyController addAction:subscribeAction];
        
        if (subscribersOnlyController.popoverPresentationController != nil) {
            [subscribersOnlyController.popoverPresentationController setSourceView: submitButton];
            [subscribersOnlyController.popoverPresentationController setSourceRect: submitButton.bounds];
        }
        
        [self presentViewController:subscribersOnlyController animated:YES completion:nil];
    }
}

-(void) presentUndoOptions {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Undo requested", nil)
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* acceptAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Accept", nil) style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                             PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                                                             NSError *error = nil;
                                                             NSURLResponse *response;
                                                             NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                                                             
                                                             NSString *post = [NSString stringWithFormat:@"gid=%@&command=acceptUndo&mobile=", [self.game gameID]];
                                                             NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
                                                             NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
                                                             
                                                             NSURL *url = [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/game"];
                                                             if (development) {
                                                                 url = [NSURL URLWithString:@"https://development.pente.org/gameServer/tb/game"];
                                                             }
                                                             [request setURL:url];
                                                             [request setHTTPMethod:@"POST"];
                                                             [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
                                                             [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
                                                             [request setHTTPBody: postData];
                                                             [request setTimeoutInterval:7.0f];
                                                             
                                                             [request setHTTPShouldUsePipelining: YES];
                                                             
                                                             [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                                                             if (error) {
                                                                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                                                 //        [alert show];
                                                                 [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
                                                                 return;
                                                             } else {
                                                                 [navControllor setDidMove: YES];
                                                                 [self.navigationController popToRootViewControllerAnimated:YES];
                                                             }
                                                         }];
    UIAlertAction* declineAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Decline", nil) style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * action) {
//                                                             PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                                                             NSError *error = nil;
                                                             NSURLResponse *response;
                                                             NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                                                             
                                                             NSString *post = [NSString stringWithFormat:@"gid=%@&command=declineUndo&mobile=", [self.game gameID]];
                                                             NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
                                                             NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
                                                             
                                                             NSURL *url = [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/game"];
                                                             if (development) {
                                                                 url = [NSURL URLWithString:@"https://development.pente.org/gameServer/tb/game"];
                                                             }
                                                             [request setURL:url];
                                                             [request setHTTPMethod:@"POST"];
                                                             [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
                                                             [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
                                                             [request setHTTPBody: postData];
                                                             [request setTimeoutInterval:7.0f];
                                                             
                                                             [request setHTTPShouldUsePipelining: YES];
                                                             
                                                             [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                                                             if (error) {
                                                                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                                                 //        [alert show];
                                                                 [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
                                                                 return;
                                                             } else {
                                                                 [self replayGame];
                                                             }
                                                         }];

    [alert addAction:acceptAction];
    [alert addAction:declineAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView: playerStats];
        [alert.popoverPresentationController setSourceRect: playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}
-(void) toDB {
//    NSLog(@"%d",lastMove);
    PenteNavigationViewController *navController = (PenteNavigationViewController*) self.navigationController;
    if (!isGoGame) {
        [[NSUserDefaults standardUserDefaults] setObject:[self.game gameType] forKey:@"DBGame"];
    }
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    DatabaseViewController * vc = (DatabaseViewController *)[sb instantiateViewControllerWithIdentifier:@"databaseViewController"];
    [vc setMovesList: [[movesList subarrayWithRange:NSMakeRange(0, lastMove)] mutableCopy]];
    [vc setGame:[self.game gameType]];
    [vc setShowAds: !navController.player.subscriber];
    [self.navigationController pushViewController:vc animated:YES];
}



-(void) replayGame: (int) untilMove {
    [board setLastConnect6Move:-1];
    [zoomedBoard setLastConnect6Move: -1];
    [board setLastMove: -1];
    [zoomedBoard setLastMove: -1];
    whiteCaptures = 0;
    blackCaptures = 0;
    [self resetBoard];
    if ([[self.game gameType] isEqualToString:@"Pente"] || [[self.game gameType] isEqualToString:@"Boat-Pente"] || [[self.game gameType] isEqualToString:@"Speed Pente"] || [[self.game gameType] isEqualToString:@"Speed Boat-Pente"]) {
        [self replayPenteGame: untilMove];
    }
    if ([[self.game gameType] isEqualToString:@"Keryo-Pente"] || [[self.game gameType] isEqualToString:@"Speed Keryo-Pente"]) {
        [self replayKeryoPenteGame: untilMove];
    }
    if ([[self.game gameType] isEqualToString:@"G-Pente"] || [[self.game gameType] isEqualToString:@"Speed G-Pente"]) {
        [self replayGPenteGame: untilMove];
    }
    if ([[self.game gameType] isEqualToString:@"D-Pente"] || [[self.game gameType] isEqualToString:@"Speed D-Pente"]) {
        [self replayDPenteGame: untilMove];
    }
    if ([[self.game gameType] isEqualToString:@"DK-Pente"] || [[self.game gameType] isEqualToString:@"Speed DK-Pente"]) {
        [self replayDKPenteGame: untilMove];
    }
    if ([[self.game gameType] isEqualToString:@"Poof-Pente"] || [[self.game gameType] isEqualToString:@"Speed Poof-Pente"]) {
        [self replayPoofPenteGame: untilMove];
    }
    if ([[self.game gameType] isEqualToString:@"O-Pente"] || [[self.game gameType] isEqualToString:@"Speed O-Pente"]) {
        [self replayOPenteGame: untilMove];
    }

    if (isGoGame) {
        [self replayGoGame: untilMove];
    }

    
    
    [self updateCaptures];
    
    if ([[self.game gameType] isEqualToString:@"Connect6"] || [[self.game gameType] isEqualToString:@"Speed Connect6"]) {
        [self replayConnect6Game: untilMove];
    }
    if ([[self.game gameType] isEqualToString:@"Gomoku"] || [[self.game gameType] isEqualToString:@"Speed Gomoku"]) {
        [self replayGomokuGame: untilMove];
    }
    
    
    isLastMove = (untilMove == [movesList count]);
    [messageButtonImageView stopAnimating];
    if ([messagesHistory objectForKey:[NSString stringWithFormat:@"%i",untilMove]]) {
        [self notifyNewMessage];
        if (([[self.game myColor] isEqualToString:@"white"] && ((untilMove % 2) == 1)) || ([[self.game myColor] isEqualToString:@"black"] && ((untilMove % 2) == 0))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%i", untilMove]]];
        } else {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" %@: %@",[self.game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%i", untilMove]]];
        }
        if (([[self.game gameType] isEqualToString:@"Connect6"] && [[self.game myColor] isEqualToString:@"white"] && ((untilMove % 4) == 1)) || ([[self.game gameType] isEqualToString:@"Connect6"] && [[self.game myColor] isEqualToString:@"black"] && ((untilMove % 4) == 3))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%i", untilMove]]];
        } else if ([[self.game gameType] isEqualToString:@"Connect6"]) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" %@: %@",[self.game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%i", untilMove]]];
        }
        if (isGoGame) {
                [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            if (([[self.game myColor] isEqualToString:@"black"] && ((untilMove % 2) == 1)) || ([[self.game myColor] isEqualToString:@"white"] && ((untilMove % 2) == 0))) {
                receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)untilMove]]];
            } else {
                [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
                receivedMessage = [NSString stringWithFormat:@" %@: %@",[self.game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)untilMove]]];
            }
        }
        [receivedMessageView setText:receivedMessage];
    } else {
        receivedMessage = @"";
        [receivedMessageView setText:receivedMessage];
    }
    CGRect frame = receivedMessageView.frame;
    frame.origin.y = 568;

    NSDictionary *fontAttributes = [NSDictionary dictionaryWithObject:[receivedMessageView font] forKey:NSFontAttributeName];
    [self.view addSubview:receivedMessageView];
    CGRect textFrame = [receivedMessage boundingRectWithSize:CGSizeMake(receivedMessageView.contentSize.width + receivedMessageView.contentOffset.x - receivedMessageView.contentInset.left - receivedMessageView.contentInset.right, receivedMessageView.font.lineHeight*5) options:(NSStringDrawingUsesLineFragmentOrigin|NSLineBreakByWordWrapping) attributes:fontAttributes context:nil];
    [receivedMessageView setText: receivedMessage];
    [receivedMessageView setFrame:frame];
    
    if (textFrame.size.height < (3*receivedMessageView.font.lineHeight)) {
        frame.size.height = textFrame.size.height;
    } else {
        frame.size.height = MIN((receivedMessageView.font.lineHeight * 5),textFrame.size.height - receivedMessageView.contentInset.top);
    }
    [receivedMessageView removeFromSuperview];
    [receivedMessageView setFrame:frame];
    
    moveStatsString = [[NSMutableString alloc] init];
    for (int i = 0; i < lastMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        if (i == 0) {
            [moveStatsString appendString: @"<b>1.</b> "];
        } else if ([[self.game gameType] isEqualToString:@"Connect6"]) {
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
        if (rowCol < gridSize*gridSize) {
            [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % gridSize], gridSize - (rowCol / gridSize)]];
        } else {
            [moveStatsString appendString:@"PASS"];
        }
    }
    [playerStats loadHTMLString: [HEADERSTRING stringByAppendingString:[playerStatsBaseString stringByAppendingString:moveStatsString]] baseURL:nil];
    
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
}


-(void) replayPenteGame: (int) untilMove {
    //NSLog(@"list %@",movesList);
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
    if ([[self.game ratedNot] rangeOfString:@"Not Rated"].location == NSNotFound && ([movesList count] == 2)) {
        for(int i = 7; i < 12; ++i) {
            for(int j = 7; j < 12; ++j) {
                if (abstractBoard[i][j] == 0) {
                    abstractBoard[i][j] = -1;
                }
            }
        }
    }
    [captures removeAllObjects];
    
    //NSLog(@" kitty moves %i",abstractBoard[0][0]);
    if ([[self.game gameType] isEqualToString:@"Boat-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
    } else {
        [board setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
        [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
    }
    [board setAbstractBoard: abstractBoard];
    [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    }
}


-(void) replayGPenteGame: (int) untilMove {
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
    if ([movesList count] == 2) {
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
    }
    
    [captures removeAllObjects];

    //NSLog(@" kitty moves %i",abstractBoard[0][0]);
    [board setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
    [board setAbstractBoard: abstractBoard];
    [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    }
}


-(void) replayKeryoPenteGame: (int) untilMove {
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
        [self detectKeryoCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
    if ([[self.game ratedNot] rangeOfString:@"Not Rated"].location == NSNotFound && ([movesList count] == 2)) {
        for(int i = 7; i < 12; ++i) {
            for(int j = 7; j < 12; ++j) {
                if (abstractBoard[i][j] == 0) {
                    abstractBoard[i][j] = -1;
                }
            }
        }
    }
    
    [captures removeAllObjects];
    
    //NSLog(@" kitty moves %i",abstractBoard[0][0]);
    [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
    [board setAbstractBoard: abstractBoard];
    [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    }
}
-(void) replayOPenteGame: (int) untilMove {
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectPoof:color atPosition:rowCol];
        [self detectKeryoPoof:color atPosition:rowCol];
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
        [self detectKeryoCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
    if ([[self.game ratedNot] rangeOfString:@"Not Rated"].location == NSNotFound && ([movesList count] == 2)) {
        for(int i = 7; i < 12; ++i) {
            for(int j = 7; j < 12; ++j) {
                if (abstractBoard[i][j] == 0) {
                    abstractBoard[i][j] = -1;
                }
            }
        }
    }
    
    [captures removeAllObjects];
    
    //NSLog(@" kitty moves %i",abstractBoard[0][0]);
    [board setBackgroundColor:[UIColor colorWithRed:0.32 green:0.75 blue:0.50 alpha:1.0]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.32 green:0.75 blue:0.50 alpha:1.0]];
    [board setAbstractBoard: abstractBoard];
    [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    }
}


-(void) replayDKPenteGame: (int) untilMove {
    if ([movesList count] == 0) {
        dPenteOpening = YES;
    } else {
        dPenteOpening = NO;
    }
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
        [self detectKeryoCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
    [captures removeAllObjects];
    
    [board setBackgroundColor:[UIColor colorWithRed:1 green:165.0/255.0 blue:0 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:1 green:165.0/255.0 blue:0 alpha:1]];
    
    if (dPenteOpening) {
        [whiteStoneCaptures setHidden:YES];
        [whiteCapturesCountLabel setHidden:YES];
        [blackStoneCaptures setHidden:YES];
        [blackCapturesCountLabel setHidden:YES];
    }
    [board setAbstractBoard: abstractBoard];
    if ([movesList count] > 0) {
        [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
        if (lastMove == [movesList count]) {
            [zoomedBoard setAbstractBoard: abstractBoard];
            [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
        }
    }
}



-(void) replayGomokuGame: (int) untilMove {
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (i % 2) + 1;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
    }

    [board setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
    [whiteStoneCaptures setHidden:YES];
    [whiteCapturesCountLabel setHidden:YES];
    [blackStoneCaptures setHidden:YES];
    [blackCapturesCountLabel setHidden:YES];
    [board setAbstractBoard: abstractBoard];
    [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    }
}


-(void) replayConnect6Game: (int) untilMove {
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (((i % 4) == 0) || ((i % 4) == 3)) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
    }
    
    [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    [whiteStoneCaptures setHidden:YES];
    [whiteCapturesCountLabel setHidden:YES];
    [blackStoneCaptures setHidden:YES];
    [blackCapturesCountLabel setHidden:YES];
    if (untilMove > 1) {
        [board setLastConnect6Move:[self parseMove:[movesList objectAtIndex:untilMove - 2]]];
    } else {
        [board setLastConnect6Move: -1];
    }
    [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    [board setAbstractBoard: abstractBoard];
    [zoomedBoard setAbstractBoard: abstractBoard];
    [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    if (untilMove > 1) {
        [zoomedBoard setLastConnect6Move:[self parseMove:[movesList objectAtIndex:untilMove - 2]]];
    } else {
        [zoomedBoard setLastConnect6Move: -1];
    }
}


-(void) replayDPenteGame: (int) untilMove {
    if ([movesList count] == 0) {
        dPenteOpening = YES;
    } else {
        dPenteOpening = NO;
    }
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
    [captures removeAllObjects];
    
    [board setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
    
    if (dPenteOpening) {
        [whiteStoneCaptures setHidden:YES];
        [whiteCapturesCountLabel setHidden:YES];
        [blackStoneCaptures setHidden:YES];
        [blackCapturesCountLabel setHidden:YES];
    }
    [board setAbstractBoard: abstractBoard];
    if ([movesList count] > 0) {
        [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
        if (lastMove == [movesList count]) {
            [zoomedBoard setAbstractBoard: abstractBoard];
            [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
        }
    }
}


-(void) replayPoofPenteGame: (int) untilMove {
    for (int i = 0; i < untilMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        [self detectPoof:color atPosition:rowCol];
        [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
    }
    if ([[self.game ratedNot] rangeOfString:@"Not Rated"].location == NSNotFound && ([movesList count] == 2)) {
        for(int i = 7; i < 12; ++i) {
            for(int j = 7; j < 12; ++j) {
                if (abstractBoard[i][j] == 0) {
                    abstractBoard[i][j] = -1;
                }
            }
        }
    }
    [captures removeAllObjects];
    
    [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    [board setAbstractBoard: abstractBoard];
    [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    }
}


-(void) replayGoGame: (int) untilMove {
    [self initGoStructures];
    BOOL hasPass = NO, doublePass = NO;
    int passMove = gridSize*gridSize;
    
    for (int i = 0; i < untilMove; ++i) {
        int currentPlayer = (i % 2) + 1, opponent = 3 - currentPlayer;
        int move = [self parseMove:[movesList objectAtIndex:i]];
        if (doublePass) {
            if (move != passMove) {
                if ([self getBoardValue:move] == 1) {
                    [deadWhiteStones addObject:[NSNumber numberWithInt:move]];
                } else if ([self getBoardValue:move] == 2) {
                    [deadBlackStones addObject:[NSNumber numberWithInt:move]];
                }
                [self setValue:0 forPosition:move];
            }
            continue;
        }
        if (move == passMove) {
            if (hasPass) {
                doublePass = YES;
            } else {
                hasPass = YES;
            }
            continue;
        } else {
            hasPass = NO;
        }
        int color = 3 - currentPlayer;// , opponentColor = 3 - color;
        NSMutableDictionary<NSNumber*,NSMutableArray<NSNumber*>*> *groupsByID = [goStoneGroupsByPlayerAndID objectForKey:[NSNumber numberWithInt: currentPlayer]];
        NSMutableDictionary<NSNumber*,NSNumber*> *stoneGroupIDs = [goStoneGroupIDsByPlayer objectForKey:[NSNumber numberWithInt: currentPlayer]];
        [self setValue:color forPosition:move];
        [self settleGroups:groupsByID andIDs:stoneGroupIDs forMove:move];

        groupsByID = [goStoneGroupsByPlayerAndID objectForKey:[NSNumber numberWithInt: opponent]];
        stoneGroupIDs = [goStoneGroupIDsByPlayer objectForKey:[NSNumber numberWithInt: opponent]];
        [self makeCapturesWithMove:move withGroups:groupsByID andIDs:stoneGroupIDs andAlterGroups:YES];
    }
    [board setBlackDeadStones:deadBlackStones];
    [board setWhiteDeadStones:deadWhiteStones];
    [zoomedBoard setBlackDeadStones:deadBlackStones];
    [zoomedBoard setWhiteDeadStones:deadWhiteStones];
    [board setBackgroundColor:[UIColor colorWithRed:250.0/255 green:200.0/255 blue:50.0/255 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:250.0/255 green:200.0/255 blue:50.0/255 alpha:1]];
    [board setAbstractBoard: abstractBoard];
    if (untilMove > 0) {
        [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    }
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        if (untilMove > 0) {
            [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
        }
    }
//    NSLog(@"koMove %d", koMove);
    if (koMove > -1) {
        [self setValue:-1 forPosition:koMove];
    }
}



-(void) makeCapturesWithMove: (int) move withGroups: (NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>*) groupsByID andIDs: (NSMutableDictionary<NSNumber*, NSNumber*>*) stoneGroupIDs andAlterGroups: (BOOL) alter {
    int captures = 0;
    koMove = -1;

    if (move%gridSize != 0) {
        int neighborStone = move - 1;
        NSNumber *neighborStoneID = [stoneGroupIDs objectForKey: [NSNumber numberWithInt: neighborStone]];
        captures = [self getCapturesOfMove:move withGroups:groupsByID andIDs:stoneGroupIDs captures:captures neighborStone:neighborStone neighborStoneID:neighborStoneID andAlterGroups:alter];
    }
    if (move%gridSize != gridSize - 1) {
        int neighborStone = move + 1;
        NSNumber *neighborStoneID = [stoneGroupIDs objectForKey: [NSNumber numberWithInt: neighborStone]];
        captures = [self getCapturesOfMove:move withGroups:groupsByID andIDs:stoneGroupIDs captures:captures neighborStone:neighborStone neighborStoneID:neighborStoneID andAlterGroups:alter];
    }
    if (move/gridSize != 0) {
        int neighborStone = move - gridSize;
        NSNumber *neighborStoneID = [stoneGroupIDs objectForKey: [NSNumber numberWithInt: neighborStone]];
        captures = [self getCapturesOfMove:move withGroups:groupsByID andIDs:stoneGroupIDs captures:captures neighborStone:neighborStone neighborStoneID:neighborStoneID andAlterGroups:alter];
    }
    if (move/gridSize != gridSize - 1) {
        int neighborStone = move + gridSize;
        NSNumber *neighborStoneID = [stoneGroupIDs objectForKey: [NSNumber numberWithInt: neighborStone]];
        captures = [self getCapturesOfMove:move withGroups:groupsByID andIDs:stoneGroupIDs captures:captures neighborStone:neighborStone neighborStoneID:neighborStoneID andAlterGroups:alter];
    }
}
-(void) setValue: (int) val forPosition: (int) pos {
    int i = pos/gridSize, j = pos%gridSize;
    abstractBoard[i][j] = val;
}
-(int) getBoardValue: (int) pos {
    int i = pos/gridSize, j = pos%gridSize;
    return abstractBoard[i][j];
}
-(int) getCapturesOfMove: (int) move withGroups: (NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>*) groupsByID andIDs: (NSMutableDictionary<NSNumber*, NSNumber*>*) stoneGroupIDs captures: (int) captures neighborStone: (int) neighborStone neighborStoneID: (NSNumber*) neighborStoneID andAlterGroups: (BOOL) alter {
    int newCaptures = captures;
    if (neighborStoneID) {
        NSArray<NSNumber*>* neighborStoneGroup = [groupsByID objectForKey:neighborStoneID];
        if (![self groupHasLiberties:neighborStoneGroup]) {
            if (alter) {
                if (koMove < 0 && [neighborStoneGroup count]==1 && [self checkKo: move]) {
                    koMove = neighborStone;
//                    NSLog(@"komove check %d", koMove);
                } else if (alter) {
                    koMove = -1;
                }
            }
            newCaptures += [neighborStoneGroup count];
            [self captureGroup:neighborStoneID withGroups:groupsByID andIDs:stoneGroupIDs andAlterGroups:alter];
        }
    }
    return newCaptures;
}
-(BOOL) checkKo: (int) move {
    int position = [self getBoardValue:move];
    
    if (move%gridSize != 0) {
        int neighborStone = move - 1;
        int neighborPosition = [self getBoardValue:neighborStone];
        if (position != 3 - neighborPosition) {
            return NO;
        }
    }
    if (move%gridSize != gridSize - 1) {
        int neighborStone = move + 1;
        int neighborPosition = [self getBoardValue:neighborStone];
        if (position != 3 - neighborPosition) {
            return NO;
        }
    }
    if (move/gridSize != 0) {
        int neighborStone = move - gridSize;
        int neighborPosition = [self getBoardValue:neighborStone];
        if (position != 3 - neighborPosition) {
            return NO;
        }
    }
    if (move/gridSize != gridSize - 1) {
        int neighborStone = move + gridSize;
        int neighborPosition = [self getBoardValue:neighborStone];
        if (position != 3 - neighborPosition) {
            return NO;
        }
    }
    return YES;
}
-(void) captureGroup: (NSNumber*) groupID withGroups: (NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>*) groupsByID andIDs: (NSMutableDictionary<NSNumber*, NSNumber*>*) stoneGroupIDs andAlterGroups: (BOOL) alter {
    NSArray<NSNumber*> *group = [groupsByID objectForKey:groupID];
    if ([group count]>0) {
        int color = [self getBoardValue:[group firstObject].intValue];
        for (NSNumber *stone in group) {
            [self setValue:0 forPosition:stone.intValue];
            if (alter) {
                [stoneGroupIDs removeObjectForKey:stone];
            }
        }
        if (alter) {
            [groupsByID removeObjectForKey:groupID];
            if (color == 2) {
                blackCaptures += [group count];
            } else if (color == 1) {
                whiteCaptures += [group count];
            }
        }
    }
}
-(BOOL) groupHasLiberties: (NSArray<NSNumber*>*) group {
    for (NSNumber *stone in group) {
        if ([self stoneHasLiberties:stone.intValue]) {
            return YES;
        }
    }
    return NO;
}

-(BOOL) stoneHasLiberties: (int) stone {
    if (stone%gridSize != 0) {
        int neighborStone = stone - 1;
        int neighborStonePos = [self getBoardValue:neighborStone];
        if (neighborStonePos != 1 && neighborStonePos != 2) {
            return YES;
        }
    }
    if (stone%gridSize != gridSize - 1) {
        int neighborStone = stone + 1;
        int neighborStonePos = [self getBoardValue:neighborStone];
        if (neighborStonePos != 1 && neighborStonePos != 2) {
            return YES;
        }
    }
    if (stone/gridSize != 0) {
        int neighborStone = stone - gridSize;
        int neighborStonePos = [self getBoardValue:neighborStone];
        if (neighborStonePos != 1 && neighborStonePos != 2) {
            return YES;
        }
    }
    if (stone/gridSize != gridSize - 1) {
        int neighborStone = stone + gridSize;
        int neighborStonePos = [self getBoardValue:neighborStone];
        if (neighborStonePos != 1 && neighborStonePos != 2) {
            return YES;
        }
    }
    return NO;
}
-(void) settleGroups: (NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>*) groupsByID andIDs: (NSMutableDictionary<NSNumber*, NSNumber*>*) stoneGroupIDs forMove: (int) move {
    NSMutableArray *newGroup = [[NSMutableArray alloc] init];
    NSNumber *moveNumber = [NSNumber numberWithInt:move];
    [newGroup addObject: moveNumber];
    [stoneGroupIDs setObject:moveNumber forKey:moveNumber];
    [groupsByID setObject:newGroup forKey:moveNumber];
    
    if (move%gridSize != 0) {
        int neighborStone = move - 1;
        NSNumber *neighborStoneID = [stoneGroupIDs objectForKey: [NSNumber numberWithInt: neighborStone]];
        if (neighborStoneID) {
            [self mergeGroup1: moveNumber withGroup2:neighborStoneID withGroups:groupsByID andIDs:stoneGroupIDs];
        }
    }
    if (move%gridSize != gridSize - 1) {
        int neighborStone = move + 1;
        NSNumber *neighborStoneID = [stoneGroupIDs objectForKey: [NSNumber numberWithInt: neighborStone]];
        if (neighborStoneID) {
            [self mergeGroup1: [stoneGroupIDs objectForKey:moveNumber] withGroup2:neighborStoneID withGroups:groupsByID andIDs:stoneGroupIDs];
        }
    }
    if (move/gridSize != 0) {
        int neighborStone = move - gridSize;
        NSNumber *neighborStoneID = [stoneGroupIDs objectForKey: [NSNumber numberWithInt: neighborStone]];
        if (neighborStoneID) {
            [self mergeGroup1: [stoneGroupIDs objectForKey:moveNumber] withGroup2:neighborStoneID withGroups:groupsByID andIDs:stoneGroupIDs];
        }
    }
    if (move/gridSize != gridSize - 1) {
        int neighborStone = move + gridSize;
        NSNumber *neighborStoneID = [stoneGroupIDs objectForKey: [NSNumber numberWithInt: neighborStone]];
        if (neighborStoneID) {
            [self mergeGroup1: [stoneGroupIDs objectForKey:moveNumber] withGroup2:neighborStoneID withGroups:groupsByID andIDs:stoneGroupIDs];
        }
    }
}

-(void) mergeGroup1: (NSNumber*) group1 withGroup2: (NSNumber*) group2 withGroups: (NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*>*) groupsByID andIDs: (NSMutableDictionary<NSNumber*, NSNumber*>*) stoneGroupIDs {
    if (group1.intValue == group2.intValue) {
        return;
    }
    NSMutableArray<NSNumber*> *oldGroup, *newGroup;
    NSNumber *oldGroupID, *newGroupID;
    if (group1.intValue < group2.intValue) {
        oldGroup = [groupsByID objectForKey:group1];
        newGroup = [groupsByID objectForKey:group2];
        oldGroupID = group1;
        newGroupID = group2;
    } else {
        newGroup = [groupsByID objectForKey:group1];
        oldGroup = [groupsByID objectForKey:group2];
        oldGroupID = group2;
        newGroupID = group1;
    }
    [groupsByID removeObjectForKey: oldGroupID];
    [newGroup addObjectsFromArray:oldGroup];
    for (NSNumber *oldStone in oldGroup) {
        [stoneGroupIDs setObject:newGroupID forKey:oldStone];
    }
}

-(void) initGoStructures {
    koMove = -1;
    goStoneGroupIDsByPlayer = [[NSMutableDictionary alloc] init];
    goStoneGroupsByPlayerAndID = [[NSMutableDictionary alloc] init];
    [goStoneGroupIDsByPlayer setObject:[[NSMutableDictionary alloc] init] forKey:[NSNumber numberWithInt:1]];
    [goStoneGroupIDsByPlayer setObject:[[NSMutableDictionary alloc] init] forKey:[NSNumber numberWithInt:2]];
    [goStoneGroupsByPlayerAndID setObject:[[NSMutableDictionary alloc] init] forKey:[NSNumber numberWithInt:1]];
    [goStoneGroupsByPlayerAndID setObject:[[NSMutableDictionary alloc] init] forKey:[NSNumber numberWithInt:2]];
    deadBlackStones = [[NSMutableArray alloc] init];
    deadWhiteStones = [[NSMutableArray alloc] init];
}

-(void) copyGoBoard {
    int currentOpponent = 2 - [movesList count]%2;
    goStoneGroups = [[NSMutableDictionary alloc] initWithDictionary: [goStoneGroupsByPlayerAndID objectForKey:[NSNumber numberWithInt:currentOpponent]] copyItems:YES];
    goStoneGroupIDs = [[NSMutableDictionary alloc] initWithDictionary: [goStoneGroupIDsByPlayer objectForKey:[NSNumber numberWithInt:currentOpponent]] copyItems:YES];
    for (int i = 0; i<gridSize; ++i) {
        for (int j = 0; j<gridSize; ++j) {
            abstractGoBoard[i][j] = abstractBoard[i][j];
        }
    }
}

-(void) copyGoBoardBack {
    for (int i = 0; i<gridSize; ++i) {
        for (int j = 0; j<gridSize; ++j) {
            abstractBoard[i][j] = abstractGoBoard[i][j];
        }
    }
}

-(void) addGoMove: (int) move {
    int currentPlayer = 1 + [movesList count]%2;
    int color = 3 - currentPlayer;
    [self copyGoBoardBack];
    [self setValue:color forPosition:move];
    [self makeCapturesWithMove:move withGroups:goStoneGroups andIDs:goStoneGroupIDs andAlterGroups:NO];
    [board setNeedsDisplay];
}

-(void) processDeadStone: (int) move {
    int val = [self getBoardValue:move];
    NSNumber *moveNumber = [NSNumber numberWithInt:move];
    if (val == 1) {
        [deadWhiteStones addObject:moveNumber];
        [self setValue:0 forPosition:move];
    } else if (val == 2) {
        [deadBlackStones addObject:moveNumber];
        [self setValue:0 forPosition:move];
    } else {
        if ([deadWhiteStones containsObject:moveNumber]) {
            [self setValue:1 forPosition:move];
            [deadWhiteStones removeObject:moveNumber];
        } else if ([deadBlackStones containsObject:moveNumber]) {
            [self setValue:2 forPosition:move];
            [deadBlackStones removeObject:moveNumber];
        }
    }
//    [board setNeedsDisplay];
//    [zoomedBoard setNeedsDisplay];
    [self showTerritory:nil];
}

-(void) resetGoBoardBeforeFlood {
    for (int i = 0; i<gridSize; ++i) {
        for (int j = 0; j<gridSize; ++j) {
            int pos = abstractBoard[i][j];
            if (pos != 1 && pos != 2) {
                abstractBoard[i][j] = 0;
            }
        }
    }
}

-(int) getEmpyNeighbor: (int) move {
    
    if (move%gridSize != 0) {
        int neighborStone = move - 1;
        if ([self getBoardValue:neighborStone] == 0) {
            return neighborStone;
        }
    }
    if (move%gridSize != gridSize - 1) {
        int neighborStone = move + 1;
        if ([self getBoardValue:neighborStone] == 0) {
            return neighborStone;
        }
    }
    if (move/gridSize != 0) {
        int neighborStone = move - gridSize;
        if ([self getBoardValue:neighborStone] == 0) {
            return neighborStone;
        }
    }
    if (move/gridSize != gridSize - 1) {
        int neighborStone = move + gridSize;
        if ([self getBoardValue:neighborStone] == 0) {
            return neighborStone;
        }
    }
    return -1;
}

-(NSMutableArray<NSNumber*>*) getMovesForValue: (int) val {
    NSMutableArray<NSNumber*>* result = [[NSMutableArray alloc] init];
    for (int i = 0; i<gridSize; ++i) {
        for (int j = 0; j<gridSize; ++j) {
            if (abstractBoard[i][j] == val) {
                [result addObject:[NSNumber numberWithInt: (i*gridSize+j)]];
            }
        }
    }
    return result;
}


-(void) floodForPlayer: (int) player {
    for (int move = 0; move<gridSize*gridSize; ++move) {
        if ([self getBoardValue:move] == 3-player) {
            int emptyNeighbor = [self getEmpyNeighbor:move];
            while (emptyNeighbor > -1) {
                [self floodFillWorkerWithMove:emptyNeighbor andValue: player + 2];
                emptyNeighbor = [self getEmpyNeighbor:move];
            }
        }
    }
}

-(void) showTerritory: (id) sender {
    [self floodForPlayer:1];
    blackTerritory = [self getMovesForValue:3];
    [self resetGoBoardBeforeFlood];
    [self floodForPlayer:2];
    whiteTerritory = [self getMovesForValue:4];
    [self resetGoBoardBeforeFlood];
    
    int i = (int)[blackTerritory count] - 1, j = (int)[whiteTerritory count] - 1;
    while (i>-1 && j>-1) {
        int p1Stone = [blackTerritory objectAtIndex:i].intValue, p2Stone = [whiteTerritory objectAtIndex:j].intValue;
        if (p1Stone == p2Stone) {
            [blackTerritory removeObjectAtIndex:i]; [whiteTerritory removeObjectAtIndex:j];
            --i; --j;
        } else if (p1Stone > p2Stone) {
            --i;
        } else {
            --j;
        }
    }
    
    [board setWhiteTerritory: whiteTerritory]; [board setBlackTerritory: blackTerritory];
    [zoomedBoard setWhiteTerritory: whiteTerritory]; [zoomedBoard setBlackTerritory: blackTerritory];
    [board setNeedsDisplay]; [zoomedBoard setNeedsDisplay];
}



-(void) floodFillWorkerWithMove: (int) move andValue: (int) val {
    [self setValue:val forPosition:move];
    int neighbor = [self getEmpyNeighbor:move];
    while (neighbor > -1) {
        [self floodFillWorkerWithMove:neighbor andValue:val];
        neighbor = [self getEmpyNeighbor:move];
    }
}


-(void) showScore {
    [self showTerritory:nil];
    int whiteT = [whiteTerritory count], blackT = [blackTerritory count], whiteS = [[self getMovesForValue:1] count], blackS = [[self getMovesForValue:2] count];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"score", nil)
                                                                   message:[NSString stringWithFormat:@"black: %i + %i = %i\nwhite: 7.5 + %i + %i = %i.5",blackT, blackS, blackT+blackS, whiteT, whiteS, whiteT+whiteS+7]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* dismissAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil) style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction * action) {
                                                              if (!goMarkStones) {
                                                                  
                                                                  [blackTerritory removeAllObjects];
                                                                  [whiteTerritory removeAllObjects];
                                                                  [board setNeedsDisplay]; [zoomedBoard setNeedsDisplay];
                                                                  
                                                              }
                                                          }];
    [alert addAction:dismissAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView: playerStats];
        [alert.popoverPresentationController setSourceRect: playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

-(void) evaluateDeadStones {
    [self showTerritory:nil];
    int whiteT = [whiteTerritory count], blackT = [blackTerritory count], whiteS = [[self getMovesForValue:1] count], blackS = [[self getMovesForValue:2] count];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"black: %i + %i = %i\nwhite: 7.5 + %i + %i = %i.5",blackT, blackS, blackT+blackS, whiteT, whiteS, whiteT+whiteS+7]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* acceptAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"accept", nil) style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              finalMove = 1;
                                                              [self submitMove:nil];
                                                          }];
    UIAlertAction* rejectAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"reject", nil) style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * action) {
                                                              finalMove = 0;
                                                              [self submitMove:nil];
                                                          }];
    [alert addAction:acceptAction];
    [alert addAction:rejectAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView: playerStats];
        [alert.popoverPresentationController setSourceRect: playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}


-(void) detectCaptureOfOpponent: (int) opponentColor atPosition: (int) rowCol {
    struct Capture capture;
    int i = rowCol / 19, j = rowCol % 19, myColor = (opponentColor == 1) ? 2 : 1;
    if ((i-3) > -1) {
        if (abstractBoard[i-3][j] == myColor) {
            if ((abstractBoard[i-1][j] == opponentColor) && (abstractBoard[i-2][j] == opponentColor)) {
                abstractBoard[i-1][j] = 0;
                abstractBoard[i-2][j] = 0;
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                if (opponentColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
            }
        }
    }
}


-(void) detectKeryoCaptureOfOpponent: (int) opponentColor atPosition: (int) rowCol {
    struct Capture capture;
    int i = rowCol / 19, j = rowCol % 19, myColor = (opponentColor == 1) ? 2 : 1;
    if ((i-4) > -1) {
        if (abstractBoard[i-4][j] == myColor) {
            if ((abstractBoard[i-1][j] == opponentColor) && (abstractBoard[i-2][j] == opponentColor) && (abstractBoard[i-3][j] == opponentColor)) {
                abstractBoard[i-1][j] = 0;
                abstractBoard[i-2][j] = 0;
                abstractBoard[i-3][j] = 0;
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-3)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-3)*19 + (j-3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j-3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+3)*19 + (j-3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+3)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i+1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+3)*19 + (j+3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j+3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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
                capture.color = opponentColor;
                capture.position = (i-1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-3)*19 + (j+3);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
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

-(BOOL) detectKeryoPoof: (int) myColor atPosition: (int) rowCol {
    BOOL poof = NO;
    struct Capture capture;
    int i = rowCol / 19, j = rowCol % 19, opponentColor = (myColor == 1) ? 2 : 1, capturesLength = (int) [captures count];
    if (((i-3) > -1) && ((i+1) < 19)) { // left
        if (abstractBoard[i-1][j] == myColor && abstractBoard[i-2][j] == myColor) {
            if ((abstractBoard[i-3][j] == opponentColor) && (abstractBoard[i+1][j] == opponentColor)) {
                abstractBoard[i-2][j] = 0;
                abstractBoard[i-1][j] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i-2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((i-3) > -1) && ((j-3) > -1) && ((i+1) < 19) && ((j+1) < 19)) { // up left
        if (abstractBoard[i-1][j-1] == myColor && abstractBoard[i-2][j-2] == myColor) {
            if ((abstractBoard[i-3][j-3] == opponentColor) && (abstractBoard[i+1][j+1] == opponentColor)) {
                abstractBoard[i-2][j-2] = 0;
                abstractBoard[i-1][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i-2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((j-3) > -1) && ((j+1) < 19)) { // up
        if (abstractBoard[i][j-1] == myColor && abstractBoard[i][j-2] == myColor) {
            if ((abstractBoard[i][j-3] == opponentColor) && (abstractBoard[i][j+1] == opponentColor)) {
                abstractBoard[i][j-2] = 0;
                abstractBoard[i][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((i-1) > -1) && ((j-3) > -1) && ((i+3) < 19) && ((j+1) < 19)) { // up right
        if (abstractBoard[i+1][j-1] == myColor && abstractBoard[i+2][j-2] == myColor) {
            if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i+3][j-3] == opponentColor)) {
                abstractBoard[i+2][j-2] = 0;
                abstractBoard[i+1][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i+2)*19 + (j-2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((i+3) < 19) && ((i-1) > -1)) { // right
        if (abstractBoard[i+1][j] == myColor && abstractBoard[i+2][j] == myColor) {
            if ((abstractBoard[i+3][j] == opponentColor) && (abstractBoard[i-1][j] == opponentColor)) {
                abstractBoard[i+2][j] = 0;
                abstractBoard[i+1][j] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i+2)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((i-1) > -1) && ((j-1) > -1) && ((i+3) < 19) && ((j+3) < 19)) { // down right
        if (abstractBoard[i+1][j+1] == myColor && abstractBoard[i+2][j+2] == myColor) {
            if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i+3][j+3] == opponentColor)) {
                abstractBoard[i+2][j+2] = 0;
                abstractBoard[i+1][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i+2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i+1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((j+2) < 19) && ((j-1) > -1)) { // down
        if (abstractBoard[i][j+1] == myColor && abstractBoard[i][j+2] == myColor) {
            if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j+3] == opponentColor)) {
                abstractBoard[i][j+1] = 0;
                abstractBoard[i][j+2] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((i-3) > -1) && ((j-1) > -1) && ((i+1) < 19) && ((j+3) < 19)) { // down left
        if (abstractBoard[i-1][j+1] == myColor && abstractBoard[i-2][j+2] == myColor) {
            if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i-3][j+3] == opponentColor)) {
                abstractBoard[i-2][j+2] = 0;
                abstractBoard[i-1][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i-2)*19 + (j+2);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    
    // 4 directions with center of 3 stones placed to poof
    if (((i-2) > -1) && ((i+2) < 19)) { // horizontal
        if (abstractBoard[i-1][j] == myColor && abstractBoard[i+1][j] == myColor) {
            if ((abstractBoard[i-2][j] == opponentColor) && (abstractBoard[i+2][j] == opponentColor)) {
                abstractBoard[i+1][j] = 0;
                abstractBoard[i-1][j] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-1)*19 + (j);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((i-2) > -1) && ((j-2) > -1) && ((i+2) < 19) && ((j+2) < 19)) { // up left
        if (abstractBoard[i-1][j-1] == myColor && abstractBoard[i+1][j+1] == myColor) {
            if ((abstractBoard[i-2][j-2] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor)) {
                abstractBoard[i+1][j+1] = 0;
                abstractBoard[i-1][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((j-2) > -1) && ((j+2) < 19)) { // vertical
        if (abstractBoard[i][j-1] == myColor && abstractBoard[i][j+1] == myColor) {
            if ((abstractBoard[i][j-2] == opponentColor) && (abstractBoard[i][j+2] == opponentColor)) {
                abstractBoard[i][j+1] = 0;
                abstractBoard[i][j-1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
            }
        }
    }
    if (((i-2) > -1) && ((j-2) > -1) && ((i+2) < 19) && ((j+2) < 19)) { // up right
        if (abstractBoard[i+1][j-1] == myColor && abstractBoard[i+1][j-1] == myColor) {
            if ((abstractBoard[i-2][j+2] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor)) {
                abstractBoard[i+1][j-1] = 0;
                abstractBoard[i-1][j+1] = 0;
                abstractBoard[i][j] = 0;
                if (myColor == 1) {
                    whiteCaptures += 2;
                } else {
                    blackCaptures += 2;
                }
                capture.color = myColor;
                capture.position = (i+1)*19 + (j-1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                capture.position = (i-1)*19 + (j+1);
                [captures addObject:[NSValue value:&capture withObjCType:@encode(struct Capture)]];
                poof = true;
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




-(int) parseMove: (NSString *) move {
    return [move intValue];
//    int col = [move characterAtIndex: 0] - 65;
//    col = (col < 8) ? col : --col;
//    int row = 19 - [[move substringWithRange:NSMakeRange(1,[move length] - 1)] intValue];
//    return row*19 + col;
}

-(void) resetBoard {
    finalMove = -1;
    for(int i = 0; i < 19; ++i) {
        for(int j = 0; j < 19; ++j) {
            abstractBoard[i][j] = 0;
        }
    }
}


- (void) notifyNewMessage {
    [messageButtonImageView setAnimationDuration:1.2];
    [messageButtonImageView startAnimating];
}


-(void) toggleBoardLock: (id) sender {
    UIButton *button=(UIButton *)sender;
    BOOL locked = [[NSUserDefaults standardUserDefaults] boolForKey:@"notBack2Dash"];
    if (locked) {
        [button setImage:[UIImage imageNamed:@"unlock.png"] forState: UIControlStateNormal];
        [[NSUserDefaults standardUserDefaults] setBool: NO forKey:@"notBack2Dash"];
    } else {
        [button setImage:[UIImage imageNamed:@"lock.png"] forState: UIControlStateNormal];
        [[NSUserDefaults standardUserDefaults] setBool: YES forKey:@"notBack2Dash"];
    }
}

- (void)messageTap:(id)sender {
    [messageButtonImageView stopAnimating];
    [receivedMessageView flashScrollIndicators];
    
    messagePopover = [[PopoverView alloc] init];
    [messagePopover setDelegate:self];
    
    [replyMessageView setFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 44)];
    CGPoint showPoint = [self.view convertPoint:messageButton.center fromView:messageButton];
    showPoint.y = showPoint.y + messageButton.bounds.size.height/2;
    if (isLastMove) {
        if (activeGame) {
            if (![receivedMessage isEqualToString:@""]) {
                [messagePopover showAtPoint: showPoint inView:self.view  withViewArray:[NSArray arrayWithObjects:receivedMessageView, replyMessageView,nil]];
            } else {
                [replyMessageView setFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 88)];
                [messagePopover showAtPoint:showPoint inView:self.view withContentView:replyMessageView];
            }
            [self.replyMessageView becomeFirstResponder];
        } else if (![receivedMessage isEqualToString:@""]) {
            [messagePopover showAtPoint:showPoint inView:self.view withContentView:receivedMessageView];
        }
    } else if (![receivedMessage isEqualToString:@""]) {
            [messagePopover showAtPoint:showPoint inView:self.view withContentView:receivedMessageView];
    }
//    [receivedMessageView sizeToFit];
}

- (void) cancelResignHide {
    if (activeGame) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"options", nil)
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"request set cancellation", nil) style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action) {
                                                                 UIAlertController *confirmController = [UIAlertController
                                                                                                         alertControllerWithTitle:NSLocalizedString(@"Are you sure?", nil)
                                                                                                         message: NSLocalizedString(@"Your opponent will still have to agree to your request.", nil)
                                                                                                         preferredStyle:UIAlertControllerStyleActionSheet];
                                                                 UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                                                                 }];
                                                                 UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"yes, request to cancel set", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                                     NSError *error;
                                                                     
                                                                     NSString *post = [NSString stringWithFormat:@"sid=%@&command=request&mobile=",[self.game setID]];
                                                                     NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
                                                                     NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
                                                                     
                                                                     NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                                                                     
                                                                     NSURL *url = [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/cancel"];
                                                                     if (development) {
                                                                         url = [NSURL URLWithString:@"https://development.pente.org/gameServer/tb/cancel"];
                                                                     }
                                                                     [request setURL:url];
                                                                     [request setHTTPMethod:@"POST"];
                                                                     [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
                                                                     [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
                                                                     [request setHTTPBody:postData];
                                                                     [request setTimeoutInterval:7.0];
                                                                     NSURLResponse *response;
                                                                     NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                                                                     NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                                                                     if ([dashboardString containsString: @"Error: Cancel request already exists."]) {
                                                                         UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:NSLocalizedString(@"A cancel request already exists.",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
                                                                         [alert show];
                                                                     } else {
                                                                         PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                                                                         [navControllor setDidMove: YES];
                                                                     }
                                                                     [self.navigationController popToRootViewControllerAnimated:YES];
                                                                 }];
                                                                 [confirmController addAction:cancelAction];
                                                                 [confirmController addAction:confirmAction];
                                                                 
                                                                 if (confirmController.popoverPresentationController != nil) {
                                                                     [confirmController.popoverPresentationController setSourceView: self.submitButton];
                                                                     [confirmController.popoverPresentationController setSourceRect: self.submitButton.bounds];
                                                                 }
                                                                 
                                                                 [self presentViewController:confirmController animated:YES completion:nil];
                                                             }];
        UIAlertAction* resignAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"resign game", nil) style:UIAlertActionStyleDestructive
                                                              handler:^(UIAlertAction * action) {
                                                                  UIAlertController *confirmController = [UIAlertController
                                                                                                          alertControllerWithTitle:NSLocalizedString(@"Are you sure?", nil)
                                                                                                          message: NSLocalizedString(@"Resigning means forfeiting the game.", nil)
                                                                                                          preferredStyle:UIAlertControllerStyleActionSheet];
                                                                  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                                                                  }];
                                                                  UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"yes, resign", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                                                      NSString *post = [NSString stringWithFormat:@"gid=%@&command=resign&mobile=",[self.game gameID]];
                                                                      NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
                                                                      NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
                                                                      
                                                                      NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                                                                      
                                                                      NSURL *url = [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/resign"];
                                                                      if (development) {
                                                                          url = [NSURL URLWithString:@"https://development.pente.org/gameServer/tb/resign"];
                                                                      }
                                                                      [request setURL:url];
                                                                      [request setHTTPMethod:@"POST"];
                                                                      [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
                                                                      [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
                                                                      [request setHTTPBody:postData];
                                                                      [request setTimeoutInterval:7.0];
                                                                      
                                                                      [request setHTTPShouldUsePipelining: YES];
                                                                      
                                                                      NSURLResponse *response;
                                                                      NSError *error;
                                                                      [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                                                                      
                                                                      PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                                                                      [navControllor setDidMove: YES];
                                                                      [navControllor popToRootViewControllerAnimated:YES];
                                                                  }];
                                                                  [confirmController addAction:cancelAction];
                                                                  [confirmController addAction:confirmAction];
                                                                  
                                                                  if (confirmController.popoverPresentationController != nil) {
                                                                      [confirmController.popoverPresentationController setSourceView: self.submitButton];
                                                                      [confirmController.popoverPresentationController setSourceRect: self.submitButton.bounds];
                                                                  }
                                                                  
                                                                  [self presentViewController:confirmController animated:YES completion:nil];
                                                              }];
        [alert addAction:cancelAction];
        [alert addAction:resignAction];
        
        PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
        if (navControllor.player.subscriber && (canUnHide || canHide)) {
            UIAlertAction* hideOrUnhideAction;
            if ((canHide && hideString.length == 0) || (canUnHide && hideString.length > 0)) {
                hideOrUnhideAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"hide game from public", nil) style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                if (hideString.length == 0) {
                                                                    hideString = @"&hide=yes";
                                                                } else {
                                                                    hideString = @"";
                                                                }
                                                            }];
            } else if ((canHide && hideString.length > 0) || (canUnHide && hideString.length == 0)) {
                hideOrUnhideAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"unhide game from public", nil) style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction * action) {
                                                                if (hideString.length == 0) {
                                                                    hideString = @"&hide=no";
                                                                } else {
                                                                    hideString = @"";
                                                                }
                                                            }];
            }

            [alert addAction:hideOrUnhideAction];

        }
        
        [alert addAction:[UIAlertAction actionWithTitle: NSLocalizedString(@"dismiss", nil) style:UIAlertActionStyleCancel
                                                handler:^(UIAlertAction * action) {
                                                }]];
        if (alert.popoverPresentationController) {
            [alert.popoverPresentationController setSourceView: playerStats];
            [alert.popoverPresentationController setSourceRect: playerStats.bounds];
        }
        [self presentViewController:alert animated:YES completion:nil];
    }
}



-(void) presentCancelReply {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:[self.game opponentName]
                                                                   message:[NSString stringWithFormat:NSLocalizedString(@"is requesting that this set be cancelled: %@",nil), cancelMsg]
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* acceptCancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"accept", nil) style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                             [self sendCancelReply:@"Yes"];
                                                         }];
    UIAlertAction* declineCancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"decline", nil) style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * action) {
                                                             [self sendCancelReply:@"No"];
                                                         }];
    [alert addAction:acceptCancelAction];
    [alert addAction:declineCancelAction];
    
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView: playerStats];
        [alert.popoverPresentationController setSourceRect: playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

-(void) sendCancelReply: (NSString *) reply {
    NSError *error = nil;
    NSURLResponse *response;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    NSString *post = [NSString stringWithFormat:@"sid=%@&gid=%@&command=%@&mobile=", [self.game setID] ,[self.game gameID], reply];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSURL *url = [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/cancel"];
    if (development) {
        url = [NSURL URLWithString:@"https://development.pente.org/gameServer/tb/cancel"];
    }
    [request setURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody: postData];
    [request setTimeoutInterval:7.0f];
    
    [request setHTTPShouldUsePipelining: YES];
    
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
    [navControllor setDidMove: YES];
    [self.navigationController popToRootViewControllerAnimated:YES];
}


-(void) presentDoublePass {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"double pass", nil)
                                                                   message:@"Your opponent has made a pass as well. Mark the stones you think are dead and press submit for their evaluation."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* acceptAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Got it", nil) style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * action) {
                                                         }];
    UIAlertAction* dismissAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"No reminders", nil) style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * action) {
                                                              [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"doublePassInfo"];
                                                          }];
    
    [alert addAction:acceptAction];
    [alert addAction:dismissAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView: playerStats];
        [alert.popoverPresentationController setSourceRect: playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
{
    if ([text isEqualToString:@"\n"] ) {
        [messagePopover dismiss];
        [textView resignFirstResponder];
        return NO;
    }
    if (range.length + range.location > textView.text.length)
    {
        return NO;
    }
    
    NSUInteger newLength = [textView.text length] + [text length] - range.length;
    return (newLength > 255) ? NO : YES;
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

- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    replyMessage = replyMessageView.text;
    if (showAds) {
        [self.view bringSubviewToFront:bannerView];
    }
//    NSLog(@"kitty Dismiss");
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [webView evaluateJavaScript:@"document.body.scrollHeight;" completionHandler:^(NSString *result, NSError * _Nullable error) {
        int contentSize = [result intValue];
        //        int contentSize = [[webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.body.scrollHeight;"]] intValue],
        int webViewSize = (int) webView.scrollView.contentSize.height;
        webViewSize = (int) webView.frame.size.height;

    //    NSLog(@"%i %i", contentSize, webViewSize);
        if (contentSize*2 > 3*webViewSize && [moveStatsString length]>10) {
            [moveStatsString deleteCharactersInRange:NSMakeRange(0, moveStatsString.length/2)];
            [playerStats loadHTMLString: [HEADERSTRING stringByAppendingString:[playerStatsBaseString stringByAppendingString:moveStatsString]] baseURL:nil];
        } else if (contentSize > webViewSize && [moveStatsString length]>10) {
            [moveStatsString deleteCharactersInRange:NSMakeRange(0, [moveStatsString rangeOfString:@".</b> "].location+6)];
    //        NSLog(moveStatsString);
            [playerStats loadHTMLString: [HEADERSTRING stringByAppendingString:[playerStatsBaseString stringByAppendingString:moveStatsString]] baseURL:nil];
        }
    }];
                               
}

-(void) webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        NSString *urlString = navigationAction.request.URL.absoluteString;
        PenteWebViewController *webViewController = [[PenteWebViewController alloc] initWithAddress: urlString];
        [self.navigationController pushViewController:webViewController animated:YES];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}


@end
