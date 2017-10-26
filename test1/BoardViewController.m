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
//#import "GADBannerView.h"
#import <QuartzCore/QuartzCore.h>
#import "PopoverView.h"
#import "DatabaseViewController.h"
#import <NSHash/NSString+NSHash.h>
#import "penteLive-Swift.h"


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
int finalMove = -1, connect6Move1 = -1, connect6Move2 = -1, dPenteMove1 = -1, dPenteMove2 = -1, dPenteMove3 = -1, dPenteMove4 = -1,
whiteCaptures, blackCaptures, lastMove;
BOOL dPenteOpening = NO;
BOOL dPenteChoice = NO;
BOOL poofed = NO;
char coordinateLetters[19] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T'};

struct Capture {
    int color;
    int position;
};


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    showedAd = NO;
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

//    dPenteChoiceLabel.hidden = NO;
//    player1Button.hidden = NO;
//    player1Button.alpha = 0.5f;
//    player2Button.hidden = NO;
//    player2Button.alpha = 0.5f;

    
    playerStats = [[UIWebView alloc] initWithFrame:CGRectMake(2, submitButton.frame.origin.y + 3, self.view.bounds.size.width - 4,  submitButton.frame.origin.y - 3)];
    [playerStats setDelegate:self];
    [playerStats setAlpha:0.90];
    [playerStats setBackgroundColor:[UIColor colorWithRed:0.98f green:0.98f blue:0.98f alpha:0.95]];
    playerStats.clipsToBounds = YES;
    playerStats.layer.cornerRadius = 1.0f;
    playerStats.layer.borderWidth = 1.0f;
    playerStats.layer.borderColor = [[UIColor grayColor] CGColor];
    //    receivedMessageView.contentInset = UIEdgeInsetsMake(7.0,7.0,0,0.0);
    [playerStats setDataDetectorTypes:UIDataDetectorTypeLink];
    [playerStats setUserInteractionEnabled:YES];
    [playerStats.scrollView setScrollEnabled:NO];
    //    playerStats.contentInset = UIEdgeInsetsMake(-5.0,0.0,0,0.0);
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat newOriginY = screenHeight - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height;
    if (showAds) {
        //        playerStats = [[UIWebView alloc] initWithFrame:CGRectMake(2, submitButton.frame.origin.y + submitButton.frame.size.height + 3, self.view.bounds.size.width - 4, 84)];
        playerStats.frame = CGRectMake(2, submitButton.frame.origin.y + 3 + submitButton.frame.size.height, self.view.bounds.size.width - 4,  newOriginY - submitButton.frame.origin.y - GAD_SIZE_320x50.height -5 -  submitButton.frame.size.height);
    } else {
        playerStats.frame = CGRectMake(2, submitButton.frame.origin.y +  3 + submitButton.frame.size.height, self.view.bounds.size.width - 4, newOriginY - submitButton.frame.origin.y - 5 -  submitButton.frame.size.height);
//        playerStats = [[UIWebView alloc] initWithFrame:CGRectMake(2, submitButton.frame.origin.y + 3, self.view.bounds.size.width - 4, 135)];
    }
    [self.view addSubview: playerStats];

    if (showAds) {
        CGPoint origin = CGPointMake(0.0, self.view.frame.size.height - self.navigationController.navigationBar.frame.size.height - kGADAdSizeBanner.size.height);
        bannerView = [[GADBannerView alloc] initWithAdSize:kGADAdSizeBanner origin:origin];
        bannerView.rootViewController = self;
        [bannerView setDelegate: self];
        //    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
        newOriginY = screenHeight - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height - bannerView.frame.size.height;
//        newOriginY = playerStats.frame.origin.y + playerStats.frame.size.height;
        CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
        bannerView.frame = newBannerViewFrame;
        bannerView.frame = newBannerViewFrame;
        bannerView.adUnitID = @"ca-app-pub-3326997956703582/5064095440";
        bannerView.rootViewController = self;
        GADRequest *request = [GADRequest request];
        //            request.testDevices = [NSArray arrayWithObjects:kGADSimulatorID, nil];
        [bannerView loadRequest:request];
        [self.view addSubview:bannerView];
//        [self.view bringSubviewToFront:bannerView];
//        NSLog(@"kittty");
    }
    [submitButton setEnabled:NO];
    [submitButton setTitle:NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
    [submitButton setAlpha:0.5];
    [board setAbstractBoard: abstractBoard];
    [zoomedBoard setAbstractBoard: abstractBoard];


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
        connect6Move1 = -1;
        connect6Move2 = -1;
        dPenteMove1 = -1;
        dPenteMove2 = -1;
        dPenteMove3 = -1;
        dPenteMove4 = -1;
//        dPenteChoice = NO;
//        dPenteOpening = NO;
        poofed = NO;
        [whiteStoneCaptures setStoneColor:[UIColor whiteColor]];
        [blackStoneCaptures setStoneColor:[UIColor blackColor]];
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
    [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects: messsageBarButton, negativeSpacer, [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"cancel.png"] style:UIBarButtonItemStylePlain target:self action:@selector(cancelResign)], positiveSpacer, nil] animated:NO];
    dPenteChoiceLabel.text = NSLocalizedString(@"Play as",nil);
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
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
    [stone setStoneColor:[UIColor whiteColor]];
    [stone setNeedsDisplay];
    [zoomedStone setStoneColor:[UIColor whiteColor]];
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
    if (dPenteChoice) {
        return;
    }
//    NSLog(@"SwipeRight %i", lastMove);
    if (lastMove < [movesList count]) {
        whiteCaptures = 0;
        blackCaptures = 0;
        ++lastMove;
        if ([[game gameType] isEqualToString:@"Connect6"]) {
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
    if (dPenteChoice) {
        return;
    }
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
        if ([[game gameType] isEqualToString:@"Connect6"]) {
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
            [stone setStoneColor: [UIColor whiteColor]];
            [zoomedStone setStoneColor: [UIColor whiteColor]];
        } else if (dPenteMove2 == -1) {
            [stone setStoneColor: [UIColor blackColor]];
            [zoomedStone setStoneColor: [UIColor blackColor]];
        } else if (dPenteMove3 == -1) {
            [stone setStoneColor: [UIColor whiteColor]];
            [zoomedStone setStoneColor: [UIColor whiteColor]];
        } else if (dPenteMove4 == -1) {
            [stone setStoneColor: [UIColor blackColor]];
            [zoomedStone setStoneColor: [UIColor blackColor]];
        }
        [stone setNeedsDisplay];
        [zoomedStone setNeedsDisplay];
    } else {
//        NSLog(@"kitty no");
    }
    
    int i, j;
    CGPoint currentPoint = [recognizer locationInView: self.board];
    float cellSize = self.board.bounds.size.width / 19;
    j = (int) floorf(currentPoint.x/cellSize);
    i = (int) floorf(currentPoint.y/cellSize);
    
    switch ([recognizer state]) {
        case UIGestureRecognizerStateBegan:
//            NSLog(@"hi start %i %i \n %@", lastMove, [movesList count], movesList);
            if (lastMove != [movesList count] && activeGame ) {
                whiteCaptures = 0;
                blackCaptures = 0;
                isLastMove = YES;
                lastMove = (int) [movesList count];
                [self replayGame:lastMove];
                [board setNeedsDisplay];
                [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.f]];
            }
            if ([captures count] != 0) {
                [self undoCaptures];
                [self updateCaptures];
                [board setNeedsDisplay];
            }
            finalMove = -1;
            [zoomedBoard setHidden: NO];
            [stone setHidden: YES];
            if (abstractBoard[i][j] == 0) {
                [zoomedStone setHidden: NO];
                [horizontalLine setHidden:NO];
                [verticalLine setHidden:NO];
            }
//            NSLog(@"hi oopsie");
            break;
        case UIGestureRecognizerStateEnded:
//            NSLog(@"hi ended");
            if ([zoomedBoard isHidden] && activeGame) {
                [submitButton setEnabled:NO];
                [submitButton setTitle:NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
                [submitButton setAlpha:0.5];
                break;
            }
            [zoomedBoard setHidden: YES];
//            if (![zoomedStone isHidden]) {
            if (abstractBoard[i][j] == 0 && activeGame) {
                stone.center = CGPointMake(cellSize*j + cellSize/2, cellSize*i + cellSize/2);
                [zoomedStone setHidden: YES];
                [horizontalLine setHidden:YES];
                [verticalLine setHidden:YES];
//                NSLog(@"hi oops %i %i",i,j);

                finalMove = 19*i + j;

                if (!([[game gameType] isEqualToString:@"Connect6"] && (connect6Move1 == -1)) && !(dPenteOpening && ([[game gameType] isEqualToString:@"D-Pente"] || [[game gameType] isEqualToString:@"DK-Pente"]) && (dPenteMove3 == -1))) {
                    [submitButton setEnabled:YES];
                    if ([[game gameType] isEqualToString:@"Connect6"]) {
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d",nil), coordinateLetters[connect6Move1 % 19], 19 - (connect6Move1 / 19), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateNormal];
                    } else if (([[game gameType] isEqualToString:@"D-Pente"] || [[game gameType] isEqualToString:@"DK-Pente"]) && dPenteOpening) {
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d-%c%d-%c%d",nil), coordinateLetters[dPenteMove1 % 19], 19 - (dPenteMove1 / 19), coordinateLetters[dPenteMove2 % 19], 19 - (dPenteMove2 / 19), coordinateLetters[dPenteMove3 % 19], 19 - (dPenteMove3 / 19), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateNormal];
                    } else {
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d",nil), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateNormal];
                    }
                    [submitButton setAlpha:1];
                }

                [stone setHidden: NO];
                if ([[game gameType] isEqualToString:@"Connect6"]) {
                    if (connect6Move1 == -1) {
                        connect6Move1 = finalMove;
                        if ([[game myColor] isEqualToString:@"white"]) {
                            abstractBoard[i][j] = 1;
                        } else {
                            abstractBoard[i][j] = 2;
                        }
                        [board setAbstractBoard: abstractBoard];
                        [zoomedBoard setAbstractBoard: abstractBoard];
                        [board setNeedsDisplay];
                        [zoomedBoard setNeedsDisplay];
                    } else {
                        connect6Move2 = finalMove;
                    }
                }
                if (dPenteOpening && ([[game gameType] isEqualToString:@"D-Pente"] || [[game gameType] isEqualToString:@"DK-Pente"])) {
                    if (dPenteMove1 == -1) {
                        dPenteMove1 = finalMove;
                        abstractBoard[i][j] = 1;
                        [board setAbstractBoard: abstractBoard];
                        [zoomedBoard setAbstractBoard: abstractBoard];
                        [board setNeedsDisplay];
                        [zoomedBoard setNeedsDisplay];
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d",nil), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateDisabled];
                        [submitButton setEnabled:NO];
                        [submitButton setAlpha:0.5];
                    } else if (dPenteMove2 == -1) {
                        dPenteMove2 = finalMove;
                        abstractBoard[i][j] = 2;
                        [board setAbstractBoard: abstractBoard];
                        [zoomedBoard setAbstractBoard: abstractBoard];
                        [board setNeedsDisplay];
                        [zoomedBoard setNeedsDisplay];
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d",nil), coordinateLetters[dPenteMove1 % 19], 19 - (dPenteMove1 / 19), coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateDisabled];
                        [submitButton setEnabled:NO];
                        [submitButton setAlpha:0.5];
                    } else if (dPenteMove3 == -1) {
                        dPenteMove3 = finalMove;
                        abstractBoard[i][j] = 1;
                        [board setAbstractBoard: abstractBoard];
                        [zoomedBoard setAbstractBoard: abstractBoard];
                        [board setNeedsDisplay];
                        [zoomedBoard setNeedsDisplay];
                        [submitButton setTitle: [NSString stringWithFormat:NSLocalizedString(@"submit: %c%d-%c%d-%c%d",nil), coordinateLetters[dPenteMove1 % 19], 19 - (dPenteMove1 / 19), coordinateLetters[dPenteMove2 % 19], 19 - (dPenteMove2 / 19),coordinateLetters[finalMove % 19], 19 - (finalMove / 19)] forState:UIControlStateDisabled];
                        [submitButton setEnabled:NO];
                        [submitButton setAlpha:0.5];
                    } else {
                        dPenteMove4 = finalMove;
                        [self detectCaptureOfOpponent:1 atPosition:finalMove];
                        [board setAbstractBoard: abstractBoard];
                        [zoomedBoard setAbstractBoard: abstractBoard];
                        [board setNeedsDisplay];
                        [zoomedBoard setNeedsDisplay];
                    }
                }
                if (!([[game gameType] isEqualToString:@"Connect6"] || [[game gameType] isEqualToString:@"Gomoku"])) {
                    if ([[game gameType] isEqualToString:@"Poof-Pente"]) {
                        if ([self detectPoof:(([[stone stoneColor] isEqual: [UIColor blackColor]]) ? 2 : 1) atPosition: finalMove]) {
                            [stone setHidden:YES];
                        }
                    }
                    [self detectCaptureOfOpponent:(([[stone stoneColor] isEqual: [UIColor blackColor]]) ? 1 : 2) atPosition: finalMove];
                    if ([[game gameType] isEqualToString:@"Keryo-Pente"] || [[game gameType] isEqualToString:@"DK-Pente"]) {
                        [self detectKeryoCaptureOfOpponent:(([[stone stoneColor] isEqual: [UIColor blackColor]]) ? 1 : 2) atPosition: finalMove];
                    }
                    if ([captures count] != 0) {
                        //NSLog(@"kittyCapture of color %i at position %i,%i",(([[stone stoneColor] isEqual: [UIColor blackColor]]) ? 1 : 2),finalMove/19,finalMove%19);
                        [self updateCaptures];
                        [board setAbstractBoard:abstractBoard];
                        [board setNeedsDisplay];
                    }
                }
            } else if (activeGame) {
                finalMove = -1;
                [submitButton setEnabled:NO];
                [submitButton setTitle:NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
                [submitButton setAlpha:0.5];
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
//            [zoomedBoard setHidden: NO];
//            [zoomedStone setHidden: NO];
//            [stone setHidden: YES];
//            [horizontalLine setHidden:NO];
//            [verticalLine setHidden:NO];
            if (activeGame) {
//                        NSLog(@"hi oopsie kitty %i %i", i, j);
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
            if (abstractBoard[i][j] == 0 && activeGame) {
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
    int myColor = ([[game myColor] isEqualToString:@"white"]) ? 1 : 2;
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
    [spinner setColor:[[game myColor] isEqualToString:@"white"] ? [UIColor blackColor]:[UIColor whiteColor]];
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(submitMoveToServer) toTarget:self withObject:nil];

}

-(void) submitMoveToServer {
//    NSLog(@"kitty %d", finalMove);

    NSString *moveString;
    if ([[game gameType] isEqualToString:@"Connect6"] && (connect6Move1 != -1) && (connect6Move2 != -1)) {
        moveString = [NSString stringWithFormat:@"%i,%i", connect6Move1, connect6Move2];
    } else if (([[game gameType] isEqualToString:@"D-Pente"] || [[game gameType] isEqualToString:@"DK-Pente"]) && (dPenteMove1 != -1) && (dPenteMove2 != -1) && (dPenteMove3 != -1) && (dPenteMove4 != -1) && dPenteOpening) {
        moveString = [NSString stringWithFormat:@"%i,%i,%i,%i,", dPenteMove1, dPenteMove2, dPenteMove3, dPenteMove4];
    } else if (([[game gameType] isEqualToString:@"D-Pente"] || [[game gameType] isEqualToString:@"DK-Pente"]) && (finalMove != -1) && dPenteChoice) {
        moveString = [NSString stringWithFormat:@"1,%i", finalMove];
    } else if (finalMove != -1) {
        moveString = [NSString stringWithFormat:@"%i", finalMove];
    }

    //    NSLog(@"kitty %@", moveString);
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url;
    NSURLResponse *response;
    NSError *error;
    NSData *responseData;
    //    NSLog(@"kittyLog %@", replyMessage);
    if ([replyMessage isEqualToString:@""]) {
        url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/game?command=move&mobile=&gid=%@&moves=%@&message=",[game gameID],moveString];
        if (development) {
            url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/tb/game?command=move&mobile=&gid=%@&moves=%@&message=",[game gameID],moveString];
        }
    } else {
        url = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/game?command=move&mobile=&gid=%@&moves=%@&message=%@",[game gameID],moveString,[self URLEncodedString_ch:replyMessage]];
        if (development) {
            url = [NSString stringWithFormat:@"https://development.pente.org/gameServer/tb/game?command=move&mobile=&gid=%@&moves=%@&message=%@",[game gameID],moveString,[self URLEncodedString_ch:replyMessage]];
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
    [navControllor setActiveGameToRemove: [game gameID]];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void) updateCaptures {
    [whiteCapturesCountLabel setText:[NSString stringWithFormat:@"x %i",whiteCaptures]];
    [whiteCapturesCountLabel setNeedsDisplay];
    [blackCapturesCountLabel setText:[NSString stringWithFormat:@"x %i",blackCaptures]];
    [blackCapturesCountLabel setNeedsDisplay];
}







-(void) replayGame {
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


    
    //    NSString *tmpStr = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tbpgn.jsp?g=%@",[game gameID]];
//    NSString *tmpStr = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/game?gid=%@&command=load",[game gameID]];
    NSString *tmpStr = [NSString stringWithFormat:@"https://www.pente.org/gameServer/mobile/game.jsp?gid=%@",[game gameID]];
    if (development) {
        tmpStr = [NSString stringWithFormat:@"https://development.pente.org/gameServer/mobile/game.jsp?gid=%@",[game gameID]];
    }
//    tmpStr = [NSString stringWithFormat:@"https://development.pente.org/gameServer/mobile/game.jsp?gid=%@",[game gameID]];
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
    
    NSArray *splitDash = [htmlString componentsSeparatedByString:@"\n"];
    NSString *dashLine;
//    NSArray *splitLine;
    NSMutableArray *messages, *atMoves;
    BOOL cancelRequest = NO, undoRequest = NO;
    NSString *cancelMsg;
    
    int dashIDX = 0;
    NSString *myUsername = [[[NSUserDefaults standardUserDefaults] objectForKey:@"username"] lowercaseString], *p1Name, *p2Name;
    
    while (dashIDX < [splitDash count]) {
        dashLine = [splitDash objectAtIndex:dashIDX];
        @try {
            if ([[dashLine substringToIndex:4] isEqualToString:@"sid="]) {
                [game setSetID:[dashLine substringFromIndex:4]];
            } else if ([dashLine containsString:@"undo=requested"]) {
                undoRequest = YES;
            } else if ([[dashLine substringToIndex:9] isEqualToString:@"gameName="]) {
                [game setGameType:[dashLine substringFromIndex:9]];
            } else if ([[dashLine substringToIndex:6] isEqualToString:@"moves="]) {
                movesList  = [NSMutableArray arrayWithArray:[[dashLine substringFromIndex:6] componentsSeparatedByString:@","]];
                lastMove = (int) [movesList count];
            } else if ([[dashLine substringToIndex:9] isEqualToString:@"messages="]) {
                messages = [NSMutableArray arrayWithArray:[[dashLine substringFromIndex:9] componentsSeparatedByString:@","]];
            } else if ([[dashLine substringToIndex:8] isEqualToString:@"private="]) {
                [game setPrivateGame:[dashLine substringFromIndex:8]];
            } else if ([[dashLine substringToIndex:6] isEqualToString:@"rated="]) {
                [game setRatedNot:[dashLine substringFromIndex:6]];
            } else if ([[dashLine substringToIndex:7] isEqualToString:@"cancel="]) {
                NSArray *playerRating = [NSArray arrayWithArray:[[dashLine substringFromIndex:7] componentsSeparatedByString:@","]];
                if (![[playerRating objectAtIndex:0] isEqualToString:myUsername]) {
                    cancelRequest = YES;
                    if ([[playerRating objectAtIndex:1] isEqualToString:@""]) {
                        cancelMsg = @"";
                    } else {
                        cancelMsg = [NSString stringWithFormat:@"/n and writes: %@",[playerRating objectAtIndex:1]];
                    }
                }
            } else if ([[dashLine substringToIndex:8] isEqualToString:@"player1="]) {
                NSArray *playerRating = [NSArray arrayWithArray:[[dashLine substringFromIndex:8] componentsSeparatedByString:@","]];
                p1Name = [playerRating objectAtIndex:0];
                if (![p1Name isEqualToString:myUsername]) {
                    iAmP1 = NO;
                    [game setOpponentName: [playerRating objectAtIndex:0]];
                    [game setOpponentRating: [playerRating objectAtIndex:1]];
                }
            } else if ([[dashLine substringToIndex:8] isEqualToString:@"player2="]) {
                NSArray *playerRating = [NSArray arrayWithArray:[[dashLine substringFromIndex:8] componentsSeparatedByString:@","]];
                p2Name = [playerRating objectAtIndex:0];
                if (![p2Name isEqualToString:myUsername]) {
                    iAmP1 = YES;
                    [game setOpponentName: [playerRating objectAtIndex:0]];
                    [game setOpponentRating: [playerRating objectAtIndex:1]];
                }
            } else if ([[dashLine substringToIndex:12] isEqualToString:@"messageNums="]) {
                atMoves = [NSMutableArray arrayWithArray:[[dashLine substringFromIndex:12] componentsSeparatedByString:@","]];
            }
        } @catch (NSException *exception) {
            
        } @finally {
            dashIDX++;
        }
    }
    [self setTitle:[game gameType]];

    
    for (int i = 0; i < [messages count]; ++i) {
        NSString *tmpStrComma = [[messages objectAtIndex:i] stringByReplacingOccurrencesOfString:@"\\1" withString: @","];
        NSString *tmpStrSmiley = [tmpStrComma stringByReplacingOccurrencesOfString:@"<img border='0' src='http://[host]/gameServer/forums/images/emoticons/happy.gif' alt=''>" withString: @":)"];
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
        if (([[game myColor] isEqualToString:@"white"] && (([movesList count] % 2) == 1)) || ([[game myColor] isEqualToString:@"black"] && (([movesList count] % 2) == 0))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
        } else {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" %@: %@",[game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
        }
        if (([[game gameType] isEqualToString:@"Connect6"] && [[game myColor] isEqualToString:@"white"] && (([movesList count] % 4) == 1)) || ([[game gameType] isEqualToString:@"Connect6"] && [[game myColor] isEqualToString:@"black"] && (([movesList count] % 4) == 3))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
        } else if ([[game gameType] isEqualToString:@"Connect6"]) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" %@: %@",[game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[movesList count]]]];
        }
    } else {
        receivedMessage = @"";
        [replyMessageView setFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 88)];
    }
    
    [receivedMessageView setEditable:NO];
    [receivedMessageView setAlpha:0.90];
    [receivedMessageView setBackgroundColor:[UIColor colorWithRed:0.98f green:0.98f blue:0.98f alpha:0.95]];
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
    NSString *ratedPrivate = [NSString stringWithFormat:NSLocalizedString(@"This game is %@ and %@", nil), [game localizedRatedNot], [game privateGame]];
    
    if (![myUsername isEqualToString:p1Name] && ![myUsername isEqualToString:p2Name]) {
        playerStatsBaseString = [NSString stringWithFormat:@"<font size=\"3.5\"><a href=\"https://www.pente.org/gameServer/profile?viewName=%@\">%@</a> vs <a href=\"https://www.pente.org/gameServer/profile?viewName=%@\">%@</a>, %@ %@ <br> %@ %@ <br> %@ </font><hr>",p1Name, p1Name, p2Name, p2Name, locRating, [game opponentRating], remTime,[game localizedTimeString], ratedPrivate];
    } else {
        playerStatsBaseString = [NSString stringWithFormat:@"<font size=\"3.5\">Opponent: <a href=\"https://www.pente.org/gameServer/profile?viewName=%@\">%@</a>, %@ %@ <br> %@ %@ <br> %@</font><hr>",[game opponentName],[game opponentName],locRating,[game opponentRating],remTime,[game remainingTime],ratedPrivate];
    }

    
//    NSLog(@"kitty message %@", message);
    dPenteOpening = NO;
    whiteCaptures = 0;
    blackCaptures = 0;
    [self resetBoard];
    if ([[game gameType] isEqualToString:@"Connect6"]) {
        if (iAmP1) {
            activeGame = (([movesList count] % 4) == 3);
        } else {
            activeGame = (([movesList count] % 2) == 1);
        }
        [self replayConnect6Game: (int) [movesList count]];
    } else if (([[game gameType] isEqualToString:@"D-Pente"] || [[game gameType] isEqualToString:@"DK-Pente"]) &&
               ([htmlString containsString:@"dPenteState=2"])) {
        if (!iAmP1) {
            activeGame = (([movesList count] % 2) == 0);
        } else {
            activeGame = (([movesList count] % 2) == 1);
        }
    } else {
        if (iAmP1) {
            activeGame = (([movesList count] % 2) == 0);
        } else {
            activeGame = (([movesList count] % 2) == 1);
        }
    }
    if ([[game gameType] isEqualToString:@"Pente"] || [[game gameType] isEqualToString:@"Boat-Pente"] || [[game gameType] isEqualToString:@"Speed Pente"] || [[game gameType] isEqualToString:@"Speed Boat-Pente"]) {
        [self replayPenteGame: (int) [movesList count]];
    }
    if ([[game gameType] isEqualToString:@"Keryo-Pente"] || [[game gameType] isEqualToString:@"Speed Keryo-Pente"]) {
        [self replayKeryoPenteGame: (int) [movesList count]];
    }
    if ([[game gameType] isEqualToString:@"G-Pente"] || [[game gameType] isEqualToString:@"Speed G-Pente"]) {
        [self replayGPenteGame: (int) [movesList count]];
    }
    if ([[game gameType] isEqualToString:@"D-Pente"] || [[game gameType] isEqualToString:@"Speed D-Pente"] || [[game gameType] isEqualToString:@"DK-Pente"] || [[game gameType] isEqualToString:@"Speed DK-Pente"]) {
        if ([[game gameType] isEqualToString:@"DK-Pente"] || [[game gameType] isEqualToString:@"Speed DK-Pente"]) {
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
    if ([[game gameType] isEqualToString:@"Poof-Pente"] || [[game gameType] isEqualToString:@"Speed Poof-Pente"]) {
        [self replayPoofPenteGame: (int) [movesList count]];
    }
    
    [self updateCaptures];
    
    if ([[game gameType] isEqualToString:@"Gomoku"] || [[game gameType] isEqualToString:@"Speed Gomoku"]) {
        [self replayGomokuGame: (int) [movesList count]];
    }

    // Find out your color
    if ([[game myColor] isEqualToString:@"white"]) {
        [stone setStoneColor:[UIColor whiteColor]];
    } else {
        [stone setStoneColor:[UIColor blackColor]];
    }
    [zoomedStone setStoneColor:[stone stoneColor]];

//    int visibleMoves;
//    if ([[game gameType] isEqualToString:@"Connect6"] || [[game gameType] isEqualToString:@"Speed Connect6"]) {
//        visibleMoves = 15;
//        if (IS_IPHONE_6) {
//            if (showAds) {
//                visibleMoves = 16;
//            } else {
//                visibleMoves = 36;
//            }
//        } else if (IS_IPHONE_6P) {
//            if (showAds) {
//                visibleMoves = 28;
//            } else {
//                visibleMoves = 60;
//            }
//        }
//    } else {
//        visibleMoves = 11;
//        if (IS_IPHONE_6) {
//            if (showAds) {
//                visibleMoves = 14;
//            } else {
//                visibleMoves = 28;
//            }
//        } else if (IS_IPHONE_6P) {
//            if (showAds) {
//                visibleMoves = 24;
//            } else {
//                visibleMoves = 50;
//            }
//        }
//    }
//    if (lastMove > visibleMoves) {
//        moveStatsString = [[NSMutableString alloc] initWithString:@"... "];
//    } else {
//        moveStatsString = [[NSMutableString alloc] init];
//    }
    moveStatsString = [[NSMutableString alloc] init];
    for (int i = 0; i < lastMove; ++i) {
//        if (lastMove - i > visibleMoves) {
//            continue;
//        }
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        if (i == 0) {
            [moveStatsString appendString: @"<b>1.</b> "];
        } else if ([[game gameType] isEqualToString:@"Connect6"] || [[game gameType] isEqualToString:@"Speed Connect6"]) {
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
        [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % 19], 19 - (rowCol / 19)]];
    }
    [playerStats loadHTMLString: [playerStatsBaseString stringByAppendingString:moveStatsString] baseURL:nil];

    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];

    if (cancelRequest) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"%@", [game opponentName]] message:[NSString stringWithFormat:NSLocalizedString(@"is requesting that this set be cancelled. %@",nil), cancelMsg] delegate:self cancelButtonTitle:NSLocalizedString(@"Decide later",nil) otherButtonTitles:NSLocalizedString(@"Accept",nil), NSLocalizedString(@"Reject",nil), nil];
        [alert setTag: 0];
        
        [alert show];
        return;
    }

    if (![receivedMessage isEqualToString:@""]) {
        [self notifyNewMessage];
    }

    if ([[game opponentName] isEqualToString:@"computer"]) {
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
                if ([[game myColor] isEqualToString:@"black"]) {
                    iWin = NO;
                }
            } else {
                if ([[game myColor] isEqualToString:@"white"]) {
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
    if (([myUsername isEqualToString:p1Name] || [myUsername isEqualToString:p2Name]) && !activeGame
        && [htmlString containsString:@"state=active"] && ![htmlString containsString:@"dPenteState=2"] && [movesList count] > 1) {
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
    } else if (([myUsername isEqualToString:p1Name] || [myUsername isEqualToString:p2Name]) && activeGame && [htmlString containsString:@"state=active"]) {
        [submitButton removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [submitButton addTarget:self action:@selector(submitMove:) forControlEvents:UIControlEventTouchUpInside];
        [submitButton setTitle: NSLocalizedString(@"submit",nil) forState:UIControlStateDisabled];
        [submitButton setEnabled:NO];
        [submitButton setAlpha:0.85];
    }
    if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"username"] isEqualToString:@"rainwolf"]) {
        if ([[[@"samywamy-" stringByAppendingString:[[NSUserDefaults standardUserDefaults] objectForKey:@"password"]] SHA256] isEqualToString:@"1b7017087c9d8ff0d2b3ec1cb930273529d7efb52ce859e2dd1a824194ab7806"]) {
            [lockButton setImage:[UIImage imageNamed:@"database.png"] forState:UIControlStateNormal];
            [lockButton removeTarget:self action:@selector(toggleBoardLock:) forControlEvents:UIControlEventTouchUpInside];
            [lockButton addTarget:self action:@selector(toDB) forControlEvents:UIControlEventTouchUpInside];
            [lockButton setAlpha:1.0f];
            [lockButton setEnabled:YES];
            [lockButton setNeedsDisplay];
        }
    }
}

-(void) requestUndo: (UIButton*) sender {
    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
    if ([navControllor.player subscriber]) {
        NSError *error = nil;
        NSURLResponse *response;
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        
        NSString *post = [NSString stringWithFormat:@"gid=%@&command=requestUndo&mobile=", [game gameID]];
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
//            [navControllor setDidMove: YES];
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
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
        
        [self presentViewController:subscribersOnlyController animated:NO completion:nil];
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
                                                             
                                                             NSString *post = [NSString stringWithFormat:@"gid=%@&command=acceptUndo&mobile=", [game gameID]];
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
                                                             PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                                                             NSError *error = nil;
                                                             NSURLResponse *response;
                                                             NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                                                             
                                                             NSString *post = [NSString stringWithFormat:@"gid=%@&command=declineUndo&mobile=", [game gameID]];
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
    [[NSUserDefaults standardUserDefaults] setObject:[game gameType] forKey:@"DBGame"];
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle:nil];
    DatabaseViewController * vc = (DatabaseViewController *)[sb instantiateViewControllerWithIdentifier:@"databaseViewController"];
    [vc setMovesList: [[movesList subarrayWithRange:NSMakeRange(0, lastMove)] mutableCopy]];
    [vc setGame:[game gameType]];
    [vc setShowAds: !navController.player.subscriber];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 0) {
        NSString *reply;
        if (buttonIndex == 0) {
        }
        else if (buttonIndex == 1) {
            reply = @"Yes";
        } else if (buttonIndex == 2) {
            reply = @"No";
        }

        PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;

        if (buttonIndex > 0) {
            NSError *error = nil;
            NSURLResponse *response;
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

            NSString *post = [NSString stringWithFormat:@"sid=%@&gid=%@&command=%@&mobile=", [game setID] ,[game gameID], reply];
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
            [navControllor setDidMove: YES];
        }
        
        [self.navigationController popToRootViewControllerAnimated:YES];

    } else if (alertView.tag == 1) {
        if (buttonIndex == 0) {
            return;
        }
        else if ((buttonIndex == 1) && (activeGame)) {
            NSString *post = [NSString stringWithFormat:@"gid=%@&command=resign&mobile=",[game gameID]];
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

        } else if (((buttonIndex == 2) && activeGame) || (!activeGame && (buttonIndex == 1))) {
//            NSString *tmpStr = [NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/game?gid=%@&command=load",[game gameID]];
//            NSURL *url = [NSURL URLWithString: tmpStr];
            NSError *error;
//            NSString *htmlString = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:&error];
//            NSRange movesRange = NSMakeRange(0,[htmlString length]);
//            movesRange = [htmlString rangeOfString: @"     sid=\"" options:0 range:movesRange];
//            movesRange.length = [htmlString length] - movesRange.location - 10;
//            movesRange.location = movesRange.location + 10;
//            NSRange movesRangeEnd = [[htmlString substringWithRange:movesRange] rangeOfString:@"\""];
//            movesRange.length = movesRangeEnd.location;
//            [game setSetID:[htmlString substringWithRange:movesRange]];
            NSRange movesRange;
            
            NSString *post = [NSString stringWithFormat:@"sid=%@&command=request&mobile=",[game setID]];
            NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
            NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
            
            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
            
            //        [request setValue:[NSString stringWithFormat:@"https://www.pente.org/gameServer/tb/cancel?command=confirm&sid=%@&gid=%@&message=", [[player.nonActiveGames objectAtIndex:indexPath.row] setID], [[player.nonActiveGames objectAtIndex:indexPath.row] gameID]]  forHTTPHeaderField:@"referer"];
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
            //        NSError *error;
            //        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            movesRange = NSMakeRange(0,[dashboardString length]);
            movesRange = [dashboardString rangeOfString: @"Error: Cancel request already exists." options:0 range:movesRange];
            if (movesRange.location != NSNotFound) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:NSLocalizedString(@"A cancel request already exists.",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
                [alert show];
            } else {
                PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                [navControllor setDidMove: YES];
            }
        }
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}


-(void) replayGame: (int) untilMove {
    [board setLastConnect6Move:-1];
    [zoomedBoard setLastConnect6Move: -1];
    [board setLastMove: -1];
    [zoomedBoard setLastMove: -1];
    whiteCaptures = 0;
    blackCaptures = 0;
    [self resetBoard];
    if ([[game gameType] isEqualToString:@"Pente"] || [[game gameType] isEqualToString:@"Boat-Pente"] || [[game gameType] isEqualToString:@"Speed Pente"] || [[game gameType] isEqualToString:@"Speed Boat-Pente"]) {
        [self replayPenteGame: untilMove];
    }
    if ([[game gameType] isEqualToString:@"Keryo-Pente"] || [[game gameType] isEqualToString:@"Speed Keryo-Pente"]) {
        [self replayKeryoPenteGame: untilMove];
    }
    if ([[game gameType] isEqualToString:@"G-Pente"] || [[game gameType] isEqualToString:@"Speed G-Pente"]) {
        [self replayGPenteGame: untilMove];
    }
    if ([[game gameType] isEqualToString:@"D-Pente"] || [[game gameType] isEqualToString:@"Speed D-Pente"]) {
        [self replayDPenteGame: untilMove];
    }
    if ([[game gameType] isEqualToString:@"DK-Pente"] || [[game gameType] isEqualToString:@"Speed DK-Pente"]) {
        [self replayDKPenteGame: untilMove];
    }
    if ([[game gameType] isEqualToString:@"Poof-Pente"] || [[game gameType] isEqualToString:@"Speed Poof-Pente"]) {
        [self replayPoofPenteGame: untilMove];
    }
    
    [self updateCaptures];
    
    if ([[game gameType] isEqualToString:@"Connect6"] || [[game gameType] isEqualToString:@"Speed Connect6"]) {
        [self replayConnect6Game: untilMove];
    }
    if ([[game gameType] isEqualToString:@"Gomoku"] || [[game gameType] isEqualToString:@"Speed Gomoku"]) {
        [self replayGomokuGame: untilMove];
    }
    
    
    isLastMove = (untilMove == [movesList count]);
    [messageButtonImageView stopAnimating];
    if ([messagesHistory objectForKey:[NSString stringWithFormat:@"%i",untilMove]]) {
        [self notifyNewMessage];
        if (([[game myColor] isEqualToString:@"white"] && ((untilMove % 2) == 1)) || ([[game myColor] isEqualToString:@"black"] && ((untilMove % 2) == 0))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%i", untilMove]]];
        } else {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" %@: %@",[game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%i", untilMove]]];
        }
        if (([[game gameType] isEqualToString:@"Connect6"] && [[game myColor] isEqualToString:@"white"] && ((untilMove % 4) == 1)) || ([[game gameType] isEqualToString:@"Connect6"] && [[game myColor] isEqualToString:@"black"] && ((untilMove % 4) == 3))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" me: %@", [messagesHistory objectForKey:[NSString stringWithFormat:@"%i", untilMove]]];
        } else if ([[game gameType] isEqualToString:@"Connect6"]) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.35f]];
            receivedMessage = [NSString stringWithFormat:@" %@: %@",[game opponentName], [messagesHistory objectForKey:[NSString stringWithFormat:@"%i", untilMove]]];
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
    
//    int visibleMoves;
//    if ([[game gameType] isEqualToString:@"Connect6"]) {
//        visibleMoves = 15;
//        if (IS_IPHONE_6) {
//            if (showAds) {
//                visibleMoves = 16;
//            } else {
//                visibleMoves = 36;
//            }
//        } else if (IS_IPHONE_6P) {
//            if (showAds) {
//                visibleMoves = 28;
//            } else {
//                visibleMoves = 60;
//            }
//        }
//    } else {
//        visibleMoves = 11;
//        if (IS_IPHONE_6) {
//            if (showAds) {
//                visibleMoves = 14;
//            } else {
//                visibleMoves = 28;
//            }
//        } else if (IS_IPHONE_6P) {
//            if (showAds) {
//                visibleMoves = 24;
//            } else {
//                visibleMoves = 50;
//            }
//        }
//    }
//    if (lastMove > visibleMoves) {
//        moveStatsString = [[NSMutableString alloc] initWithString:@"... "];
//    } else {
//        moveStatsString = [[NSMutableString alloc] init];
//    }
    moveStatsString = [[NSMutableString alloc] init];
    for (int i = 0; i < lastMove; ++i) {
//        if (lastMove - i > visibleMoves) {
//            continue;
//        }
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        if (i == 0) {
            [moveStatsString appendString: @"<b>1.</b> "];
        } else if ([[game gameType] isEqualToString:@"Connect6"]) {
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
        [moveStatsString appendString:[NSString stringWithFormat:@"%c%d", coordinateLetters[rowCol % 19], 19 - (rowCol / 19)]];
    }
    [playerStats loadHTMLString: [playerStatsBaseString stringByAppendingString:moveStatsString] baseURL:nil];
    
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
    if ([[game ratedNot] rangeOfString:@"Not Rated"].location == NSNotFound && ([movesList count] == 2)) {
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
    if ([[game gameType] isEqualToString:@"Boat-Pente"]) {
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
    if ([[game ratedNot] rangeOfString:@"Not Rated"].location == NSNotFound && ([movesList count] == 2)) {
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
    
    //NSLog(@" kitty moves %i",abstractBoard[0][0]);
    [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
//    [board setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
//    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
    [whiteStoneCaptures setHidden:YES];
    [whiteCapturesCountLabel setHidden:YES];
    [blackStoneCaptures setHidden:YES];
    [blackCapturesCountLabel setHidden:YES];
//    if ([movesList count] > 1) {
//        [board setLastConnect6Move:[self parseMove:[movesList objectAtIndex:[movesList count] - 2]]];
//        [zoomedBoard setLastConnect6Move:[self parseMove:[movesList objectAtIndex:[movesList count] - 2]]];
//    }
    if (untilMove > 1) {
//        NSLog(@"kitty %i %i", [self parseMove:[movesList objectAtIndex:untilMove - 2]], [self parseMove:[movesList objectAtIndex:untilMove - 1]]);
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
    if ([[game ratedNot] rangeOfString:@"Not Rated"].location == NSNotFound && ([movesList count] == 2)) {
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
    [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
//    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.89 green:0.537 blue:0.973 alpha:1]];
    [board setAbstractBoard: abstractBoard];
    [board setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard: abstractBoard];
        [zoomedBoard setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
    }
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
    if (isLastMove) {
        if (activeGame) {
            if (![receivedMessage isEqualToString:@""]) {
                [messagePopover showAtPoint:CGPointMake(messageButton.center.x+messageButton.bounds.size.width/2, 0) inView:self.view  withViewArray:[NSArray arrayWithObjects:receivedMessageView, replyMessageView,nil]];
            } else {
                [replyMessageView setFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 88)];
                [messagePopover showAtPoint:CGPointMake(messageButton.center.x+messageButton.bounds.size.width/2, 0) inView:self.view withContentView:replyMessageView];
            }
            [self.replyMessageView becomeFirstResponder];
        } else if (![receivedMessage isEqualToString:@""]) {
            [messagePopover showAtPoint:CGPointMake(messageButton.center.x+messageButton.bounds.size.width/2, 0) inView:self.view withContentView:receivedMessageView];
        }
    } else if (![receivedMessage isEqualToString:@""]) {
            [messagePopover showAtPoint:CGPointMake(messageButton.center.x+messageButton.bounds.size.width/2, 0) inView:self.view withContentView:receivedMessageView];
    }
}

- (void) cancelResign {
    UIAlertView *alert;
    if (activeGame) {
        alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Options",nil) message:nil delegate:self cancelButtonTitle:NSLocalizedString(@"Dismiss",nil) otherButtonTitles:NSLocalizedString(@"Resign",nil), NSLocalizedString(@"Cancel Set",nil), nil];
        [alert setTag: 1];
        [alert show];
    }
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

-(BOOL) webView:(UIWebView *)inWeb shouldStartLoadWithRequest:(NSURLRequest *)inRequest navigationType:(UIWebViewNavigationType)inType {
    if ( inType == UIWebViewNavigationTypeLinkClicked ) {
        NSString *urlString = [[inRequest URL] absoluteString];
        PenteWebViewController *webViewController = [[PenteWebViewController alloc] initWithAddress: urlString];
//        [webViewController setDelegate:self];
        [self.navigationController pushViewController:webViewController animated:YES];
        return NO;
    }
    
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    int contentSize = [[webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.body.scrollHeight;"]] intValue],
    webViewSize = (int) webView.scrollView.contentSize.height;
    webViewSize = (int) webView.frame.size.height;

//    NSLog(@"%i %i", contentSize, webViewSize);
    if (contentSize > webViewSize && [moveStatsString length]>10) {
        [moveStatsString deleteCharactersInRange:NSMakeRange(0, [moveStatsString rangeOfString:@".</b> "].location+6)];
//        NSLog(moveStatsString);
        [playerStats loadHTMLString: [playerStatsBaseString stringByAppendingString:moveStatsString] baseURL:nil];
    }
}



@end
