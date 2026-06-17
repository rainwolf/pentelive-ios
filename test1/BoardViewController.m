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
#import "DatabaseViewController.h"
#import "PenteGame.h"
#import "PopoverView.h"
#import "TSMessage.h"
#import "penteLive-Swift.h"
#import <NSHash/NSString+NSHash.h>
#import <QuartzCore/QuartzCore.h>

#define usernameKey @"username"
#define passwordKey @"password"

// GADBannerView *bannerView_;

@interface BoardViewController ()
// SELECTION: the chosen pair [black move5, white move6]. Declared here (not the
// .h) so the new TB-select state stays local to the implementation.
@property (nonatomic, strong) NSMutableArray<NSNumber *> *renjuSelectedPoints;
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
@synthesize passButton;
@synthesize dPenteChoiceLabel;
//@synthesize gamesTable;
@synthesize whiteCapturesCountLabel;
@synthesize whiteStoneCaptures;
@synthesize blackCapturesCountLabel;
@synthesize blackStoneCaptures;
@synthesize spinner;
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
@synthesize moveStatsString;
@synthesize playerStatsBaseString;

int abstractGoBoard[19][19];
int finalMove = -1, connect6Move1 = -1, connect6Move2 = -1, dPenteMove1 = -1,
    dPenteMove2 = -1, dPenteMove3 = -1, dPenteMove4 = -1, whiteCaptures,
    blackCaptures, lastMove, swap2Move1 = -1, swap2Move2 = -1, swap2Move3 = -1;
BOOL dPenteOpening = NO;
BOOL dPenteChoice = NO;
BOOL swap2Opening = NO;
BOOL swap2Choice = NO;
BOOL swap2Pass = NO;
BOOL swap2WillPass = NO;
BOOL isSwap2 = NO;
BOOL swap2PlayP1 = NO;
BOOL poofed = NO;
BOOL canHide = NO;
BOOL canUnHide = NO;
char coordinateLetters[19] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
                              'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T'};
NSString *hideString, *cancelMsg;
LegacyPenteGame *penteGame;

NSMutableDictionary<NSNumber *, NSMutableDictionary<NSNumber *, NSNumber *> *>
    *goStoneGroupIDsByPlayer;
NSMutableDictionary<
    NSNumber *, NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *>
    *goStoneGroupsByPlayerAndID;
int koMove = -1, gridSize = 19;
NSMutableArray<NSNumber *> *deadWhiteStones, *deadBlackStones, *whiteTerritory,
    *blackTerritory;
BOOL goMarkStones = NO, goEvaluateDeadStones = NO, go = NO, isGoGame = NO;
NSMutableDictionary<NSNumber *, NSNumber *> *goStoneGroupIDs;
NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *goStoneGroups;

- (void)viewDidLoad {
    [super viewDidLoad];

    penteGame = [[LegacyPenteGame alloc] init];
    engine = [[SwiftPenteGame alloc] initWithVariant:PenteVariantPente];
    lastReplayWinner = 0;

    finalMove = -1;
    connect6Move1 = -1;
    connect6Move2 = -1;
    dPenteMove1 = -1;
    dPenteMove2 = -1;
    dPenteMove3 = -1;
    dPenteMove4 = -1;
    whiteCaptures;
    blackCaptures;
    lastMove;
    swap2Move1 = -1;
    swap2Move2 = -1;
    swap2Move3 = -1;
    dPenteOpening = NO;
    dPenteChoice = NO;
    swap2Opening = NO;
    swap2Choice = NO;
    swap2Pass = NO;
    swap2WillPass = NO;
    isSwap2 = NO;
    swap2PlayP1 = NO;
    poofed = NO;
    canHide = NO;
    canUnHide = NO;

    // Do any additional setup after loading the view, typically from a nib.
    cancelMsg = @"";
    hideString = @"";
    messageButtonImageView = [[UIImageView alloc]
        initWithImage:[UIImage imageNamed:@"messageBubble0.png"]];
    NSArray *images = [NSArray
        arrayWithObjects:[UIImage imageNamed:@"messageBubble0.png"],
                         [UIImage imageNamed:@"messageBubble1.png"], nil];
    messageButtonImageView.animationImages = images;
    [messageButton addSubview:self.messageButtonImageView];

    messageButton.layer.cornerRadius = 5;
    messageButton.layer.masksToBounds = YES;
    [messageButtonImageView
        setCenter:CGPointMake(messageButton.bounds.size.width / 2,
                              messageButton.bounds.size.height / 2)];
    [messageButton addTarget:self
                      action:@selector(messageTap:)
            forControlEvents:UIControlEventTouchUpInside];

    [board setLastConnect6Move:-1];
    [zoomedBoard setLastConnect6Move:-1];
    [board setLastMove:-1];
    [zoomedBoard setLastMove:-1];

    //    [self.navigationController.navigationBar setTranslucent:NO];
    //    [self.navigationController setEdgesForExtendedLayout:UIRectEdgeNone];
    [board setFrame:CGRectMake(0, 0, self.view.bounds.size.width,
                               self.view.bounds.size.width)];
    [zoomedBoard setFrame:CGRectMake(0, 0, 2 * self.view.bounds.size.width,
                                     2 * self.view.bounds.size.width)];
    CGRect rect;
    rect = submitButton.frame;
    //    rect.origin.y = board.frame.size.height + 2 +
    //    submitButton.frame.size.height;
    rect.origin.y = board.frame.size.height + 2;
    rect.origin.x =
        (board.frame.size.width - submitButton.frame.size.width) / 2;
    submitButton.frame = rect;

    lockButton = [[UIButton alloc] initWithFrame:rect];
    rect.size.width = rect.size.height;
    rect.origin.x = board.frame.size.width - rect.size.width - 10;
    [lockButton setTitle:nil forState:UIControlStateNormal];
    [lockButton setFrame:rect];
    [lockButton addTarget:self
                   action:@selector(toggleBoardLock:)
         forControlEvents:UIControlEventTouchUpInside];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"notBack2Dash"]) {
        [lockButton setImage:[UIImage imageNamed:@"lock.png"]
                    forState:UIControlStateNormal];
    } else {
        [lockButton setImage:[UIImage imageNamed:@"unlock.png"]
                    forState:UIControlStateNormal];
    }
    [self.view addSubview:lockButton];

    rect = whiteCapturesCountLabel.frame;
    rect.origin.y = board.frame.size.height + 2;
    whiteCapturesCountLabel.frame = rect;
    rect = whiteStoneCaptures.frame;
    rect.origin.y = board.frame.size.height + 2 + 2;
    whiteStoneCaptures.frame = rect;
    rect = blackCapturesCountLabel.frame;
    rect.origin.y = whiteCapturesCountLabel.frame.size.height +
                    whiteCapturesCountLabel.frame.origin.y + 1;
    blackCapturesCountLabel.frame = rect;
    rect = blackStoneCaptures.frame;
    rect.origin.y = whiteCapturesCountLabel.frame.size.height +
                    whiteCapturesCountLabel.frame.origin.y + 1 + 2;
    blackStoneCaptures.frame = rect;

    rect = player1Button.frame;
    rect.origin.y = board.frame.size.height + 2;
    float x = self.view.bounds.size.width / 4;
    rect.size.width = x;
    rect.origin.x = x;
    player1Button.frame = rect;
    [player1Button setTitle:NSLocalizedString(@"white", nil)
                   forState:UIControlStateNormal];
    rect = player2Button.frame;
    rect.origin.y = board.frame.size.height + 2;
    rect.origin.x = 2 * x;
    rect.size.width = x;
    //    rect.origin.x = (board.frame.size.width -
    //    submitButton.frame.size.width)/2;
    player2Button.frame = rect;
    [player2Button setTitle:NSLocalizedString(@"black", nil)
                   forState:UIControlStateNormal];
    rect = passButton.frame;
    rect.origin.x = 3 * x;
    rect.origin.y = board.frame.size.height + 2;
    rect.size.width = x;
    passButton.frame = rect;
    rect = dPenteChoiceLabel.frame;
    rect.origin.y = (player1Button.frame.origin.y + 3);
    dPenteChoiceLabel.frame = rect;

    playerStats = [[WKWebView alloc]
        initWithFrame:CGRectMake(2, submitButton.frame.origin.y + 3,
                                 self.view.bounds.size.width - 4,
                                 submitButton.frame.origin.y - 3)];
    [playerStats setNavigationDelegate:self];
    [playerStats setAlpha:0.90];
    [playerStats setBackgroundColor:[UIColor colorWithRed:0.98f
                                                    green:0.98f
                                                     blue:0.98f
                                                    alpha:0.95]];
    playerStats.clipsToBounds = YES;
    playerStats.layer.cornerRadius = 1.0f;
    playerStats.layer.borderWidth = 1.0f;
    playerStats.layer.borderColor = [[UIColor grayColor] CGColor];
    //    receivedMessageView.contentInset = UIEdgeInsetsMake(7.0,7.0,0,0.0);
    [playerStats setUserInteractionEnabled:YES];
    [playerStats.scrollView setScrollEnabled:NO];
    //    playerStats.contentInset = UIEdgeInsetsMake(-5.0,0.0,0,0.0);
    [self.view addSubview:playerStats];

    [submitButton setEnabled:NO];
    [submitButton setTitle:NSLocalizedString(@"submit", nil)
                  forState:UIControlStateDisabled];
    [submitButton setAlpha:0.5];
    [board setAbstractBoard:abstractBoard];
    [zoomedBoard setAbstractBoard:abstractBoard];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (@available(iOS 26.0, *)) {
        self.navigationController.interactiveContentPopGestureRecognizer
            .enabled = NO;
    }

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

    UIBarButtonItem *negativeSpacer = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                             target:nil
                             action:nil];
    negativeSpacer.width = -16.0; // it was -6 in iOS 6
    UIBarButtonItem *positiveSpacer = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace
                             target:nil
                             action:nil];
    positiveSpacer.width = 16.0; // it was -6 in iOS 6
    UIBarButtonItem *messsageBarButton = self.navigationItem.rightBarButtonItem;
    if (isGoGame) {
        UIBarButtonItem *goItem = [[UIBarButtonItem alloc]
            initWithImage:[UIImage imageNamed:@"database"]
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(showScore)];
        UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc]
            initWithImage:[UIImage imageNamed:@"cancel.png"]
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(cancelResignHide)];
        [self.navigationItem
            setRightBarButtonItems:[NSArray
                                       arrayWithObjects:messsageBarButton,
                                                        negativeSpacer, goItem,
                                                        negativeSpacer,
                                                        cancelItem,
                                                        positiveSpacer, nil]
                          animated:YES];
    } else {
        [self.navigationItem
            setRightBarButtonItems:
                [NSArray
                    arrayWithObjects:
                        messsageBarButton, negativeSpacer,
                        [[UIBarButtonItem alloc]
                            initWithImage:[UIImage imageNamed:@"cancel.png"]
                                    style:UIBarButtonItemStylePlain
                                   target:self
                                   action:@selector(cancelResignHide)],
                        positiveSpacer, nil]
                          animated:YES];
    }
    dPenteChoiceLabel.text = NSLocalizedString(@"Play as", nil);

    CGFloat bottomOffset = 0;

    if ([[UIDevice currentDevice] userInterfaceIdiom] ==
        UIUserInterfaceIdiomPhone) {
        if ((int)[[UIScreen mainScreen] nativeBounds].size.height == 2436) {
            bottomOffset = 34;
        }
    }
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat newOriginY =
        screenHeight -
        self.navigationController.navigationBar.frame.size.height -
        [UIApplication sharedApplication].statusBarFrame.size.height;
    playerStats.frame = CGRectMake(
        2, submitButton.frame.origin.y + 3 + submitButton.frame.size.height,
        self.view.bounds.size.width - 4,
        newOriginY - submitButton.frame.origin.y - 5 -
            submitButton.frame.size.height - bottomOffset);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    //    [bannerView removeFromSuperview];
    PenteNavigationViewController *navController =
        (PenteNavigationViewController *)self.navigationController;
    [navController setChallengeCancelled:YES];

    if (@available(iOS 26.0, *)) {
        navController.interactiveContentPopGestureRecognizer.enabled = YES;
    }

    [super viewWillDisappear:animated];
}

- (void)viewDidUnload {
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
    [self setMovesList:nil];
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
    UIInterfaceOrientation interfaceOrientation =
        [[UIApplication sharedApplication] statusBarOrientation];
    return (
        (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown) &&
        (interfaceOrientation != UIInterfaceOrientationLandscapeLeft) &&
        (interfaceOrientation != UIInterfaceOrientationLandscapeRight));
}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
    //    return UIInterfaceOrientationLandscapeLeft |
    //    UIInterfaceOrientationLandscapeRight | UIInterfaceOrientationPortrait;
}

//-(void)createAdBannerView {
//    bannerView_ = [[GADBannerView alloc]
//    initWithFrame:CGRectMake(0.0,self.view.frame.size.height -
//    GAD_SIZE_320x50.height -44, GAD_SIZE_320x50.width,
//    GAD_SIZE_320x50.height)]; bannerView.adUnitID = @"XXXXXXXXXXXX";
//}

- (IBAction)dPentePlayer1:(id)sender {
    if (self.renjuPhase != nil) {
        if ([self.renjuPhase isEqualToString:@"SWAP"]) {
            self.renjuTakeOver = YES;
            self.renjuMove4Decline = NO;
            [self submitRenjuDecision];
        } else if ([self.renjuPhase isEqualToString:@"BRANCH"]) {
            // Post-take-over Branch A: reveal the 9x9 box, place move 5, then
            // submit it as a single `move` (no standalone branch post).
            self.renjuMove4BranchA = YES;
            self.renjuMove4BranchB = NO;
            [player1Button setHidden:YES];
            [player2Button setHidden:YES];
            [passButton setHidden:YES];
            [dPenteChoiceLabel setHidden:YES];
            [submitButton setAlpha:1];
            [submitButton setHidden:NO];
            activeGame = YES;
            [self applyRenjuOpeningMaskIfNeeded]; // 9x9 box
        }
        return;
    }
    if ([game.gameType hasPrefix:@"Swap2-"]) {
        dPenteChoice = NO;
        finalMove = 0;
        swap2PlayP1 = YES;
        spinner.center = stone.center;
        [spinner setHidden:NO];
        [spinner startAnimating];
        [NSThread detachNewThreadSelector:@selector(submitMoveToServer)
                                 toTarget:self
                               withObject:nil];
    } else {
        [player1Button setHidden:YES];
        [player2Button setHidden:YES];
        [dPenteChoiceLabel setHidden:YES];
        [submitButton setAlpha:1];
        [submitButton setHidden:NO];
        [stone setStoneColor:WHITE];
        [stone setNeedsDisplay];
        [zoomedStone setStoneColor:WHITE];
        [zoomedStone setNeedsDisplay];
        activeGame = YES;
    }
    [passButton setHidden:YES];
}

- (IBAction)dPentePlayer2:(id)sender {
    if (self.renjuPhase != nil) {
        if ([self.renjuPhase isEqualToString:@"SWAP"]) {
            if ([self isRenjuMove4Window]) {
                // "No swap" -> Branch A: place your move 5 in the 9x9, submitted with
                // the decline together via the move4 fold.
                self.renjuTakeOver = NO;
                self.renjuMove4Decline = NO;
                self.renjuMove4BranchA = YES;
                self.renjuMove4BranchB = NO;
                [player1Button setHidden:YES];
                [player2Button setHidden:YES];
                [passButton setHidden:YES];
                [dPenteChoiceLabel setHidden:YES];
                [submitButton setAlpha:1];
                [submitButton setHidden:NO];
                activeGame = YES;
                [self applyRenjuOpeningMaskIfNeeded]; // 9x9 box
            } else {
                // decline + place: dismiss buttons, show the central box, let
                // boardTap place, then confirm via the normal submit path.
                self.renjuTakeOver = NO;
                self.renjuMove4Decline = NO;
                [player1Button setHidden:YES];
                [player2Button setHidden:YES];
                [dPenteChoiceLabel setHidden:YES];
                [submitButton setAlpha:1];
                [submitButton setHidden:NO];
                activeGame = YES;
                [self updateRenjuBoxOverlay];
                [self applyRenjuOpeningMaskIfNeeded];
            }
        } else if ([self.renjuPhase isEqualToString:@"BRANCH"]) {
            // Post-take-over Branch B: collect ten 5th-move offers (auto-submits on
            // the 10th pick) as a single `move` (no standalone branch post).
            self.renjuMove4BranchA = NO;
            self.renjuMove4BranchB = YES;
            self.renjuPickedOffers = [NSMutableArray array];
            [player1Button setHidden:YES];
            [player2Button setHidden:YES];
            [passButton setHidden:YES];
            [dPenteChoiceLabel setHidden:YES];
            [submitButton setHidden:YES];
            [self renderRenjuCandidates:@[]];
            [self showRenjuOfferCounter];
            activeGame = YES;
        }
        return;
    }
    if ([game.gameType hasPrefix:@"Swap2-"]) {
        [player1Button setHidden:YES];
        [player2Button setHidden:YES];
        [dPenteChoiceLabel setHidden:YES];
        [submitButton setAlpha:1];
        [submitButton setHidden:NO];
        [stone setStoneColor:BLACK];
        [stone setNeedsDisplay];
        [zoomedStone setStoneColor:BLACK];
        [zoomedStone setNeedsDisplay];
        activeGame = YES;
        swap2PlayP1 = NO;
    } else {
        dPenteChoice = NO;
        finalMove = 0;
        spinner.center = stone.center;
        [spinner setHidden:NO];
        [spinner startAnimating];
        [NSThread detachNewThreadSelector:@selector(submitMoveToServer)
                                 toTarget:self
                               withObject:nil];
    }
    [passButton setHidden:YES];
}

- (IBAction)swap2Pass:(id)sender {
    if (self.renjuPhase != nil) {
        // Move-4 "Place 10" -> Branch B: offer ten 5th-move candidates, submitted with
        // the decline together via the move4 fold (auto-sends on the 10th pick).
        self.renjuTakeOver = NO;
        self.renjuMove4Decline = NO;
        self.renjuMove4BranchA = NO;
        self.renjuMove4BranchB = YES;
        self.renjuPickedOffers = [NSMutableArray array];
        [player1Button setHidden:YES];
        [player2Button setHidden:YES];
        [passButton setHidden:YES];
        [dPenteChoiceLabel setHidden:YES];
        [submitButton setHidden:YES];
        [self renderRenjuCandidates:@[]];
        [self showRenjuOfferCounter];
        activeGame = YES;
        return;
    }
    [passButton setHidden:YES];
    swap2WillPass = YES;
    [player1Button setHidden:YES];
    [player2Button setHidden:YES];
    [dPenteChoiceLabel setHidden:YES];
    [submitButton setAlpha:1];
    [submitButton setHidden:NO];
    [stone setStoneColor:BLACK];
    [stone setNeedsDisplay];
    [zoomedStone setStoneColor:BLACK];
    [zoomedStone setNeedsDisplay];
    activeGame = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [TSMessage
            showNotificationInViewController:self.navigationController
                                       title:NSLocalizedString(@"Swap2 PASS",
                                                               nil)
                                    subtitle:
                                        NSLocalizedString(
                                            @"Place 2 stones and let player 1 "
                                            @"decide",
                                            nil)
                                       image:nil
                                        type:TSMessageNotificationTypeMessage
                                    duration:
                                        TSMessageNotificationDurationAutomatic
                                    callback:^{
                                        [TSMessage dismissActiveNotification];
                                    }
                                 buttonTitle:nil
                              buttonCallback:nil
                                  atPosition:TSMessageNotificationPositionBottom
                        canBeDismissedByUser:YES];
    });
}

- (IBAction)goForwardOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    if (swap2Choice || dPenteChoice || goMarkStones) {
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
            [zoomedBoard setAbstractBoard:abstractBoard];
            [zoomedBoard setNeedsDisplay];
        }
    }
}

- (IBAction)goBackOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    if (swap2Choice || dPenteChoice || goMarkStones) {
        return;
    }
    [board setBlackTerritory:nil];
    [board setWhiteTerritory:nil];
    //    NSLog(@"SwipeLeft %i", lastMove);
    finalMove = -1;
    if (!submitButton.imageView.image && activeGame) {
        [submitButton setEnabled:NO];
        [submitButton setTitle:NSLocalizedString(@"submit", nil)
                      forState:UIControlStateDisabled];
        [submitButton setAlpha:0.5];
    }
    [stone setHidden:YES];
    if (connect6Move1 != -1) {
        connect6Move1 = -1;
        connect6Move2 = -1;
        [self replayGame:lastMove];
        [board setAbstractBoard:abstractBoard];
        [zoomedBoard setAbstractBoard:abstractBoard];
        [board setNeedsDisplay];
        [zoomedBoard setNeedsDisplay];
    } else if (dPenteOpening) {
        dPenteMove4 = -1;
        if (dPenteMove3 != -1) {
            abstractBoard[dPenteMove3 / gridSize][dPenteMove3 % gridSize] = 0;
            [board setAbstractBoard:abstractBoard];
            [zoomedBoard setAbstractBoard:abstractBoard];
            dPenteMove3 = -1;
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
            [submitButton
                setTitle:[NSString
                             stringWithFormat:
                                 NSLocalizedString(@"submit: %c%d-%c%d", nil),
                                 coordinateLetters[dPenteMove1 % gridSize],
                                 gridSize - (dPenteMove1 / gridSize),
                                 coordinateLetters[dPenteMove2 % gridSize],
                                 gridSize - (dPenteMove2 / gridSize)]
                forState:UIControlStateDisabled];
        } else if (dPenteMove2 != -1) {
            abstractBoard[dPenteMove2 / gridSize][dPenteMove2 % gridSize] = 0;
            [board setAbstractBoard:abstractBoard];
            [zoomedBoard setAbstractBoard:abstractBoard];
            dPenteMove2 = -1;
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
            [submitButton
                setTitle:[NSString
                             stringWithFormat:NSLocalizedString(@"submit: %c%d",
                                                                nil),
                                              coordinateLetters[dPenteMove1 %
                                                                gridSize],
                                              gridSize - (dPenteMove1 / gridSize)]
                forState:UIControlStateDisabled];
        } else if (dPenteMove1 != -1) {
            abstractBoard[dPenteMove1 / gridSize][dPenteMove1 % gridSize] = 0;
            [board setAbstractBoard:abstractBoard];
            [zoomedBoard setAbstractBoard:abstractBoard];
            dPenteMove1 = -1;
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
        }
    } else if (swap2Opening) {
        swap2Move3 = -1;
        if (swap2Move2 != -1) {
            abstractBoard[swap2Move2 / gridSize][swap2Move2 % gridSize] = 0;
            [board setAbstractBoard:abstractBoard];
            [zoomedBoard setAbstractBoard:abstractBoard];
            swap2Move2 = -1;
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
            [submitButton
                setTitle:[NSString
                             stringWithFormat:NSLocalizedString(@"submit: %c%d",
                                                                nil),
                                              coordinateLetters[swap2Move1 %
                                                                gridSize],
                                              gridSize - (swap2Move1 / gridSize)]
                forState:UIControlStateDisabled];
        } else if (swap2Move1 != -1) {
            abstractBoard[swap2Move1 / gridSize][swap2Move1 % gridSize] = 0;
            [board setAbstractBoard:abstractBoard];
            [zoomedBoard setAbstractBoard:abstractBoard];
            swap2Move1 = -1;
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
            [zoomedBoard setAbstractBoard:abstractBoard];
            [zoomedBoard setNeedsDisplay];
        }
    }
}

#pragma mark - Renju turn-based opening UI

// Legal central-square radius for the NEXT single-stone opening placement; 0 = no box.
// Moves 2/3/4/5 -> radius 1/2/3/4 (3x3/5x5/7x7/9x9) about centre (7,7). placed = stones on board.
- (int)renjuCentralBoxRadius {
    if (!activeGame) {
        return 0;
    }
    if (self.renjuMove4BranchA) {
        return 4; // move-4 "No swap": move 5 constrained to the 9x9
    }
    if (self.renjuMove4BranchB) {
        return 0; // move-4 "Place 10": offers are whole-board
    }
    NSString *phase = self.renjuPhase;
    int placed = (int)[movesList count];
    if ([phase isEqualToString:@"MOVE"]) {
        return MAX(1, MIN(4, placed)); // incl. Branch-A move 5 -> 9x9
    }
    if ([phase isEqualToString:@"SWAP"] && !self.renjuTakeOver &&
        !self.renjuMove4Decline) {
        if (placed >= 4) {
            return 0; // move-4 window: declining triggers BRANCH, no stone placed
        }
        return MAX(1, MIN(3, placed)); // decline+place windows 1-3 -> 3x3/5x5/7x7
    }
    return 0; // OFFERS/BRANCH/SELECTION/COMPLETE
}

// Mark every empty cell OUTSIDE the legal central square with -1 (masked) so the
// board's empty-cell guard rejects taps there. No-op when no box applies. The marks
// are transient: loadEngineIntoAbstractBoard rebuilds the board (no -1 for Renju) on
// the next server refresh, so they clear automatically.
- (void)applyRenjuOpeningMaskIfNeeded {
    int r = [self renjuCentralBoxRadius];
    if (r <= 0) {
        return;
    }
    for (int i = 0; i < gridSize; ++i) {
        for (int j = 0; j < gridSize; ++j) {
            if (abstractBoard[i][j] == 0 && (abs(j - 7) > r || abs(i - 7) > r)) {
                abstractBoard[i][j] = -1;
            }
        }
    }
    [self.board setNeedsDisplay];
    [self.zoomedBoard setNeedsDisplay];
}

- (void)updateRenjuBoxOverlay {
    // No visible central-box overlay (per design). The legal central square is still
    // enforced during placement in boardTap: (via renjuCentralBoxRadius), and the
    // server is authoritative regardless — we just don't draw the dashed hint.
    [self.renjuBoxLayer removeFromSuperlayer];
    self.renjuBoxLayer = nil;
}

- (void)renderRenjuCandidates:(NSArray<NSNumber *> *)cells {
    self.board.renjuCandidates = cells;
    [self.board setNeedsDisplay];
    if (self.zoomedBoard) {
        self.zoomedBoard.renjuCandidates = cells;
        [self.zoomedBoard setNeedsDisplay];
    }
}

- (BOOL)isRenjuMove4Window {
    return [self.renjuPhase isEqualToString:@"SWAP"] && [movesList count] == 4;
}

- (void)showRenjuOfferCounter {
    NSUInteger n = self.renjuPickedOffers.count;
    [dPenteChoiceLabel
        setText:[NSString stringWithFormat:NSLocalizedString(@"Pick %lu of 10",
                                                             nil),
                                           (unsigned long)n]];
    [dPenteChoiceLabel setHidden:NO];
}

- (void)renderRenjuOpeningUI {
    // Each render reflects a fresh server-shipped phase; the decision flags only carry
    // from a button press to the immediately-following submit, so reset them here.
    self.renjuTakeOver = NO;
    self.renjuMove4Decline = NO;
    self.renjuBranchB = NO;
    self.renjuMove4BranchA = NO;
    self.renjuMove4BranchB = NO;
    self.renjuSelectedPoints = [NSMutableArray array]; // clear any stale SELECTION pair
    // hide the dPente/swap2 controls first; clear any stale overlay from a prior phase.
    // The submit button stays hidden during the swap/branch/offer/selection choices —
    // those auto-submit; it is only revealed by placing a stone (MOVE / decline+place).
    [player1Button setHidden:YES];
    [player2Button setHidden:YES];
    [passButton setHidden:YES];
    [dPenteChoiceLabel setHidden:YES];
    [submitButton setHidden:YES];
    [self renderRenjuCandidates:@[]];
    [self updateRenjuBoxOverlay];

    NSString *phase = self.renjuPhase;
    if ([phase isEqualToString:@"SWAP"]) {
        if ([self isRenjuMove4Window]) {
            // Move-4: three choices on one screen via the move4 fold.
            [dPenteChoiceLabel setText:NSLocalizedString(@"Swap, play on, or offer 10?", nil)];
            [player1Button setTitle:NSLocalizedString(@"Swap", nil)
                           forState:UIControlStateNormal];
            [player2Button setTitle:NSLocalizedString(@"No swap", nil)
                           forState:UIControlStateNormal];
            [passButton setTitle:NSLocalizedString(@"Place 10", nil)
                        forState:UIControlStateNormal];
            [dPenteChoiceLabel setHidden:NO];
            [player1Button setHidden:NO];
            [player2Button setHidden:NO];
            [passButton setHidden:NO];
            [self.view bringSubviewToFront:player1Button];
            [self.view bringSubviewToFront:player2Button];
            [self.view bringSubviewToFront:passButton];
            [self.view bringSubviewToFront:dPenteChoiceLabel];
        } else {
            [dPenteChoiceLabel setText:NSLocalizedString(@"Swap?", nil)];
            [player1Button setTitle:NSLocalizedString(@"Yes", nil)
                           forState:UIControlStateNormal];
            [player2Button setTitle:NSLocalizedString(@"No", nil)
                           forState:UIControlStateNormal];
            [dPenteChoiceLabel setHidden:NO];
            [player1Button setHidden:NO];
            [player2Button setHidden:NO];
            [self.view bringSubviewToFront:player1Button];
            [self.view bringSubviewToFront:player2Button];
            [self.view bringSubviewToFront:dPenteChoiceLabel];
        }
    } else if ([phase isEqualToString:@"BRANCH"]) {
        [dPenteChoiceLabel setText:NSLocalizedString(@"Place 5th, or offer 10?", nil)];
        [player1Button setTitle:NSLocalizedString(@"Place", nil)
                       forState:UIControlStateNormal];
        [player2Button setTitle:NSLocalizedString(@"Offer", nil)
                       forState:UIControlStateNormal];
        [dPenteChoiceLabel setHidden:NO];
        [player1Button setHidden:NO];
        [player2Button setHidden:NO];
        [self.view bringSubviewToFront:player1Button];
        [self.view bringSubviewToFront:player2Button];
        [self.view bringSubviewToFront:dPenteChoiceLabel];
    } else if ([phase isEqualToString:@"OFFERS"]) {
        self.renjuPickedOffers = [NSMutableArray array];
        [self renderRenjuCandidates:@[]];
        [self showRenjuOfferCounter];
    } else if ([phase isEqualToString:@"SELECTION"]) {
        self.renjuSelectedPoints = [NSMutableArray array];
        [self renderRenjuCandidates:(self.renjuOffers ?: @[])];
        [dPenteChoiceLabel setText:NSLocalizedString(@"Tap black's 5th, then your 6th", nil)];
        [dPenteChoiceLabel setHidden:NO];
        [self.view bringSubviewToFront:dPenteChoiceLabel];
    } else {
        // MOVE / COMPLETE: ordinary single-stone placement, no choice buttons. Reveal
        // the submit button (disabled until a stone is placed) — it was hidden above for
        // the choice phases; the placement path only setEnabled:YES, never setHidden:NO.
        [submitButton setHidden:NO];
        [submitButton setEnabled:NO];
        [submitButton setTitle:NSLocalizedString(@"submit", nil)
                      forState:UIControlStateDisabled];
        [submitButton setAlpha:0.5];
    }
    // MOVE / COMPLETE: no buttons; placement handled by boardTap.
    // Lock out illegal cells (outside the central square) with -1 for the constrained
    // placement phases (SWAP windows 1-3 and MOVE). No-op for the others.
    [self applyRenjuOpeningMaskIfNeeded];
}

- (void)submitRenjuDecision {
    [player1Button setHidden:YES];
    [player2Button setHidden:YES];
    [dPenteChoiceLabel setHidden:YES];
    spinner.center = stone.center;
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(submitMoveToServer)
                             toTarget:self
                           withObject:nil];
}

- (BOOL)renjuOfferWouldDuplicate:(int)move {
    NSMutableSet<NSNumber *> *accepted = [NSMutableSet set];
    for (NSNumber *m in self.renjuPickedOffers) {
        for (NSNumber *img in [RenjuOfferSymmetry d4ImagesOf:m.intValue]) {
            [accepted addObject:img];
        }
    }
    for (NSNumber *img in [RenjuOfferSymmetry d4ImagesOf:move]) {
        if ([accepted containsObject:img]) {
            return YES;
        }
    }
    return NO;
}

- (IBAction)boardTap:(UILongPressGestureRecognizer *)recognizer {
    if (dPenteChoice && [submitButton isHidden]) {
        return;
    }
    // Renju: no board interaction while a swap/branch choice is pending. The choice
    // buttons are visible until the player decides; declining a swap (windows 1-3)
    // hides them and opens central-box placement.
    if (([self.renjuPhase isEqualToString:@"SWAP"] ||
         [self.renjuPhase isEqualToString:@"BRANCH"]) &&
        ![player1Button isHidden]) {
        return;
    }
    if (dPenteOpening) {
        if (dPenteMove1 == -1) {
            [stone setStoneColor:WHITE];
            [zoomedStone setStoneColor:WHITE];
        } else if (dPenteMove2 == -1) {
            [stone setStoneColor:BLACK];
            [zoomedStone setStoneColor:BLACK];
        } else if (dPenteMove3 == -1) {
            [stone setStoneColor:WHITE];
            [zoomedStone setStoneColor:WHITE];
        } else if (dPenteMove4 == -1) {
            [stone setStoneColor:BLACK];
            [zoomedStone setStoneColor:BLACK];
        }
        [stone setNeedsDisplay];
        [zoomedStone setNeedsDisplay];
    } else if (swap2Opening) {
        if (swap2Move1 == -1) {
            [stone setStoneColor:WHITE];
            [zoomedStone setStoneColor:WHITE];
        } else if (swap2Move2 == -1) {
            [stone setStoneColor:BLACK];
            [zoomedStone setStoneColor:BLACK];
        } else if (swap2Move3 == -1) {
            [stone setStoneColor:WHITE];
            [zoomedStone setStoneColor:WHITE];
        }
        [stone setNeedsDisplay];
        [zoomedStone setNeedsDisplay];
    } else if (swap2WillPass || (swap2Choice && swap2Pass)) {
        if (swap2Move1 == -1) {
            [stone setStoneColor:BLACK];
            [zoomedStone setStoneColor:BLACK];
        } else if (swap2Move2 == -1) {
            [stone setStoneColor:WHITE];
            [zoomedStone setStoneColor:WHITE];
        }
        [stone setNeedsDisplay];
        [zoomedStone setNeedsDisplay];
    } else if (self.renjuPhase != nil) {
        // Renju opening: black plays first (move 1 = centre). The stone the current
        // player is placing alternates by stones-on-board parity — odd count (centre
        // only, 3 stones, ...) places WHITE; even count places BLACK.
        int renjuColor = (([movesList count] % 2) == 1) ? WHITE : BLACK;
        [stone setStoneColor:renjuColor];
        [zoomedStone setStoneColor:renjuColor];
        [stone setNeedsDisplay];
        [zoomedStone setNeedsDisplay];
    } else {
        //        NSLog(@"kitty no");
    }

    int i, j;
    CGPoint currentPoint = [recognizer locationInView:self.board];
    NSNumber *finaMoveNumber;
    float cellSize = self.board.bounds.size.width / gridSize;
    j = (int)floorf(currentPoint.x / cellSize);
    i = (int)floorf(currentPoint.y / cellSize);

    switch ([recognizer state]) {
    case UIGestureRecognizerStateBegan:
        [stone
            setBounds:CGRectMake(
                          0, 0, 1.2 * self.board.bounds.size.width / gridSize,
                          1.2 * self.board.bounds.size.width / gridSize)];
        [zoomedStone
            setBounds:CGRectMake(0, 0,
                                 1.2 * 1.5 * 2 * self.board.bounds.size.width /
                                     gridSize,
                                 1.2 * 1.5 * 2 * self.board.bounds.size.width /
                                     gridSize)];
        [stone setNeedsDisplay];
        [zoomedStone setNeedsDisplay];
        //            NSLog(@"hi start %i %i \n %@", lastMove, [movesList
        //            count], movesList);
        if (!goMarkStones && lastMove != [movesList count] && activeGame) {
            whiteCaptures = 0;
            blackCaptures = 0;
            isLastMove = YES;
            lastMove = lastMove;
            [self replayGame:lastMove];
            [board setNeedsDisplay];
            [receivedMessageView
                setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.f]];
        }
        if (!goMarkStones && [captures count] != 0) {
            if (!swap2WillPass) {
                [self undoCaptures];
                [self updateCaptures];
                [board setNeedsDisplay];
            } else {
                lastMove = lastMove;
                [self replayGame:lastMove];
                int move;
                //                    if (connect6Move1 != -1) {
                //                        move = connect6Move1;
                //                        if ([[self.game myColor]
                //                        isEqualToString:@"white"]) {
                //                            abstractBoard[move/19][move%19] =
                //                            1;
                //                        } else {
                //                            abstractBoard[move/19][move%19] =
                //                            2;
                //                        }
                //                    }
                if (swap2Move1 != -1) {
                    move = swap2Move1;
                    abstractBoard[move / gridSize][move % gridSize] = 2;
                    [self detectCaptureOfOpponent:1 atPosition:move];
                }
                [board setNeedsDisplay];
            }
        }
        finalMove = -1;
        [zoomedBoard setHidden:NO];
        [stone setHidden:YES];
        finaMoveNumber = [NSNumber numberWithInt:gridSize * i + j];
        if (activeGame &&
            ((!goMarkStones && ((go && abstractGoBoard[i][j] == 0) ||
                                (abstractBoard[i][j] == 0))) ||
             (goMarkStones &&
              (abstractBoard[i][j] != 0 ||
               [deadBlackStones containsObject:finaMoveNumber] ||
               [deadWhiteStones containsObject:finaMoveNumber])))) {
            [zoomedStone setHidden:NO];
            [horizontalLine setHidden:NO];
            [verticalLine setHidden:NO];
        }
        break;
    case UIGestureRecognizerStateEnded:
        //            NSLog(@"hi ended");
        if ([zoomedBoard isHidden] && activeGame) {
            if (!isGoGame) {
                [submitButton setEnabled:NO];
                [submitButton setTitle:NSLocalizedString(@"submit", nil)
                              forState:UIControlStateDisabled];
                [submitButton setAlpha:0.5];
            } else {
                [submitButton setEnabled:YES];
                [submitButton setTitle:NSLocalizedString(@"PASS", nil)
                              forState:UIControlStateNormal];
            }
            break;
        }
        [zoomedBoard setHidden:YES];

        finalMove = gridSize * i + j;
        finaMoveNumber = [NSNumber numberWithInt:finalMove];
        if (self.renjuPhase != nil && activeGame) {
            int tapped = gridSize * i + j;
            if ([self.renjuPhase isEqualToString:@"OFFERS"] ||
                self.renjuMove4BranchB) {
                if (abstractBoard[i][j] != 0) {
                    break; // occupied
                }
                NSNumber *cell = @(tapped);
                if ([self.renjuPickedOffers containsObject:cell]) {
                    [self.renjuPickedOffers removeObject:cell]; // tap again to remove
                } else {
                    if (self.renjuPickedOffers.count >= 10) {
                        break;
                    }
                    if ([self renjuOfferWouldDuplicate:tapped]) {
                        break; // D4 dedup (UX)
                    }
                    [self.renjuPickedOffers addObject:cell];
                }
                [self renderRenjuCandidates:self.renjuPickedOffers];
                [self showRenjuOfferCounter];
                if (self.renjuPickedOffers.count == 10) {
                    finalMove = tapped; // unused by Branch-B payload
                    [self submitRenjuDecision]; // renjuAction=move (10 offers)
                }
                break;
            }
            if ([self.renjuPhase isEqualToString:@"SELECTION"]) {
                // Two taps: 1st = the offered black 5th, 2nd = an empty white 6th
                // distinct from the 5th. A tap beyond two resets the pair.
                if (self.renjuSelectedPoints == nil) {
                    self.renjuSelectedPoints = [NSMutableArray array];
                }
                if (self.renjuSelectedPoints.count == 0) {
                    if (![self.renjuOffers containsObject:@(tapped)]) {
                        break; // 1st must be offered
                    }
                    [self.renjuSelectedPoints addObject:@(tapped)];
                    [self renderRenjuCandidates:self.renjuSelectedPoints];
                } else if (self.renjuSelectedPoints.count == 1) {
                    if (abstractBoard[i][j] != 0 ||
                        tapped == [self.renjuSelectedPoints[0] intValue]) {
                        break; // 2nd must be empty and distinct from the 5th
                    }
                    [self.renjuSelectedPoints addObject:@(tapped)];
                    [self renderRenjuCandidates:self.renjuSelectedPoints];
                    [self submitRenjuDecision]; // renjuAction=select, moves "m5,m6"
                } else {
                    self.renjuSelectedPoints = [NSMutableArray array]; // 3rd tap resets
                    [self renderRenjuCandidates:(self.renjuOffers ?: @[])];
                }
                break;
            }
            // MOVE / SWAP decline+place: gate to the central box
            int r = [self renjuCentralBoxRadius];
            if (r > 0) {
                if (abs(j - 7) > r || abs(i - 7) > r) {
                    finalMove = -1;
                    [self replayGame:lastMove];
                    [submitButton setEnabled:NO];
                    [submitButton setTitle:@"submit"
                                  forState:UIControlStateDisabled];
                    [submitButton setAlpha:0.5];
                    [board setNeedsDisplay];
                    [zoomedBoard setNeedsDisplay];
                    break; // outside legal square
                }
            }
            // fall through to the normal single-stone placement/preview below
        }
        if (goMarkStones && activeGame &&
            (abstractBoard[i][j] != 0 ||
             [deadBlackStones containsObject:finaMoveNumber] ||
             [deadWhiteStones containsObject:finaMoveNumber])) {

            [self processDeadStone:finalMove];

        } else if (!go && abstractBoard[i][j] > 0) {
            connect6Move1 = -1;
            connect6Move2 = -1;
            dPenteMove1 = -1;
            dPenteMove2 = -1;
            dPenteMove3 = -1;
            dPenteMove4 = -1;
            swap2Move1 = -1;
            swap2Move2 = -1;
            swap2Move3 = -1;
            finalMove = -1;
            [self replayGame:lastMove];
            [submitButton setEnabled:NO];
            [submitButton setTitle:@"submit" forState:UIControlStateDisabled];
            [board setNeedsDisplay];
            [zoomedBoard setNeedsDisplay];
            break;

        } else if (((go && abstractGoBoard[i][j] == 0) ||
                    (!goMarkStones && abstractBoard[i][j] == 0)) &&
                   activeGame) {
            stone.center = CGPointMake(cellSize * j + cellSize / 2,
                                       cellSize * i + cellSize / 2);

            if (!([[self.game gameType] isEqualToString:@"Connect6"] &&
                  (connect6Move1 == -1)) &&
                !(dPenteOpening &&
                  ([[self.game gameType] isEqualToString:@"D-Pente"] ||
                   [[self.game gameType] isEqualToString:@"DK-Pente"]) &&
                  (dPenteMove3 == -1))) {
                [submitButton setEnabled:YES];
                if ([[self.game gameType] isEqualToString:@"Connect6"]) {
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(@"submit: %c%d-%c%d",
                                                           nil),
                                         coordinateLetters[connect6Move1 % gridSize],
                                         gridSize - (connect6Move1 / gridSize),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateNormal];
                } else if (([[self.game gameType] isEqualToString:@"D-Pente"] ||
                            [[self.game gameType]
                                isEqualToString:@"DK-Pente"]) &&
                           dPenteOpening) {
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(
                                             @"submit: %c%d-%c%d-%c%d-%c%d",
                                             nil),
                                         coordinateLetters[dPenteMove1 % gridSize],
                                         gridSize - (dPenteMove1 / gridSize),
                                         coordinateLetters[dPenteMove2 % gridSize],
                                         gridSize - (dPenteMove2 / gridSize),
                                         coordinateLetters[dPenteMove3 % gridSize],
                                         gridSize - (dPenteMove3 / gridSize),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateNormal];
                } else {
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(@"submit: %c%d",
                                                           nil),
                                         coordinateLetters[finalMove %
                                                           gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateNormal];
                }
                [submitButton setAlpha:1];
            }

            [stone setHidden:NO];
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
            if (dPenteOpening &&
                ([[self.game gameType] isEqualToString:@"D-Pente"] ||
                 [[self.game gameType] isEqualToString:@"DK-Pente"])) {
                if (dPenteMove1 == -1) {
                    dPenteMove1 = finalMove;
                    abstractBoard[i][j] = 1;
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(@"submit: %c%d",
                                                           nil),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateDisabled];
                    [submitButton setEnabled:NO];
                    [submitButton setAlpha:0.5];
                } else if (dPenteMove2 == -1) {
                    dPenteMove2 = finalMove;
                    abstractBoard[i][j] = 2;
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(@"submit: %c%d-%c%d",
                                                           nil),
                                         coordinateLetters[dPenteMove1 % gridSize],
                                         gridSize - (dPenteMove1 / gridSize),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateDisabled];
                    [submitButton setEnabled:NO];
                    [submitButton setAlpha:0.5];
                } else if (dPenteMove3 == -1) {
                    dPenteMove3 = finalMove;
                    abstractBoard[i][j] = 1;
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(
                                             @"submit: %c%d-%c%d-%c%d", nil),
                                         coordinateLetters[dPenteMove1 % gridSize],
                                         gridSize - (dPenteMove1 / gridSize),
                                         coordinateLetters[dPenteMove2 % gridSize],
                                         gridSize - (dPenteMove2 / gridSize),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateDisabled];
                    [submitButton setEnabled:NO];
                    [submitButton setAlpha:0.5];
                } else {
                    dPenteMove4 = finalMove;
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(
                                             @"submit: %c%d-%c%d-%c%d-%c%d",
                                             nil),
                                         coordinateLetters[dPenteMove1 % gridSize],
                                         gridSize - (dPenteMove1 / gridSize),
                                         coordinateLetters[dPenteMove2 % gridSize],
                                         gridSize - (dPenteMove2 / gridSize),
                                         coordinateLetters[dPenteMove3 % gridSize],
                                         gridSize - (dPenteMove3 / gridSize),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateDisabled];
                    [self detectCaptureOfOpponent:1 atPosition:finalMove];
                }
            }
            if (swap2Opening && [[self.game gameType] hasPrefix:@"Swap2-"]) {
                if (swap2Move1 == -1) {
                    swap2Move1 = finalMove;
                    abstractBoard[i][j] = 1;
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(@"submit: %c%d",
                                                           nil),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateDisabled];
                    [submitButton setEnabled:NO];
                    [submitButton setAlpha:0.5];
                } else if (swap2Move2 == -1) {
                    swap2Move2 = finalMove;
                    abstractBoard[i][j] = 2;
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(@"submit: %c%d-%c%d",
                                                           nil),
                                         coordinateLetters[swap2Move1 % gridSize],
                                         gridSize - (swap2Move1 / gridSize),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateDisabled];
                    [submitButton setEnabled:NO];
                    [submitButton setAlpha:0.5];
                } else {
                    swap2Move3 = finalMove;
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(
                                             @"submit: %c%d-%c%d-%c%d", nil),
                                         coordinateLetters[swap2Move1 % gridSize],
                                         gridSize - (swap2Move1 / gridSize),
                                         coordinateLetters[swap2Move2 % gridSize],
                                         gridSize - (swap2Move2 / gridSize),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateNormal];
                }
            }
            if (swap2WillPass && [[self.game gameType] hasPrefix:@"Swap2-"] &&
                [movesList count] == 3) {
                if (swap2Move1 == -1) {
                    swap2Move1 = finalMove;
                    abstractBoard[i][j] = 2;
                    [self detectCaptureOfOpponent:1 atPosition:finalMove];
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(@"submit: %c%d",
                                                           nil),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateDisabled];
                    [submitButton setEnabled:NO];
                    [submitButton setAlpha:0.5];
                } else {
                    swap2Move2 = finalMove;
                    [submitButton
                        setTitle:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(@"submit: %c%d-%c%d",
                                                           nil),
                                         coordinateLetters[swap2Move1 % gridSize],
                                         gridSize - (swap2Move1 / gridSize),
                                         coordinateLetters[finalMove % gridSize],
                                         gridSize - (finalMove / gridSize)]
                        forState:UIControlStateNormal];
                    abstractBoard[swap2Move1 / gridSize][swap2Move1 % gridSize] = 2;
                    [self detectCaptureOfOpponent:1 atPosition:swap2Move1];
                    [self detectCaptureOfOpponent:2 atPosition:finalMove];
                }
            }
            if (isGoGame) {
                if (finalMove != koMove) {
                    [self addGoMove:finalMove];
                    [self updateCaptures];
                }
            } else if (!([[self.game gameType] isEqualToString:@"Connect6"] ||
                         [[self.game gameType] isEqualToString:@"Gomoku"])) {
                if ([[self.game gameType] isEqualToString:@"Poof-Pente"] ||
                    [[self.game gameType] isEqualToString:@"O-Pente"]) {
                    if ([self detectPoof:(stone.stoneColor == BLACK ? 2 : 1)
                              atPosition:finalMove]) {
                        [stone setHidden:YES];
                    }
                }
                if ([[self.game gameType] isEqualToString:@"O-Pente"]) {
                    if ([self
                            detectKeryoPoof:(stone.stoneColor == BLACK ? 2 : 1)
                                 atPosition:finalMove]) {
                        [stone setHidden:YES];
                    }
                }
                [self
                    detectCaptureOfOpponent:(stone.stoneColor == BLACK ? 1 : 2)
                                 atPosition:finalMove];
                if ([[self.game gameType] containsString:@"Keryo-Pente"] ||
                    [[self.game gameType] isEqualToString:@"DK-Pente"] ||
                    [[self.game gameType] isEqualToString:@"O-Pente"]) {
                    [self
                        detectKeryoCaptureOfOpponent:(stone.stoneColor == BLACK
                                                          ? 1
                                                          : 2)
                                          atPosition:finalMove];
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
                [submitButton setTitle:NSLocalizedString(@"submit", nil)
                              forState:UIControlStateDisabled];
                [submitButton setAlpha:0.5];
            } else {
                [submitButton setTitle:NSLocalizedString(@"PASS", nil)
                              forState:UIControlStateNormal];
                finalMove = gridSize * gridSize;
                [self copyGoBoardBack];
            }
        }
        [board setNeedsDisplay];
        [zoomedBoard setNeedsDisplay];
        break;
    default:
        break;
    }
    if ((currentPoint.x < 0) ||
        (currentPoint.x > self.board.bounds.size.width) ||
        (currentPoint.y < 0) ||
        (currentPoint.y > self.board.bounds.size.height)) {
        // out of board bounds
        [zoomedBoard setHidden:YES];
        [zoomedStone setHidden:YES];
        [horizontalLine setHidden:YES];
        [verticalLine setHidden:YES];
        finalMove = -1;
        finaMoveNumber = nil;
    } else {
        if ([zoomedBoard isHidden] &&
            ([recognizer state] != UIGestureRecognizerStateEnded) &&
            ((go && abstractGoBoard[i][j] == 0) ||
             (!goMarkStones && abstractBoard[i][j] == 0) ||
             (goMarkStones &&
              (abstractBoard[i][j] != 0 ||
               [deadBlackStones containsObject:finaMoveNumber] ||
               [deadWhiteStones containsObject:finaMoveNumber])))) {
            if (activeGame) {
                [zoomedBoard setHidden:NO];
                [zoomedStone setHidden:NO];
                [stone setHidden:YES];
                [horizontalLine setHidden:NO];
                [verticalLine setHidden:NO];
            } else {
                [zoomedBoard setHidden:NO];
            }
        }
        // re-center the zoomed board.
        zoomedBoard.center =
            CGPointMake(board.center.x - (currentPoint.x - board.center.x),
                        board.center.y - (currentPoint.y - board.center.y));
        // re-center the stone, re-snap if needed.
        float cellSize = self.zoomedBoard.bounds.size.width / gridSize;
        if ((fabs(zoomedStone.center.x - 2 * currentPoint.x) >= cellSize / 2) ||
            (fabs(zoomedStone.center.y - 2 * currentPoint.y) >= cellSize / 2)) {

            zoomedStone.center = CGPointMake(cellSize * j + cellSize / 2,
                                             cellSize * i + cellSize / 2);
            verticalLine.center = CGPointMake(
                cellSize * j + cellSize / 2, zoomedBoard.bounds.size.width / 2);
            horizontalLine.center =
                CGPointMake(zoomedBoard.bounds.size.height / 2,
                            cellSize * i + cellSize / 2);
            if (goMarkStones) {
                finaMoveNumber = [NSNumber numberWithInt:gridSize * i + j];
            }
            if (activeGame &&
                ((!goMarkStones && ((go && abstractGoBoard[i][j] == 0) ||
                                    (abstractBoard[i][j] == 0))) ||
                 (goMarkStones &&
                  (abstractBoard[i][j] != 0 ||
                   [deadBlackStones containsObject:finaMoveNumber] ||
                   [deadWhiteStones containsObject:finaMoveNumber])))) {
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

- (void)undoCaptures {
    int myColor = ([[self.game myColor] isEqualToString:@"white"]) ? 1 : 2;
    BOOL poof = NO, done = NO;
    struct Capture capture;
    if ([captures count] > 0) {
        for (id capturee in captures) {
            [capturee getValue:&capture];
            int i = capture.position / gridSize, j = capture.position % gridSize,
                color = capture.color;
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
    [spinner setColor:[[self.game myColor] isEqualToString:@"white"]
                          ? [UIColor blackColor]
                          : [UIColor whiteColor]];
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(submitMoveToServer)
                             toTarget:self
                           withObject:nil];
}

- (NSString *)getDeadStonesString {
    NSMutableString *str = [[NSMutableString alloc]
        initWithString:[NSString stringWithFormat:@"%d", gridSize * gridSize]];
    for (NSNumber *move in deadBlackStones) {
        [str insertString:[NSString stringWithFormat:@"%i,", move.intValue]
                  atIndex:0];
    }
    for (NSNumber *move in deadWhiteStones) {
        [str insertString:[NSString stringWithFormat:@"%i,", move.intValue]
                  atIndex:0];
    }
    return str;
}

// Returns the renjuAction for the pending phase, or nil for a plain command=move.
// *outMoves receives the moves payload string.
- (NSString *)renjuActionForCurrentPhaseFillingMoves:(NSString **)outMoves {
    // Branch A (fresh move-4 decline OR post-take-over): a single `move` placing the
    // 5th stone. The server infers "decline pending swap" from the phase; no sentinel.
    if (self.renjuMove4BranchA) {
        *outMoves = [NSString stringWithFormat:@"%d", finalMove];
        return @"move";
    }
    // Branch B: a single `move` carrying the ten 5th-move offers (branch inferred by count).
    if (self.renjuMove4BranchB) {
        NSMutableArray<NSString *> *toks = [NSMutableArray array];
        for (NSNumber *n in self.renjuPickedOffers) {
            [toks addObject:[n stringValue]];
        }
        *outMoves = [toks componentsJoinedByString:@","];
        return @"move";
    }
    NSString *phase = self.renjuPhase;
    if ([phase isEqualToString:@"SWAP"]) {
        if (self.renjuTakeOver) {
            *outMoves = @"1"; // take over opponent's side; server ignores the payload
            return @"swap";
        }
        // windows 1-3 decline + place: a single `move` carrying just the stone.
        *outMoves = [NSString stringWithFormat:@"%d", finalMove];
        return @"move";
    }
    if ([phase isEqualToString:@"SELECTION"]) {
        // atomic 2-stone: chosen black 5th + white 6th.
        *outMoves = [NSString stringWithFormat:@"%@,%@",
                     self.renjuSelectedPoints[0], self.renjuSelectedPoints[1]];
        return @"select";
    }
    // MOVE / COMPLETE -> plain placement, no renjuAction
    *outMoves = [NSString stringWithFormat:@"%d", finalMove];
    return nil;
}

- (void)submitMoveToServer {
    //    NSLog(@"kitty %d", finalMove);

    NSString *moveString;
    NSString *renjuAction = nil;
    BOOL isRenju = [self.game.gameType containsString:@"Renju"];
    if (isRenju) {
        NSString *renjuMoves = nil;
        renjuAction = [self renjuActionForCurrentPhaseFillingMoves:&renjuMoves];
        moveString = renjuMoves;
    } else
    if ([[self.game gameType] isEqualToString:@"Connect6"] &&
        (connect6Move1 != -1) && (connect6Move2 != -1)) {
        moveString =
            [NSString stringWithFormat:@"%i,%i", connect6Move1, connect6Move2];
    } else if (([[self.game gameType] isEqualToString:@"D-Pente"] ||
                [[self.game gameType] isEqualToString:@"DK-Pente"]) &&
               (dPenteMove1 != -1) && (dPenteMove2 != -1) &&
               (dPenteMove3 != -1) && (dPenteMove4 != -1) && dPenteOpening) {
        moveString =
            [NSString stringWithFormat:@"%i,%i,%i,%i,", dPenteMove1,
                                       dPenteMove2, dPenteMove3, dPenteMove4];
    } else if (([[self.game gameType] isEqualToString:@"D-Pente"] ||
                [[self.game gameType] isEqualToString:@"DK-Pente"]) &&
               (finalMove != -1) && dPenteChoice) {
        moveString = [NSString stringWithFormat:@"1,%i", finalMove];
    } else if ([[self.game gameType] hasPrefix:@"Swap2-"] &&
               (swap2Opening || swap2WillPass || swap2Choice)) {
        if (swap2Opening && swap2Move1 != -1 && swap2Move2 != -1 &&
            swap2Move3 != -1) {
            moveString = [NSString stringWithFormat:@"%i,%i,%i,", swap2Move1,
                                                    swap2Move2, swap2Move3];
        } else if (swap2WillPass && swap2Move1 != -1 && swap2Move2 != -1) {
            moveString =
                [NSString stringWithFormat:@"2,%i,%i,", swap2Move1, swap2Move2];
        } else if (swap2Choice) {
            if (swap2PlayP1) {
                moveString = @"0";
            } else if (finalMove != -1) {
                moveString = [NSString stringWithFormat:@"1,%i,", finalMove];
            }
        }
    } else if (finalMove != -1) {
        moveString = [NSString stringWithFormat:@"%i", finalMove];
    }

    if (isGoGame) {
        if (goMarkStones) {
            moveString = [self getDeadStonesString];
        } else {
            if (finalMove == -1) {
                moveString =
                    [NSString stringWithFormat:@"%d", (gridSize * gridSize)];
            }
        }
    }

    //    NSLog(@"kitty %@", moveString);

    NSString *renjuSuffix =
        (renjuAction != nil)
            ? [NSString stringWithFormat:@"&renjuAction=%@", renjuAction]
            : @"";

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url;
    //    NSLog(@"kittyLog %@", replyMessage);
    if ([replyMessage isEqualToString:@""]) {
        url = [NSString
            stringWithFormat:
                @"https://www.pente.org/gameServer/tb/"
                @"game?command=move%@&mobile=&gid=%@&moves=%@&message=%@",
                hideString, [self.game gameID], moveString, renjuSuffix];
        if (development) {
            url = [NSString
                stringWithFormat:
                    @"https://localhost/gameServer/tb/"
                    @"game?command=move%@&mobile=&gid=%@&moves=%@&message=%@",
                    hideString, [self.game gameID], moveString, renjuSuffix];
        }
    } else {
        url = [NSString
            stringWithFormat:
                @"https://www.pente.org/gameServer/tb/"
                @"game?command=move%@&mobile=&gid=%@&moves=%@&message=%@%@",
                hideString, [self.game gameID], moveString,
                [self URLEncodedString_ch:replyMessage], renjuSuffix];
        if (development) {
            url = [NSString
                stringWithFormat:
                    @"https://localhost/gameServer/tb/"
                    @"game?command=move%@&mobile=&gid=%@&moves=%@&message=%@%@",
                    hideString, [self.game gameID], moveString,
                    [self URLEncodedString_ch:replyMessage], renjuSuffix];
        }
    }
    //    NSLog(@"kitty %@", url);
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];

    //    [request setHTTPShouldUsePipelining: YES];

    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient
        sendRequest:request
         completion:^(NSData *responseData, NSURLResponse *response,
                      NSError *error) {
             __strong typeof(weakSelf) strongSelf = weakSelf;
             if (!strongSelf)
                 return;
             [strongSelf->spinner stopAnimating];
             if (error) {
                 UIAlertView *alert = [[UIAlertView alloc]
                         initWithTitle:NSLocalizedString(@"Error", nil)
                               message:[NSString stringWithFormat:
                                                     NSLocalizedString(
                                                         @"Reason: %@", nil),
                                                     error.localizedDescription]
                              delegate:nil
                     cancelButtonTitle:@"OK"
                     otherButtonTitles:nil];
                 [alert show];
                 return;
             }
             NSInteger status =
                 [response isKindOfClass:[NSHTTPURLResponse class]]
                     ? ((NSHTTPURLResponse *)response).statusCode
                     : 200;
             BOOL respIsRenju =
                 [strongSelf.game.gameType containsString:@"Renju"];
             NSString *body =
                 responseData
                     ? [[[NSString alloc] initWithData:responseData
                                              encoding:NSUTF8StringEncoding]
                           stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceAndNewlineCharacterSet]]
                     : @"";
             BOOL rejected =
                 respIsRenju &&
                 ((status >= 400) ||
                  (body.length > 0 && ![body hasPrefix:@"{"] &&
                   ![body hasPrefix:@"["] &&
                   ([body containsString:@"Renju"] ||
                    [body containsString:@"offered"] ||
                    [body containsString:@"swap"] ||
                    [body containsString:@"Expected"] ||
                    [body containsString:@"decision"] ||
                    [body containsString:@"Selected"])));
             if (rejected) {
                 UIAlertView *alert = [[UIAlertView alloc]
                         initWithTitle:NSLocalizedString(@"Move rejected", nil)
                               message:body.length
                                           ? body
                                           : NSLocalizedString(
                                                 @"Renju move rejected.", nil)
                              delegate:nil
                     cancelButtonTitle:@"OK"
                     otherButtonTitles:nil];
                 [alert show];
                 return;
             }
             [strongSelf cleanUp];
         }];
}

- (void)cleanUp {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"notBack2Dash"]) {
        finalMove = -1;
        activeGame = NO;
        [submitButton setEnabled:NO];
        [submitButton setTitle:NSLocalizedString(@"submit", nil)
                      forState:UIControlStateDisabled];
        [submitButton setAlpha:0.5];
        [zoomedStone setHidden:YES];
        [stone setHidden:YES];
        [self replayGame];
        return;
    }
    PenteNavigationViewController *navControllor =
        (PenteNavigationViewController *)self.navigationController;
    [navControllor setDidMove:YES];
    [navControllor setActiveGameToRemove:[self.game gameID]];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)updateCaptures {
    [whiteCapturesCountLabel
        setText:[NSString stringWithFormat:@"x %i", whiteCaptures]];
    [whiteCapturesCountLabel sizeToFit];
    [whiteCapturesCountLabel setNeedsDisplay];
    [blackCapturesCountLabel
        setText:[NSString stringWithFormat:@"x %i", blackCaptures]];
    [blackCapturesCountLabel sizeToFit];
    [blackCapturesCountLabel setNeedsDisplay];
}

- (void)showAlertWithMessage:(NSString *)message {
    UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:NSLocalizedString(@"Error", nil)
                  message:[NSString stringWithFormat:NSLocalizedString(
                                                         @"Reason: %@", nil),
                                                     message]
                 delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
    //        [alert show];
    [alert performSelectorOnMainThread:@selector(show)
                            withObject:nil
                         waitUntilDone:YES];
}

- (void)replayGame {
    //    initialize all the global variables to the default values, then replay
    //    the game up to lastMove.
    gridSize = 19;
    isGoGame = NO;
    self->movesList = [[NSMutableArray alloc] init];
    self->captures = [[NSMutableArray alloc] init];
    for (int i = 0; i < gridSize; ++i) {
        for (int j = 0; j < gridSize; ++j) {
            abstractBoard[i][j] = 0;
        }
    }
    lastMove = -1;

    [board setLastConnect6Move:-1];
    [zoomedBoard setLastConnect6Move:-1];
    whiteCaptures = 0;
    blackCaptures = 0;
    if ((!receivedMessageView) || (!replyMessageView)) {
        receivedMessageView = [[UITextView alloc]
            initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40,
                                     44)];
        replyMessageView = [[UITextView alloc]
            initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40,
                                     44)];
    }

    __block BOOL iAmP1 = NO;

    [self setReplyMessage:@""];
    [self setReceivedMessage:nil];
    messagesHistory = [[NSMutableDictionary alloc] init];
    isLastMove = YES;

    //    NSString *tmpStr = [NSString
    //    stringWithFormat:@"https://www.pente.org/gameServer/tbpgn.jsp?g=%@",[self.game
    //    gameID]];
    //    NSString *tmpStr = [NSString
    //    stringWithFormat:@"https://www.pente.org/gameServer/tb/game?gid=%@&command=load",[self.game
    //    gameID]];
    NSString *tmpStr = [NSString
        stringWithFormat:
            @"https://www.pente.org/gameServer/mobile/json/game.jsp?gid=%@",
            [self.game gameID]];
    if (development) {
        tmpStr = [NSString
            stringWithFormat:
                @"https://localhost/gameServer/mobile/json/game.jsp?gid=%@",
                [self.game gameID]];
    }
    //    tmpStr = [NSString
    //    stringWithFormat:@"https://localhost/gameServer/mobile/game.jsp?gid=%@",[self.game
    //    gameID]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:tmpStr]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    //    NSString *htmlString = [NSString stringWithContentsOfURL:url
    //    encoding:NSUTF8StringEncoding error:&error];
    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient
        sendRequest:request
         completion:^(NSData *responseData, NSURLResponse *response,
                      NSError *error) {
             __strong typeof(weakSelf) strongSelf = weakSelf;
             if (!strongSelf)
                 return;

             if (error) {
                 [strongSelf showAlertWithMessage:error.localizedDescription];
                 return;
             }

             NSDictionary *jsonResponse = [NSJSONSerialization
                 JSONObjectWithData:responseData
                            options:NSJSONReadingMutableContainers
                              error:&error];
             if (error) {
                 [strongSelf showAlertWithMessage:error.localizedDescription];
                 return;
             }

             //    NSLog(@"kitty %@", htmlString);
             //    NSLog(@"kitty %@", jsonResponse);

             canHide = [jsonResponse[@"canHide"] boolValue];
             canUnHide = [jsonResponse[@"canUnHide"] boolValue];

             NSMutableArray *messages, *atMoves;
             BOOL cancelRequest = NO;

             NSString *myUsername = [[[NSUserDefaults standardUserDefaults]
                 objectForKey:@"username"] lowercaseString];
             NSString *p1Name = jsonResponse[@"player1"][@"name"],
                      *p2Name = jsonResponse[@"player2"][@"name"];
             NSString *currentPlayer = jsonResponse[@"currentPlayer"];
             BOOL undoRequest = [jsonResponse[@"undoRequested"] boolValue];
             [strongSelf.game setSetID:[jsonResponse[@"sid"] stringValue]];
             if ([jsonResponse[@"moves"] length] > 0) {
                 strongSelf->movesList = [NSMutableArray
                     arrayWithArray:[jsonResponse[@"moves"]
                                        componentsSeparatedByString:@","]];
             } else {
                 strongSelf->movesList = [[NSMutableArray alloc] init];
             }
             [strongSelf.game setRatedNot:jsonResponse[@"rated"]];
             [strongSelf.game setPrivateGame:jsonResponse[@"privateGame"]];
             iAmP1 = [myUsername isEqualToString:p1Name];
             [strongSelf.game setGameType:jsonResponse[@"gameName"]];
             isGoGame = ([strongSelf.game.gameType hasPrefix:@"Go"] &&
                         ![strongSelf.game.gameType hasPrefix:@"Gomoku"]) ||
                        ([strongSelf.game.gameType hasPrefix:@"Speed Go"] &&
                         ![strongSelf.game.gameType hasPrefix:@"Speed Gomoku"]);
             if ([strongSelf.game.gameType containsString:@"Renju"]) {
                 gridSize = 15;
             }
             [strongSelf setTitle:[strongSelf.game gameType]];
             if (iAmP1) {
                 [strongSelf.game setOpponentName:p2Name];
                 [strongSelf.game
                     setOpponentRating:[jsonResponse[@"player2"][@"rating"]
                                           stringValue]];
                 [strongSelf.game setMyColor:isGoGame ? @"black" : @"white"];
             } else {
                 [strongSelf.game setOpponentName:p1Name];
                 [strongSelf.game
                     setOpponentRating:[jsonResponse[@"player1"][@"rating"]
                                           stringValue]];
                 [strongSelf.game setMyColor:isGoGame ? @"white" : @"black"];
             }

             atMoves = [NSMutableArray
                 arrayWithArray:[jsonResponse[@"messageNums"]
                                    componentsSeparatedByString:@","]];
             messages = [NSMutableArray
                 arrayWithArray:[jsonResponse[@"messages"]
                                    componentsSeparatedByString:@","]];

             cancelMsg = @"";
             if (jsonResponse[@"cancel"]) {
                 if (![myUsername
                         isEqualToString:jsonResponse[@"cancel"][@"name"]]) {
                     cancelRequest = YES;
                     cancelMsg = [NSString
                         stringWithFormat:@"/n and writes: %@",
                                          jsonResponse[@"cancel"][@"message"]];
                 }
             }

             for (int i = 0; i < [messages count]; ++i) {
                 NSString *tmpStr =
                     [Message replaceSmileys:[messages objectAtIndex:i]];
                 [strongSelf->messagesHistory
                     setObject:tmpStr
                        forKey:[atMoves objectAtIndex:i]];
             }

             [strongSelf->receivedMessageView
                 setFont:[UIFont fontWithName:@"HelveticaNeue-Bold"
                                         size:15.35f]];
             if ([strongSelf->messagesHistory
                     objectForKey:[NSString
                                      stringWithFormat:
                                          @"%lu",
                                          (unsigned long)
                                              [strongSelf->movesList count]]]) {
                 if (([[strongSelf.game myColor] isEqualToString:@"white"] &&
                      (([strongSelf->movesList count] % 2) == 1)) ||
                     ([[strongSelf.game myColor] isEqualToString:@"black"] &&
                      (([strongSelf->movesList count] % 2) == 0))) {
                     [strongSelf->receivedMessageView
                         setFont:[UIFont fontWithName:@"HelveticaNeue"
                                                 size:15.35f]];
                     strongSelf->receivedMessage = [NSString
                         stringWithFormat:
                             @" me: %@",
                             [strongSelf->messagesHistory
                                 objectForKey:[NSString
                                                  stringWithFormat:
                                                      @"%lu",
                                                      (unsigned long)
                                                          [strongSelf->movesList
                                                                  count]]]];
                 } else {
                     [strongSelf->receivedMessageView
                         setFont:[UIFont fontWithName:@"HelveticaNeue-Bold"
                                                 size:15.35f]];
                     strongSelf->receivedMessage = [NSString
                         stringWithFormat:
                             @" %@: %@", [strongSelf.game opponentName],
                             [strongSelf->messagesHistory
                                 objectForKey:[NSString
                                                  stringWithFormat:
                                                      @"%lu",
                                                      (unsigned long)
                                                          [strongSelf->movesList
                                                                  count]]]];
                 }
                 if (([[strongSelf.game gameType]
                          isEqualToString:@"Connect6"] &&
                      [[strongSelf.game myColor] isEqualToString:@"white"] &&
                      (([strongSelf->movesList count] % 4) == 1)) ||
                     ([[strongSelf.game gameType]
                          isEqualToString:@"Connect6"] &&
                      [[strongSelf.game myColor] isEqualToString:@"black"] &&
                      (([strongSelf->movesList count] % 4) == 3))) {
                     [strongSelf->receivedMessageView
                         setFont:[UIFont fontWithName:@"HelveticaNeue"
                                                 size:15.35f]];
                     strongSelf->receivedMessage = [NSString
                         stringWithFormat:
                             @" me: %@",
                             [strongSelf->messagesHistory
                                 objectForKey:[NSString
                                                  stringWithFormat:
                                                      @"%lu",
                                                      (unsigned long)
                                                          [strongSelf->movesList
                                                                  count]]]];
                 } else if ([[strongSelf.game gameType]
                                isEqualToString:@"Connect6"]) {
                     [strongSelf->receivedMessageView
                         setFont:[UIFont fontWithName:@"HelveticaNeue-Bold"
                                                 size:15.35f]];
                     strongSelf->receivedMessage = [NSString
                         stringWithFormat:
                             @" %@: %@", [strongSelf.game opponentName],
                             [strongSelf->messagesHistory
                                 objectForKey:[NSString
                                                  stringWithFormat:
                                                      @"%lu",
                                                      (unsigned long)
                                                          [strongSelf->movesList
                                                                  count]]]];
                 }
                 if (isGoGame) {
                     if (([[strongSelf.game myColor]
                              isEqualToString:@"black"] &&
                          (([strongSelf->movesList count] % 2) == 1)) ||
                         ([[strongSelf.game myColor]
                              isEqualToString:@"white"] &&
                          (([strongSelf->movesList count] % 2) == 0))) {
                         [strongSelf->receivedMessageView
                             setFont:[UIFont fontWithName:@"HelveticaNeue"
                                                     size:15.35f]];
                         strongSelf->receivedMessage = [NSString
                             stringWithFormat:
                                 @" me: %@",
                                 [strongSelf->messagesHistory
                                     objectForKey:
                                         [NSString
                                             stringWithFormat:
                                                 @"%lu",
                                                 (unsigned long)
                                                     [strongSelf->movesList
                                                             count]]]];
                     } else {
                         [strongSelf->receivedMessageView
                             setFont:[UIFont fontWithName:@"HelveticaNeue-Bold"
                                                     size:15.35f]];
                         strongSelf->receivedMessage = [NSString
                             stringWithFormat:
                                 @" %@: %@", [strongSelf.game opponentName],
                                 [strongSelf->messagesHistory
                                     objectForKey:
                                         [NSString
                                             stringWithFormat:
                                                 @"%lu",
                                                 (unsigned long)
                                                     [strongSelf->movesList
                                                             count]]]];
                     }
                 }
             } else {
                 strongSelf->receivedMessage = @"";
                 [strongSelf->replyMessageView
                     setFrame:CGRectMake(0, 0,
                                         strongSelf.view.bounds.size.width - 40,
                                         88)];
             }

             [strongSelf->receivedMessageView setEditable:NO];
             [strongSelf->receivedMessageView setAlpha:0.90];
             //    [strongSelf->receivedMessageView setBackgroundColor:[UIColor
             //    colorWithRed:0.98f green:0.98f blue:0.98f alpha:0.95]];
             strongSelf->receivedMessageView.clipsToBounds = YES;
             strongSelf->receivedMessageView.layer.cornerRadius = 5.0f;
             strongSelf->receivedMessageView.contentInset =
                 UIEdgeInsetsMake(-10.0, 0.0, 0, 0.0);
             [strongSelf->receivedMessageView
                 setText:strongSelf->receivedMessage];
             CGRect frame = strongSelf->receivedMessageView.frame;
             frame.origin.y = 568;

             NSDictionary *fontAttributes = [NSDictionary
                 dictionaryWithObject:[strongSelf->receivedMessageView font]
                               forKey:NSFontAttributeName];
             [strongSelf.view addSubview:strongSelf->receivedMessageView];
             CGRect textFrame = [strongSelf->receivedMessage
                 boundingRectWithSize:
                     CGSizeMake(
                         strongSelf->receivedMessageView.contentSize.width +
                             strongSelf->receivedMessageView.contentOffset.x -
                             strongSelf->receivedMessageView.contentInset.left -
                             strongSelf->receivedMessageView.contentInset.right,
                         strongSelf->receivedMessageView.font.lineHeight * 5)
                              options:(NSStringDrawingUsesLineFragmentOrigin |
                                       NSLineBreakByWordWrapping)
                           attributes:fontAttributes
                              context:nil];
             [strongSelf->receivedMessageView
                 setText:strongSelf->receivedMessage];
             //    CGFloat fontLineHeight = [[strongSelf->receivedMessageView
             //    font] lineHeight];
             [strongSelf->receivedMessageView setFrame:frame];
             //    [strongSelf.view addSubview:
             //    strongSelf->receivedMessageView];

             //    if (strongSelf->receivedMessageView.contentSize.height <
             //    (3*strongSelf->receivedMessageView.font.lineHeight)) {
             if (textFrame.size.height <
                 (3 * strongSelf->receivedMessageView.font.lineHeight)) {
                 //        frame.size.height =
                 //        strongSelf->receivedMessageView.contentSize.height;
                 frame.size.height = textFrame.size.height;
             } else {
                 frame.size.height =
                     MIN((strongSelf->receivedMessageView.font.lineHeight * 5),
                         textFrame.size.height -
                             strongSelf->receivedMessageView.contentInset.top);
             }
             [strongSelf->receivedMessageView removeFromSuperview];
             [strongSelf->receivedMessageView setFrame:frame];

             [strongSelf->replyMessageView
                 setFont:[UIFont systemFontOfSize:15]];
             frame = strongSelf->replyMessageView.frame;
             frame.size.height =
                 strongSelf->replyMessageView.font.lineHeight * 3;
             [strongSelf->replyMessageView setAlpha:0.90];
             [strongSelf->replyMessageView setEditable:YES];
             strongSelf->replyMessageView.clipsToBounds = YES;
             strongSelf->replyMessageView.layer.cornerRadius = 5.0f;
             strongSelf->replyMessageView.contentInset =
                 UIEdgeInsetsMake(-7.0, 0.0, 0, 0.0);
             [strongSelf->replyMessageView setFrame:frame];
             //    [strongSelf->replyMessageView
             //    setAutocapitalizationType:UITextAutocapitalizationTypeNone];
             //    [strongSelf->replyMessageView
             //    setAutocorrectionType:UITextAutocorrectionTypeNo];
             [strongSelf->replyMessageView setReturnKeyType:UIReturnKeyDone];
             [strongSelf->replyMessageView setDelegate:self];
             strongSelf->replyMessageView.layer.borderWidth = 2.0f;
             strongSelf->replyMessageView.layer.borderColor =
                 [[UIColor grayColor] CGColor];

             NSString *locRating = NSLocalizedString(@"rating:", nil);
             NSString *remTime = NSLocalizedString(@"Remaining time:", nil);
             NSString *ratedPrivate = [NSString
                 stringWithFormat:NSLocalizedString(@"This game is %@ and %@",
                                                    nil),
                                  [strongSelf.game localizedRatedNot],
                                  [strongSelf.game privateGame]];

             if (![myUsername isEqualToString:p1Name] &&
                 ![myUsername isEqualToString:p2Name]) {
                 playerStatsBaseString = [NSString
                     stringWithFormat:
                         @"<font size=\"3.5\"><a "
                         @"href=\"https://www.pente.org/gameServer/"
                         @"profile?viewName=%@\">%@</a> vs <a "
                         @"href=\"https://www.pente.org/gameServer/"
                         @"profile?viewName=%@\">%@</a>, %@ %@ <br> %@ %@ <br> "
                         @"%@ </font><hr>",
                         p1Name, p1Name, p2Name, p2Name, locRating,
                         [strongSelf.game opponentRating], remTime,
                         [strongSelf.game localizedTimeString], ratedPrivate];
             } else {
                 playerStatsBaseString = [NSString
                     stringWithFormat:
                         @"<font size=\"3.5\">Opponent: <a "
                         @"href=\"https://www.pente.org/gameServer/"
                         @"profile?viewName=%@\">%@</a>, %@ %@ <br> %@ %@ <br> "
                         @"%@</font><hr>",
                         [strongSelf.game opponentName],
                         [strongSelf.game opponentName], locRating,
                         [strongSelf.game opponentRating], remTime,
                         [strongSelf.game remainingTime], ratedPrivate];
             }

             int dPenteState = jsonResponse[@"dPenteState"] != nil
                                   ? [jsonResponse[@"dPenteState"] intValue]
                                   : 0;

             id rpVal = jsonResponse[@"renjuPhase"];
             self.renjuPhase = [rpVal isKindOfClass:[NSString class]] ? rpVal : nil;

             id roVal = jsonResponse[@"renjuOffers"];
             if ([roVal isKindOfClass:[NSString class]] && [(NSString *)roVal length] > 0) {
                 NSMutableArray<NSNumber *> *parsed = [NSMutableArray array];
                 for (NSString *tok in [(NSString *)roVal componentsSeparatedByString:@","]) {
                     NSString *t = [tok stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                     if (t.length > 0) [parsed addObject:@([t intValue])];
                 }
                 self.renjuOffers = parsed;
             } else {
                 self.renjuOffers = nil;
             }

             id rsVal = jsonResponse[@"renjuSwaps"];
             self.renjuSwaps = [rsVal isKindOfClass:[NSNumber class]] ? rsVal : nil;

             //    NSLog(@"kitty message %@", message);
             dPenteOpening = NO;
             whiteCaptures = 0;
             blackCaptures = 0;
             [strongSelf resetBoard];

             lastMove = (int)[strongSelf->movesList count];

             if ([[strongSelf.game gameType] isEqualToString:@"Pente"] ||
                 [[strongSelf.game gameType] isEqualToString:@"Boat-Pente"] ||
                 [[strongSelf.game gameType] isEqualToString:@"Speed Pente"] ||
                 [[strongSelf.game gameType]
                     isEqualToString:@"Speed Boat-Pente"]) {
                 [strongSelf replayGame:lastMove];
             }
             if ([[strongSelf.game gameType] isEqualToString:@"Keryo-Pente"] ||
                 [[strongSelf.game gameType]
                     isEqualToString:@"Speed Keryo-Pente"]) {
                 [strongSelf replayGame:lastMove];
             }
             if ([[strongSelf.game gameType] isEqualToString:@"O-Pente"] ||
                 [[strongSelf.game gameType]
                     isEqualToString:@"Speed O-Pente"]) {
                 [strongSelf replayGame:lastMove];
             }
             if ([[strongSelf.game gameType] isEqualToString:@"G-Pente"] ||
                 [[strongSelf.game gameType]
                     isEqualToString:@"Speed G-Pente"]) {
                 [strongSelf replayGame:lastMove];
             }
             if ([[strongSelf.game gameType] isEqualToString:@"D-Pente"] ||
                 [[strongSelf.game gameType]
                     isEqualToString:@"Speed D-Pente"] ||
                 [[strongSelf.game gameType] isEqualToString:@"DK-Pente"] ||
                 [[strongSelf.game gameType]
                     isEqualToString:@"Speed DK-Pente"]) {
                 if ([[strongSelf.game gameType] isEqualToString:@"DK-Pente"] ||
                     [[strongSelf.game gameType]
                         isEqualToString:@"Speed DK-Pente"]) {
                     [strongSelf replayGame:lastMove];
                 } else {
                     [strongSelf replayGame:lastMove];
                 }

                 dPenteChoice = NO;
                 if ([strongSelf->movesList count] == 4) {
                     //            NSLog(@"kitty %@", htmlString);
                     if (dPenteState == 2 && strongSelf->activeGame) {
                         dPenteChoice = YES;
                         [strongSelf->submitButton setHidden:YES];
                         [player2Button setHidden:NO];
                         [player1Button setHidden:NO];
                         [strongSelf.view bringSubviewToFront:player1Button];
                         [dPenteChoiceLabel setHidden:NO];
                         [whiteStoneCaptures setHidden:YES];
                         [whiteCapturesCountLabel setHidden:YES];
                         [blackStoneCaptures setHidden:YES];
                         [blackCapturesCountLabel setHidden:YES];
                         [lockButton setHidden:YES];
                     } else {
                         [player1Button setHidden:YES];
                         [player2Button setHidden:YES];
                         [dPenteChoiceLabel setHidden:YES];
                     }
                 }
             }
             if ([strongSelf.game.gameType containsString:@"Swap2-"]) {
                 swap2Opening = [strongSelf->movesList count] == 0;
                 swap2Choice =
                     dPenteState == 2 && ([strongSelf->movesList count] == 3 ||
                                          [strongSelf->movesList count] == 5);
                 if ([strongSelf.game.gameType containsString:@"Swap2-Pente"]) {
                     [strongSelf replayGame:lastMove];
                 } else if ([strongSelf.game.gameType
                                containsString:@"Swap2-Keryo"]) {
                     [strongSelf replayGame:lastMove];
                 }

                 if (swap2Choice) {
                     if ([strongSelf->movesList count] == 3) {
                         dPenteChoice = YES;
                         [strongSelf->submitButton setHidden:YES];
                         [player2Button setHidden:NO];
                         [player1Button setHidden:NO];
                         [strongSelf.view bringSubviewToFront:player1Button];
                         [dPenteChoiceLabel setHidden:NO];
                         [whiteStoneCaptures setHidden:YES];
                         [whiteCapturesCountLabel setHidden:YES];
                         [blackStoneCaptures setHidden:YES];
                         [blackCapturesCountLabel setHidden:YES];
                         [lockButton setHidden:YES];
                         [passButton setHidden:NO];

                     } else if ([strongSelf->movesList count] == 5) {
                         dPenteChoice = YES;
                         [strongSelf->submitButton setHidden:YES];
                         [player2Button setHidden:NO];
                         [player1Button setHidden:NO];
                         [strongSelf.view bringSubviewToFront:player1Button];
                         [dPenteChoiceLabel setHidden:NO];
                         [whiteStoneCaptures setHidden:YES];
                         [whiteCapturesCountLabel setHidden:YES];
                         [blackStoneCaptures setHidden:YES];
                         [blackCapturesCountLabel setHidden:YES];
                         [lockButton setHidden:YES];
                     }
                 } else {
                 }
             }
             if ([[strongSelf.game gameType] containsString:@"Poof-Pente"]) {
                 [strongSelf replayGame:lastMove];
             }
             go = NO;
             goMarkStones = NO;
             goEvaluateDeadStones = NO;
             if (isGoGame) {
                 if ([strongSelf.game.gameType containsString:@"(9x9)"]) {
                     gridSize = 9;
                 } else if ([strongSelf.game.gameType
                                containsString:@"(13x13)"]) {
                     gridSize = 13;
                 }
                 goMarkStones = [jsonResponse[@"goState"]
                     isEqualToString:@"MARK_DEAD_STONES"];
                 goEvaluateDeadStones = [jsonResponse[@"goState"]
                     isEqualToString:@"EVALUATE_DEAD_STONES"];
                 [strongSelf replayGoGame:lastMove];
                 [strongSelf->board setGo:YES];
                 [strongSelf->zoomedBoard setGo:YES];
                 if (!goMarkStones && !goEvaluateDeadStones) {
                     [strongSelf copyGoBoard];
                     [strongSelf->zoomedBoard setAbstractBoard:abstractGoBoard];
                     go = YES;
                 } else if (goMarkStones) {
                     [strongSelf showTerritory:nil];
                 } else if (goEvaluateDeadStones && strongSelf->activeGame) {
                     [strongSelf evaluateDeadStones];
                 }
             }
             if ([[strongSelf.game gameType] containsString:@"Connect6"]) {
                 [strongSelf replayGame:lastMove];
             }
             [strongSelf updateCaptures];

             if ([[strongSelf.game gameType] containsString:@"Gomoku"]) {
                 [strongSelf replayGame:lastMove];
             }

             if ([[strongSelf.game gameType] containsString:@"Renju"]) {
                 [strongSelf replayGame:lastMove];
             }

             // Find out your color
             if ([[strongSelf.game myColor] isEqualToString:@"white"]) {
                 [strongSelf->stone setStoneColor:WHITE];
             } else {
                 [strongSelf->stone setStoneColor:BLACK];
             }
             [strongSelf->zoomedStone
                 setStoneColor:[strongSelf->stone stoneColor]];
             if (goMarkStones) {
                 [strongSelf->zoomedStone setStoneColor:RED];
                 [strongSelf->zoomedStone setAlpha:0.7];
             }

             moveStatsString = [[NSMutableString alloc] init];
             for (int i = 0; i < lastMove; ++i) {
                 int rowCol = [strongSelf
                     parseMove:[strongSelf->movesList objectAtIndex:i]];
                 if (i == 0) {
                     [moveStatsString appendString:@"<b>1.</b> "];
                 } else if ([[strongSelf.game gameType]
                                containsString:@"Connect6"]) {
                     if (((i - 3) % 4) == 0) {
                         [moveStatsString
                             appendString:[NSString stringWithFormat:
                                                        @"&nbsp; <b>%i.</b> ",
                                                        (i >> 2) + 2]];
                     } else if (((i - 3) % 4) == 2 || i == 1) {
                         [moveStatsString appendString:@" - "];
                     } else {
                         [moveStatsString appendString:@"-"];
                     }
                 } else {
                     if ((i % 2) == 0) {
                         [moveStatsString
                             appendString:[NSString stringWithFormat:
                                                        @"&nbsp; <b>%i.</b> ",
                                                        (i >> 1) + 1]];
                     } else {
                         [moveStatsString appendString:@" - "];
                     }
                 }
                 if (rowCol < gridSize * gridSize) {
                     [moveStatsString
                         appendString:[NSString
                                          stringWithFormat:
                                              @"%c%d",
                                              coordinateLetters[rowCol %
                                                                gridSize],
                                              gridSize - (rowCol / gridSize)]];
                 } else {
                     [moveStatsString appendString:@"PASS"];
                 }
             }
             [strongSelf->playerStats
                 loadHTMLString:[HEADERSTRING stringByAppendingString:
                                                  [playerStatsBaseString
                                                      stringByAppendingString:
                                                          moveStatsString]]
                        baseURL:nil];

             [strongSelf->board setGridSize:gridSize];
             [strongSelf->zoomedBoard setGridSize:gridSize];
             [strongSelf->board setNeedsDisplay];
             [strongSelf->zoomedBoard setNeedsDisplay];

             if (cancelRequest) {
                 [strongSelf presentCancelReply];
             }

             if (![strongSelf->receivedMessage isEqualToString:@""]) {
                 [strongSelf notifyNewMessage];
             }

             strongSelf->activeGame =
                 [currentPlayer isEqualToString:myUsername];

             if ([strongSelf.game.gameType containsString:@"Renju"]) {
                 if (strongSelf.renjuPhase != nil && strongSelf->activeGame) {
                     [strongSelf renderRenjuOpeningUI];
                 } else {
                     // not our turn / no opening phase: clear any stale overlay
                     [player1Button setHidden:YES];
                     [player2Button setHidden:YES];
                     [passButton setHidden:YES];
                     [dPenteChoiceLabel setHidden:YES];
                     [strongSelf renderRenjuCandidates:@[]];
                     [strongSelf updateRenjuBoxOverlay]; // radius 0 -> removes box
                 }
             }

             if ([[strongSelf.game opponentName] isEqualToString:@"computer"]) {
                 NSString *message = nil;
                 BOOL iWin = YES;
                 if (strongSelf->lastReplayWinner == 1) {
                     message = NSLocalizedString(@"White wins", nil);
                 } else if (strongSelf->lastReplayWinner == 2) {
                     message = NSLocalizedString(@"Black wins", nil);
                 } else if (whiteCaptures == 10) {
                     message = NSLocalizedString(@"Black wins", nil);
                 } else if (blackCaptures == 10) {
                     message = NSLocalizedString(@"White wins", nil);
                 }
                 if (message) {
                     strongSelf->activeGame = NO;
                     if ([message isEqualToString:@"White wins"]) {
                         if ([[strongSelf.game myColor]
                                 isEqualToString:@"black"]) {
                             iWin = NO;
                         }
                     } else {
                         if ([[strongSelf.game myColor]
                                 isEqualToString:@"white"]) {
                             iWin = NO;
                         }
                     }
                     [TSMessage
                         showNotificationInViewController:
                             strongSelf.navigationController
                                                    title:NSLocalizedString(
                                                              @"Game Over", nil)
                                                 subtitle:message
                                                    image:nil
                                                     type:
                                                         (iWin
                                                              ? TSMessageNotificationTypeSuccess
                                                              : TSMessageNotificationTypeError)
                                                     duration:
                                                         TSMessageNotificationDurationAutomatic
                                                 callback:^{
                                                     [TSMessage
                                                         dismissActiveNotification];
                                                 }
                                              buttonTitle:nil
                                           buttonCallback:nil
                                               atPosition:
                                                   TSMessageNotificationPositionBottom
                                     canBeDismissedByUser:YES];
                 }
             }
             if ([jsonResponse[@"state"] isEqualToString:@"inactive"]) {
                 strongSelf->activeGame = NO;
                 PenteNavigationViewController *navC =
                     (PenteNavigationViewController *)
                         strongSelf.navigationController;
                 if (navC.player.dbAccess) {
                     [strongSelf->submitButton
                         setImage:[UIImage imageNamed:@"database.png"]
                         forState:UIControlStateNormal];
                     [strongSelf->submitButton
                             removeTarget:self
                                   action:@selector(submitMove:)
                         forControlEvents:UIControlEventTouchUpInside];
                     [strongSelf->submitButton
                                addTarget:self
                                   action:@selector(toDB)
                         forControlEvents:UIControlEventTouchUpInside];
                     [strongSelf->submitButton
                         setTitle:NSLocalizedString(@"   search", nil)
                         forState:UIControlStateNormal];
                     [strongSelf->submitButton setAlpha:1.0f];
                     [strongSelf->submitButton setEnabled:YES];
                     [strongSelf->submitButton setNeedsDisplay];
                     [lockButton removeFromSuperview];
                 }
             }
             if (undoRequest && strongSelf->activeGame) {
                 [strongSelf presentUndoOptions];
             }
             if (goMarkStones && strongSelf->activeGame &&
                 ![[NSUserDefaults standardUserDefaults]
                     boolForKey:@"doublePassInfo"]) {
                 [strongSelf presentDoublePass];
             }
             if (([myUsername isEqualToString:p1Name] ||
                  [myUsername isEqualToString:p2Name]) &&
                 !strongSelf->activeGame &&
                 [jsonResponse[@"state"] isEqualToString:@"active"] &&
                 dPenteState != 2 &&
                 ([strongSelf->movesList count] > 1 ||
                  ([strongSelf->movesList count] > 0 &&
                   (isGoGame ||
                    [[strongSelf.game gameType] isEqualToString:@"D-Pente"] ||
                    [[strongSelf.game gameType]
                        isEqualToString:@"DK-Pente"])))) {
                 [strongSelf->submitButton
                         removeTarget:nil
                               action:NULL
                     forControlEvents:UIControlEventAllEvents];
                 if (undoRequest) {
                     [strongSelf->submitButton
                         setTitle:NSLocalizedString(@"undo requested", nil)
                         forState:UIControlStateDisabled];
                     [strongSelf->submitButton setEnabled:NO];
                     [strongSelf->submitButton setAlpha:0.85];
                 } else {
                     [strongSelf->submitButton
                         setTitle:NSLocalizedString(@"request undo", nil)
                         forState:UIControlStateNormal];
                     [strongSelf->submitButton setEnabled:YES];
                     [strongSelf->submitButton setAlpha:1];
                     [strongSelf->submitButton
                                addTarget:self
                                   action:@selector(requestUndo:)
                         forControlEvents:UIControlEventTouchUpInside];
                 }
             } else if (([myUsername isEqualToString:p1Name] ||
                         [myUsername isEqualToString:p2Name]) &&
                        strongSelf->activeGame) {
                 [strongSelf->submitButton
                         removeTarget:nil
                               action:NULL
                     forControlEvents:UIControlEventAllEvents];
                 [strongSelf->submitButton
                            addTarget:self
                               action:@selector(submitMove:)
                     forControlEvents:UIControlEventTouchUpInside];
                 if (isGoGame) {
                     if (goMarkStones) {
                         [strongSelf->submitButton
                             setTitle:NSLocalizedString(@"submit", nil)
                             forState:UIControlStateNormal];
                         [strongSelf->submitButton setEnabled:YES];
                         [strongSelf->submitButton setAlpha:1.0];
                     } else {
                         [strongSelf->submitButton
                             setTitle:NSLocalizedString(@"PASS", nil)
                             forState:UIControlStateNormal];
                         [strongSelf->submitButton setEnabled:YES];
                         [strongSelf->submitButton setAlpha:1.0];
                     }
                 } else {
                     [strongSelf->submitButton
                         setTitle:NSLocalizedString(@"submit", nil)
                         forState:UIControlStateDisabled];
                     [strongSelf->submitButton setEnabled:NO];
                     [strongSelf->submitButton setAlpha:0.85];
                 }
             }
         }]; // end sendRequest completion
}

- (void)requestUndo:(UIButton *)sender {
    PenteNavigationViewController *navControllor =
        (PenteNavigationViewController *)self.navigationController;
    if ([navControllor.player subscriber]) {
        UIAlertController *confirmController = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"Are you sure?", nil)
                             message:nil
                      preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction =
            [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil)
                                     style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action){
                                   }];
        UIAlertAction *confirmAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"yes, request undo", nil)
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
                        NSError *error = nil;
                        NSURLResponse *response;
                        NSMutableURLRequest *request =
                            [[NSMutableURLRequest alloc] init];

                        NSString *post =
                            [NSString stringWithFormat:
                                          @"gid=%@&command=requestUndo&mobile=",
                                          [self.game gameID]];
                        NSData *postData =
                            [post dataUsingEncoding:NSASCIIStringEncoding
                                allowLossyConversion:YES];
                        NSString *postLength = [NSString
                            stringWithFormat:@"%lu",
                                             (unsigned long)[postData length]];

                        NSURL *url = [NSURL
                            URLWithString:
                                @"https://www.pente.org/gameServer/tb/game"];
                        if (development) {
                            url = [NSURL
                                URLWithString:
                                    @"https://localhost/gameServer/tb/game"];
                        }
                        [request setURL:url];
                        [request setHTTPMethod:@"POST"];
                        [request setValue:postLength
                            forHTTPHeaderField:@"Content-Length"];
                        [request setValue:@"application/x-www-form-urlencoded"
                            forHTTPHeaderField:@"Content-Type"];
                        [request setHTTPBody:postData];
                        [request setTimeoutInterval:7.0f];

                        [request setHTTPShouldUsePipelining:YES];

                        __weak typeof(self) weakSelf = self;
                        [PenteHTTPClient
                            sendRequest:request
                             completion:^(NSData *responseData,
                                          NSURLResponse *response,
                                          NSError *error) {
                                 if (error) {
                                     UIAlertView *alert = [[UIAlertView alloc]
                                             initWithTitle:NSLocalizedString(
                                                               @"Error", nil)
                                                   message:
                                                       [NSString
                                                           stringWithFormat:
                                                               NSLocalizedString(
                                                                   @"Reason: "
                                                                   @"%@",
                                                                   nil),
                                                               error
                                                                   .localizedDescription]
                                                  delegate:nil
                                         cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];
                                     [alert show];
                                     return;
                                 }
                                 [weakSelf.navigationController
                                     popToRootViewControllerAnimated:YES];
                             }];
                    }];
        [confirmController addAction:cancelAction];
        [confirmController addAction:confirmAction];

        if (confirmController.popoverPresentationController != nil) {
            [confirmController.popoverPresentationController
                setSourceView:submitButton];
            [confirmController.popoverPresentationController
                setSourceRect:submitButton.bounds];
        }

        [self presentViewController:confirmController
                           animated:YES
                         completion:nil];

    } else {
        UIAlertController *subscribersOnlyController = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"Action not available",
                                                       nil)
                             message:
                                 NSLocalizedString(
                                     @"Request undo is a feature available to "
                                     @"subscribers only.",
                                     nil)
                      preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction =
            [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil)
                                     style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction *action){
                                   }];
        UIAlertAction *subscribeAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"subscription info", nil)
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
                        ((PenteNavigationViewController *)
                             self.navigationController)
                            .showSubscribe = YES;
                        [self.navigationController
                            popToRootViewControllerAnimated:YES];
                    }];
        [subscribersOnlyController addAction:cancelAction];
        [subscribersOnlyController addAction:subscribeAction];

        if (subscribersOnlyController.popoverPresentationController != nil) {
            [subscribersOnlyController.popoverPresentationController
                setSourceView:submitButton];
            [subscribersOnlyController.popoverPresentationController
                setSourceRect:submitButton.bounds];
        }

        [self presentViewController:subscribersOnlyController
                           animated:YES
                         completion:nil];
    }
}

- (void)presentUndoOptions {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"Undo requested", nil)
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *acceptAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"Accept", nil)
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {
                    PenteNavigationViewController *navControllor =
                        (PenteNavigationViewController *)
                            self.navigationController;
                    NSError *error = nil;
                    NSURLResponse *response;
                    NSMutableURLRequest *request =
                        [[NSMutableURLRequest alloc] init];

                    NSString *post = [NSString
                        stringWithFormat:@"gid=%@&command=acceptUndo&mobile=",
                                         [self.game gameID]];
                    NSData *postData =
                        [post dataUsingEncoding:NSASCIIStringEncoding
                            allowLossyConversion:YES];
                    NSString *postLength = [NSString
                        stringWithFormat:@"%lu",
                                         (unsigned long)[postData length]];

                    NSURL *url =
                        [NSURL URLWithString:
                                   @"https://www.pente.org/gameServer/tb/game"];
                    if (development) {
                        url =
                            [NSURL URLWithString:
                                       @"https://localhost/gameServer/tb/game"];
                    }
                    [request setURL:url];
                    [request setHTTPMethod:@"POST"];
                    [request setValue:postLength
                        forHTTPHeaderField:@"Content-Length"];
                    [request setValue:@"application/x-www-form-urlencoded"
                        forHTTPHeaderField:@"Content-Type"];
                    [request setHTTPBody:postData];
                    [request setTimeoutInterval:7.0f];

                    [request setHTTPShouldUsePipelining:YES];

                    __weak typeof(self) weakSelf = self;
                    [PenteHTTPClient
                        sendRequest:request
                         completion:^(NSData *responseData,
                                      NSURLResponse *response, NSError *error) {
                             if (error) {
                                 UIAlertView *alert = [[UIAlertView alloc]
                                         initWithTitle:NSLocalizedString(
                                                           @"Error", nil)
                                               message:
                                                   [NSString
                                                       stringWithFormat:
                                                           NSLocalizedString(
                                                               @"Reason: %@",
                                                               nil),
                                                           error
                                                               .localizedDescription]
                                              delegate:nil
                                     cancelButtonTitle:@"OK"
                                     otherButtonTitles:nil];
                                 [alert show];
                                 return;
                             }
                             [navControllor setDidMove:YES];
                             [weakSelf.navigationController
                                 popToRootViewControllerAnimated:YES];
                         }];
                }];
    UIAlertAction *declineAction = [UIAlertAction
        actionWithTitle:NSLocalizedString(@"Decline", nil)
                  style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *action) {
                    //                                                             PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
                    NSError *error = nil;
                    NSURLResponse *response;
                    NSMutableURLRequest *request =
                        [[NSMutableURLRequest alloc] init];

                    NSString *post = [NSString
                        stringWithFormat:@"gid=%@&command=declineUndo&mobile=",
                                         [self.game gameID]];
                    NSData *postData =
                        [post dataUsingEncoding:NSASCIIStringEncoding
                            allowLossyConversion:YES];
                    NSString *postLength = [NSString
                        stringWithFormat:@"%lu",
                                         (unsigned long)[postData length]];

                    NSURL *url =
                        [NSURL URLWithString:
                                   @"https://www.pente.org/gameServer/tb/game"];
                    if (development) {
                        url =
                            [NSURL URLWithString:
                                       @"https://localhost/gameServer/tb/game"];
                    }
                    [request setURL:url];
                    [request setHTTPMethod:@"POST"];
                    [request setValue:postLength
                        forHTTPHeaderField:@"Content-Length"];
                    [request setValue:@"application/x-www-form-urlencoded"
                        forHTTPHeaderField:@"Content-Type"];
                    [request setHTTPBody:postData];
                    [request setTimeoutInterval:7.0f];

                    [request setHTTPShouldUsePipelining:YES];

                    __weak typeof(self) weakSelf = self;
                    [PenteHTTPClient
                        sendRequest:request
                         completion:^(NSData *responseData,
                                      NSURLResponse *response, NSError *error) {
                             if (error) {
                                 UIAlertView *alert = [[UIAlertView alloc]
                                         initWithTitle:NSLocalizedString(
                                                           @"Error", nil)
                                               message:
                                                   [NSString
                                                       stringWithFormat:
                                                           NSLocalizedString(
                                                               @"Reason: %@",
                                                               nil),
                                                           error
                                                               .localizedDescription]
                                              delegate:nil
                                     cancelButtonTitle:@"OK"
                                     otherButtonTitles:nil];
                                 [alert show];
                                 return;
                             }
                             [weakSelf replayGame];
                         }];
                }];

    [alert addAction:acceptAction];
    [alert addAction:declineAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView:playerStats];
        [alert.popoverPresentationController setSourceRect:playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)toDB {
    //    NSLog(@"%d",lastMove);
    PenteNavigationViewController *navController =
        (PenteNavigationViewController *)self.navigationController;
    if (!isGoGame) {
        [[NSUserDefaults standardUserDefaults] setObject:[self.game gameType]
                                                  forKey:@"DBGame"];
    }
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"MainStoryboard"
                                                 bundle:nil];
    DatabaseViewController *vc = (DatabaseViewController *)[sb
        instantiateViewControllerWithIdentifier:@"databaseViewController"];
    [vc setMovesList:[[movesList subarrayWithRange:NSMakeRange(0, lastMove)]
                         mutableCopy]];
    [vc setGame:[self.game gameType]];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)syncCapturesToEngine {
    // Legacy ObjC PenteGame drives the interactive tentative-placement capture
    // preview only; point it at the controller's abstractBoard ivar here (the
    // viewDidLoad alias was removed in this phase). Removed entirely in Phase 5.
    penteGame.abstractBoard = abstractBoard;
    penteGame.captures = captures;
    penteGame.whiteCaptures = whiteCaptures;
    penteGame.blackCaptures = blackCaptures;
}

// Fills the abstractBoard ivar from the Swift engine (the render seam, scope (c)).
//
// The engine masks the opening restriction (centre 5x5 -1 cells, emitted only at
// exactly two played moves) intrinsically for every tournament/G-Pente variant.
// Legacy only ever SHOWED that mask when the game was rated or (speed) G-Pente,
// and only while it stood at exactly two moves (the deleted replay* methods gated
// on `[[self.game ratedNot] ... != "Not Rated"] && [movesList count] == 2`, with
// G-Pente masking on the move count alone). The rated/(speed)gPente half of this
// gate is the SAME policy as `Table.syncFromEngine`. The `&& [movesList count] == 2`
// half is ADDITIONAL here and intentionally NOT in Table: this view replays arbitrary
// history positions (stepping back through a finished game), so it must suppress the
// mask except at the 2-move position to reproduce legacy; `Table` is live-play only
// (it always renders the latest position), so the engine's own `moveCount == 2`
// mask guard already covers it without an explicit count check. Net effect: unrated,
// non-gPente Pente/Keryo/Poof/O-Pente games no longer surface the centre restriction.
- (void)loadEngineIntoAbstractBoard {
    BOOL rated = [[self.game ratedNot] rangeOfString:@"Not Rated"].location ==
                 NSNotFound;
    BOOL isGPente = [[self.game gameType] isEqualToString:@"G-Pente"] ||
                    [[self.game gameType] isEqualToString:@"Speed G-Pente"];
    BOOL maskAllowed = (rated || isGPente) && ([movesList count] == 2);
    for (int rc = 0; rc < gridSize * gridSize; ++rc) {
        int v = (int)[engine stoneAt:rc];
        abstractBoard[rc / gridSize][rc % gridSize] =
            (v == -1 && !maskAllowed) ? 0 : v;
    }
}

// Parses the full move list into rowCol ints for SwiftPenteGame replay:until:.
- (NSArray<NSNumber *> *)parsedMoves {
    NSMutableArray<NSNumber *> *parsed =
        [NSMutableArray arrayWithCapacity:[movesList count]];
    for (NSString *m in movesList) {
        [parsed addObject:@([self parseMove:m])];
    }
    return parsed;
}

- (void)syncCapturesFromEngine {
    whiteCaptures = penteGame.whiteCaptures;
    blackCaptures = penteGame.blackCaptures;
}

- (void)replayGame:(int)untilMove {
    [board setLastConnect6Move:-1];
    [zoomedBoard setLastConnect6Move:-1];
    [board setLastMove:-1];
    [zoomedBoard setLastMove:-1];
    whiteCaptures = 0;
    blackCaptures = 0;
    [self resetBoard];

    if (isGoGame) {
        // Go is out of scope for the engine — it keeps its own replay path.
        lastReplayWinner = 0;
        [self replayGoGame:untilMove];
        [self updateCaptures];
    } else {
        PenteVariant variant =
            [BoardVariantMapping variantForGameType:[self.game gameType]];

        // Opening flags — preserved verbatim from the deleted per-variant methods.
        if (variant == PenteVariantDPente || variant == PenteVariantDkPente) {
            dPenteOpening = ([movesList count] == 0);
        } else if (variant == PenteVariantSwap2Pente ||
                   variant == PenteVariantSwap2Keryo) {
            swap2Opening = ([movesList count] == 0 ||
                            ([movesList count] == 3 && swap2Pass));
        }

        // RISK 1: re-create the engine for THIS variant. The engine's ruleset
        // (captures, win threshold, opening mask, colour cadence) is fixed at
        // init; [engine reset] only clears board/counters. Without this the
        // viewDidLoad placeholder (PenteVariantPente) would mis-rule every other
        // variant. Cheap to re-alloc per replay.
        engine = [[SwiftPenteGame alloc] initWithVariant:variant];

        // RISK 2: feed the move list straight through, matching legacy
        // -replayMoves:variant:untilMove: (PenteGame.m), which placed every entry
        // unconditionally and never filtered a pass/-1 sentinel. For all Pente
        // engine variants movesList holds valid board coords (0..360); passes are
        // Go-only (handled above) and Swap2's pass is an out-of-band flag, never a
        // move-list entry. Filtering here would shift the colour cadence and
        // diverge from legacy, so we do NOT filter.
        MoveResult *result = [engine replay:[self parsedMoves] until:untilMove];
        lastReplayWinner = (int)result.winner;
        whiteCaptures = (int)engine.whiteCaptures;
        blackCaptures = (int)engine.blackCaptures;
        [captures removeAllObjects];

        BOOL boat = [[self.game gameType] isEqualToString:@"Boat-Pente"];
        UIColor *bg = [BoardVariantMapping backgroundColorForVariant:variant
                                                           boatPente:boat];
        [board setBackgroundColor:bg];
        [zoomedBoard setBackgroundColor:bg];

        // RISK 3: 19x19 engine path only — Go (gridSize 9/13) handled above.
        [self loadEngineIntoAbstractBoard];
        [board setAbstractBoard:abstractBoard];

        [self updateCaptures];
        if ([BoardVariantMapping hidesCaptureLabelsForVariant:variant
                                                      opening:dPenteOpening]) {
            [whiteStoneCaptures setHidden:YES];
            [whiteCapturesCountLabel setHidden:YES];
            [blackStoneCaptures setHidden:YES];
            [blackCapturesCountLabel setHidden:YES];
        }

        BOOL atLatest = (lastMove == [movesList count]);
        BOOL syncZoom = (variant == PenteVariantConnect6) || atLatest;
        if (syncZoom) {
            [zoomedBoard setAbstractBoard:abstractBoard];
        }

        if (untilMove > 0) {
            int last = [self parseMove:[movesList objectAtIndex:untilMove - 1]];
            [board setLastMove:last];
            if (syncZoom) {
                [zoomedBoard setLastMove:last];
            }
        }

        if (variant == PenteVariantConnect6) {
            if (untilMove > 1) {
                int prev =
                    [self parseMove:[movesList objectAtIndex:untilMove - 2]];
                [board setLastConnect6Move:prev];
                [zoomedBoard setLastConnect6Move:prev];
            } else {
                [board setLastConnect6Move:-1];
                [zoomedBoard setLastConnect6Move:-1];
            }
        }
    }

    isLastMove = (untilMove == [movesList count]);
    [messageButtonImageView stopAnimating];
    if ([messagesHistory
            objectForKey:[NSString stringWithFormat:@"%i", untilMove]]) {
        [self notifyNewMessage];
        if (([[self.game myColor] isEqualToString:@"white"] &&
             ((untilMove % 2) == 1)) ||
            ([[self.game myColor] isEqualToString:@"black"] &&
             ((untilMove % 2) == 0))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue"
                                                         size:15.35f]];
            receivedMessage = [NSString
                stringWithFormat:
                    @" me: %@",
                    [messagesHistory
                        objectForKey:[NSString
                                         stringWithFormat:@"%i", untilMove]]];
        } else {
            [receivedMessageView
                setFont:[UIFont fontWithName:@"HelveticaNeue-Bold"
                                        size:15.35f]];
            receivedMessage = [NSString
                stringWithFormat:
                    @" %@: %@", [self.game opponentName],
                    [messagesHistory
                        objectForKey:[NSString
                                         stringWithFormat:@"%i", untilMove]]];
        }
        if (([[self.game gameType] isEqualToString:@"Connect6"] &&
             [[self.game myColor] isEqualToString:@"white"] &&
             ((untilMove % 4) == 1)) ||
            ([[self.game gameType] isEqualToString:@"Connect6"] &&
             [[self.game myColor] isEqualToString:@"black"] &&
             ((untilMove % 4) == 3))) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue"
                                                         size:15.35f]];
            receivedMessage = [NSString
                stringWithFormat:
                    @" me: %@",
                    [messagesHistory
                        objectForKey:[NSString
                                         stringWithFormat:@"%i", untilMove]]];
        } else if ([[self.game gameType] isEqualToString:@"Connect6"]) {
            [receivedMessageView
                setFont:[UIFont fontWithName:@"HelveticaNeue-Bold"
                                        size:15.35f]];
            receivedMessage = [NSString
                stringWithFormat:
                    @" %@: %@", [self.game opponentName],
                    [messagesHistory
                        objectForKey:[NSString
                                         stringWithFormat:@"%i", untilMove]]];
        }
        if (isGoGame) {
            [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue"
                                                         size:15.35f]];
            if (([[self.game myColor] isEqualToString:@"black"] &&
                 ((untilMove % 2) == 1)) ||
                ([[self.game myColor] isEqualToString:@"white"] &&
                 ((untilMove % 2) == 0))) {
                receivedMessage = [NSString
                    stringWithFormat:
                        @" me: %@",
                        [messagesHistory
                            objectForKey:[NSString
                                             stringWithFormat:@"%lu",
                                                              (unsigned long)
                                                                  untilMove]]];
            } else {
                [receivedMessageView
                    setFont:[UIFont fontWithName:@"HelveticaNeue-Bold"
                                            size:15.35f]];
                receivedMessage = [NSString
                    stringWithFormat:
                        @" %@: %@", [self.game opponentName],
                        [messagesHistory
                            objectForKey:[NSString
                                             stringWithFormat:@"%lu",
                                                              (unsigned long)
                                                                  untilMove]]];
            }
        }
        [receivedMessageView setText:receivedMessage];
    } else {
        receivedMessage = @"";
        [receivedMessageView setText:receivedMessage];
    }
    CGRect frame = receivedMessageView.frame;
    frame.origin.y = 568;

    NSDictionary *fontAttributes =
        [NSDictionary dictionaryWithObject:[receivedMessageView font]
                                    forKey:NSFontAttributeName];
    [self.view addSubview:receivedMessageView];
    CGRect textFrame = [receivedMessage
        boundingRectWithSize:CGSizeMake(
                                 receivedMessageView.contentSize.width +
                                     receivedMessageView.contentOffset.x -
                                     receivedMessageView.contentInset.left -
                                     receivedMessageView.contentInset.right,
                                 receivedMessageView.font.lineHeight * 5)
                     options:(NSStringDrawingUsesLineFragmentOrigin |
                              NSLineBreakByWordWrapping)
                  attributes:fontAttributes
                     context:nil];
    [receivedMessageView setText:receivedMessage];
    [receivedMessageView setFrame:frame];

    if (textFrame.size.height < (3 * receivedMessageView.font.lineHeight)) {
        frame.size.height = textFrame.size.height;
    } else {
        frame.size.height =
            MIN((receivedMessageView.font.lineHeight * 5),
                textFrame.size.height - receivedMessageView.contentInset.top);
    }
    [receivedMessageView removeFromSuperview];
    [receivedMessageView setFrame:frame];

    moveStatsString = [[NSMutableString alloc] init];
    for (int i = 0; i < lastMove; ++i) {
        int rowCol = [self parseMove:[movesList objectAtIndex:i]];
        if (i == 0) {
            [moveStatsString appendString:@"<b>1.</b> "];
        } else if ([[self.game gameType] isEqualToString:@"Connect6"]) {
            if (((i - 3) % 4) == 0) {
                [moveStatsString
                    appendString:[NSString
                                     stringWithFormat:@"&nbsp; <b>%i.</b> ",
                                                      (i >> 2) + 2]];
            } else if (((i - 3) % 4) == 2 || i == 1) {
                [moveStatsString appendString:@" - "];
            } else {
                [moveStatsString appendString:@"-"];
            }
        } else {
            if ((i % 2) == 0) {
                [moveStatsString
                    appendString:[NSString
                                     stringWithFormat:@"&nbsp; <b>%i.</b> ",
                                                      (i >> 1) + 1]];
            } else {
                [moveStatsString appendString:@" - "];
            }
        }
        if (rowCol < gridSize * gridSize) {
            [moveStatsString
                appendString:[NSString
                                 stringWithFormat:@"%c%d",
                                                  coordinateLetters[rowCol %
                                                                    gridSize],
                                                  gridSize -
                                                      (rowCol / gridSize)]];
        } else {
            [moveStatsString appendString:@"PASS"];
        }
    }
    [playerStats
        loadHTMLString:[HEADERSTRING
                           stringByAppendingString:
                               [playerStatsBaseString
                                   stringByAppendingString:moveStatsString]]
               baseURL:nil];

    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
}

- (void)replayGoGame:(int)untilMove {
    GoGame *goGame = [[GoGame alloc] initWithGridSize:gridSize];
    NSMutableArray<NSNumber *> *moveInts = [NSMutableArray array];
    for (int i = 0; i < [movesList count]; ++i) {
        [moveInts addObject:@([self parseMove:[movesList objectAtIndex:i]])];
    }
    [goGame replay:moveInts until:untilMove];

    deadBlackStones = [[goGame blackDeadStones] mutableCopy];
    deadWhiteStones = [[goGame whiteDeadStones] mutableCopy];

    for (int pos = 0; pos < gridSize * gridSize; ++pos) {
        [self setValue:(int)[goGame stoneAt:pos] forPosition:pos];
    }
    koMove = (int)[goGame koMove];

    [board setBlackDeadStones:deadBlackStones];
    [board setWhiteDeadStones:deadWhiteStones];
    [zoomedBoard setBlackDeadStones:deadBlackStones];
    [zoomedBoard setWhiteDeadStones:deadWhiteStones];
    [board setBackgroundColor:[UIColor colorWithRed:250.0 / 255
                                              green:200.0 / 255
                                               blue:50.0 / 255
                                              alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:250.0 / 255
                                                    green:200.0 / 255
                                                     blue:50.0 / 255
                                                    alpha:1]];
    [board setAbstractBoard:abstractBoard];
    if (untilMove > 0) {
        [board setLastMove:[self parseMove:[movesList
                                               objectAtIndex:untilMove - 1]]];
    }
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard:abstractBoard];
        if (untilMove > 0) {
            [zoomedBoard
                setLastMove:[self parseMove:[movesList
                                                objectAtIndex:untilMove - 1]]];
        }
    }
    //    NSLog(@"koMove %d", koMove);
    if (koMove > -1) {
        [self setValue:-1 forPosition:koMove];
    }
}

- (void)
    makeCapturesWithMove:(int)move
              withGroups:
                  (NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *>
                       *)groupsByID
                  andIDs:(NSMutableDictionary<NSNumber *, NSNumber *> *)
                             stoneGroupIDs
          andAlterGroups:(BOOL)alter {
    int captures = 0;
    koMove = -1;

    if (move % gridSize != 0) {
        int neighborStone = move - 1;
        NSNumber *neighborStoneID =
            [stoneGroupIDs objectForKey:[NSNumber numberWithInt:neighborStone]];
        captures = [self getCapturesOfMove:move
                                withGroups:groupsByID
                                    andIDs:stoneGroupIDs
                                  captures:captures
                             neighborStone:neighborStone
                           neighborStoneID:neighborStoneID
                            andAlterGroups:alter];
    }
    if (move % gridSize != gridSize - 1) {
        int neighborStone = move + 1;
        NSNumber *neighborStoneID =
            [stoneGroupIDs objectForKey:[NSNumber numberWithInt:neighborStone]];
        captures = [self getCapturesOfMove:move
                                withGroups:groupsByID
                                    andIDs:stoneGroupIDs
                                  captures:captures
                             neighborStone:neighborStone
                           neighborStoneID:neighborStoneID
                            andAlterGroups:alter];
    }
    if (move / gridSize != 0) {
        int neighborStone = move - gridSize;
        NSNumber *neighborStoneID =
            [stoneGroupIDs objectForKey:[NSNumber numberWithInt:neighborStone]];
        captures = [self getCapturesOfMove:move
                                withGroups:groupsByID
                                    andIDs:stoneGroupIDs
                                  captures:captures
                             neighborStone:neighborStone
                           neighborStoneID:neighborStoneID
                            andAlterGroups:alter];
    }
    if (move / gridSize != gridSize - 1) {
        int neighborStone = move + gridSize;
        NSNumber *neighborStoneID =
            [stoneGroupIDs objectForKey:[NSNumber numberWithInt:neighborStone]];
        captures = [self getCapturesOfMove:move
                                withGroups:groupsByID
                                    andIDs:stoneGroupIDs
                                  captures:captures
                             neighborStone:neighborStone
                           neighborStoneID:neighborStoneID
                            andAlterGroups:alter];
    }
}
- (void)setValue:(int)val forPosition:(int)pos {
    int i = pos / gridSize, j = pos % gridSize;
    abstractBoard[i][j] = val;
}
- (int)getBoardValue:(int)pos {
    int i = pos / gridSize, j = pos % gridSize;
    return abstractBoard[i][j];
}
- (int)
    getCapturesOfMove:(int)move
           withGroups:
               (NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *)
                   groupsByID
               andIDs:
                   (NSMutableDictionary<NSNumber *, NSNumber *> *)stoneGroupIDs
             captures:(int)captures
        neighborStone:(int)neighborStone
      neighborStoneID:(NSNumber *)neighborStoneID
       andAlterGroups:(BOOL)alter {
    int newCaptures = captures;
    if (neighborStoneID) {
        NSArray<NSNumber *> *neighborStoneGroup =
            [groupsByID objectForKey:neighborStoneID];
        if (![self groupHasLiberties:neighborStoneGroup]) {
            if (alter) {
                if (koMove < 0 && [neighborStoneGroup count] == 1 &&
                    [self checkKo:move]) {
                    koMove = neighborStone;
                    //                    NSLog(@"komove check %d", koMove);
                } else if (alter) {
                    koMove = -1;
                }
            }
            newCaptures += [neighborStoneGroup count];
            [self captureGroup:neighborStoneID
                    withGroups:groupsByID
                        andIDs:stoneGroupIDs
                andAlterGroups:alter];
        }
    }
    return newCaptures;
}
- (BOOL)checkKo:(int)move {
    int position = [self getBoardValue:move];

    if (move % gridSize != 0) {
        int neighborStone = move - 1;
        int neighborPosition = [self getBoardValue:neighborStone];
        if (position != 3 - neighborPosition) {
            return NO;
        }
    }
    if (move % gridSize != gridSize - 1) {
        int neighborStone = move + 1;
        int neighborPosition = [self getBoardValue:neighborStone];
        if (position != 3 - neighborPosition) {
            return NO;
        }
    }
    if (move / gridSize != 0) {
        int neighborStone = move - gridSize;
        int neighborPosition = [self getBoardValue:neighborStone];
        if (position != 3 - neighborPosition) {
            return NO;
        }
    }
    if (move / gridSize != gridSize - 1) {
        int neighborStone = move + gridSize;
        int neighborPosition = [self getBoardValue:neighborStone];
        if (position != 3 - neighborPosition) {
            return NO;
        }
    }
    return YES;
}
- (void)captureGroup:(NSNumber *)groupID
          withGroups:
              (NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *)
                  groupsByID
              andIDs:
                  (NSMutableDictionary<NSNumber *, NSNumber *> *)stoneGroupIDs
      andAlterGroups:(BOOL)alter {
    NSArray<NSNumber *> *group = [groupsByID objectForKey:groupID];
    if ([group count] > 0) {
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
- (BOOL)groupHasLiberties:(NSArray<NSNumber *> *)group {
    for (NSNumber *stone in group) {
        if ([self stoneHasLiberties:stone.intValue]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)stoneHasLiberties:(int)stone {
    if (stone % gridSize != 0) {
        int neighborStone = stone - 1;
        int neighborStonePos = [self getBoardValue:neighborStone];
        if (neighborStonePos != 1 && neighborStonePos != 2) {
            return YES;
        }
    }
    if (stone % gridSize != gridSize - 1) {
        int neighborStone = stone + 1;
        int neighborStonePos = [self getBoardValue:neighborStone];
        if (neighborStonePos != 1 && neighborStonePos != 2) {
            return YES;
        }
    }
    if (stone / gridSize != 0) {
        int neighborStone = stone - gridSize;
        int neighborStonePos = [self getBoardValue:neighborStone];
        if (neighborStonePos != 1 && neighborStonePos != 2) {
            return YES;
        }
    }
    if (stone / gridSize != gridSize - 1) {
        int neighborStone = stone + gridSize;
        int neighborStonePos = [self getBoardValue:neighborStone];
        if (neighborStonePos != 1 && neighborStonePos != 2) {
            return YES;
        }
    }
    return NO;
}
- (void)settleGroups:
            (NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *)
                groupsByID
              andIDs:
                  (NSMutableDictionary<NSNumber *, NSNumber *> *)stoneGroupIDs
             forMove:(int)move {
    NSMutableArray *newGroup = [[NSMutableArray alloc] init];
    NSNumber *moveNumber = [NSNumber numberWithInt:move];
    [newGroup addObject:moveNumber];
    [stoneGroupIDs setObject:moveNumber forKey:moveNumber];
    [groupsByID setObject:newGroup forKey:moveNumber];

    if (move % gridSize != 0) {
        int neighborStone = move - 1;
        NSNumber *neighborStoneID =
            [stoneGroupIDs objectForKey:[NSNumber numberWithInt:neighborStone]];
        if (neighborStoneID) {
            [self mergeGroup1:moveNumber
                   withGroup2:neighborStoneID
                   withGroups:groupsByID
                       andIDs:stoneGroupIDs];
        }
    }
    if (move % gridSize != gridSize - 1) {
        int neighborStone = move + 1;
        NSNumber *neighborStoneID =
            [stoneGroupIDs objectForKey:[NSNumber numberWithInt:neighborStone]];
        if (neighborStoneID) {
            [self mergeGroup1:[stoneGroupIDs objectForKey:moveNumber]
                   withGroup2:neighborStoneID
                   withGroups:groupsByID
                       andIDs:stoneGroupIDs];
        }
    }
    if (move / gridSize != 0) {
        int neighborStone = move - gridSize;
        NSNumber *neighborStoneID =
            [stoneGroupIDs objectForKey:[NSNumber numberWithInt:neighborStone]];
        if (neighborStoneID) {
            [self mergeGroup1:[stoneGroupIDs objectForKey:moveNumber]
                   withGroup2:neighborStoneID
                   withGroups:groupsByID
                       andIDs:stoneGroupIDs];
        }
    }
    if (move / gridSize != gridSize - 1) {
        int neighborStone = move + gridSize;
        NSNumber *neighborStoneID =
            [stoneGroupIDs objectForKey:[NSNumber numberWithInt:neighborStone]];
        if (neighborStoneID) {
            [self mergeGroup1:[stoneGroupIDs objectForKey:moveNumber]
                   withGroup2:neighborStoneID
                   withGroups:groupsByID
                       andIDs:stoneGroupIDs];
        }
    }
}

- (void)mergeGroup1:(NSNumber *)group1
         withGroup2:(NSNumber *)group2
         withGroups:
             (NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *)
                 groupsByID
             andIDs:
                 (NSMutableDictionary<NSNumber *, NSNumber *> *)stoneGroupIDs {
    if (group1.intValue == group2.intValue) {
        return;
    }
    NSMutableArray<NSNumber *> *oldGroup, *newGroup;
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
    [groupsByID removeObjectForKey:oldGroupID];
    [newGroup addObjectsFromArray:oldGroup];
    for (NSNumber *oldStone in oldGroup) {
        [stoneGroupIDs setObject:newGroupID forKey:oldStone];
    }
}

- (void)copyGoBoard {
    int currentOpponent = 2 - [movesList count] % 2;
    goStoneGroups = [[NSMutableDictionary alloc]
        initWithDictionary:[goStoneGroupsByPlayerAndID
                               objectForKey:[NSNumber
                                                numberWithInt:currentOpponent]]
                 copyItems:YES];
    goStoneGroupIDs = [[NSMutableDictionary alloc]
        initWithDictionary:[goStoneGroupIDsByPlayer
                               objectForKey:[NSNumber
                                                numberWithInt:currentOpponent]]
                 copyItems:YES];
    for (int i = 0; i < gridSize; ++i) {
        for (int j = 0; j < gridSize; ++j) {
            abstractGoBoard[i][j] = abstractBoard[i][j];
        }
    }
}

- (void)copyGoBoardBack {
    for (int i = 0; i < gridSize; ++i) {
        for (int j = 0; j < gridSize; ++j) {
            abstractBoard[i][j] = abstractGoBoard[i][j];
        }
    }
}

// NOTE (Go migration): replayGoGame: routes through the Swift GoGame engine, but this
// interactive path still uses the ObjC Go helpers below (makeCapturesWithMove:/settleGroups:/etc.).
// Fully migrating interactive Go to GoGame is a future follow-up.
- (void)addGoMove:(int)move {
    int currentPlayer = 1 + [movesList count] % 2;
    int color = 3 - currentPlayer;
    [self copyGoBoardBack];
    [self setValue:color forPosition:move];
    [self makeCapturesWithMove:move
                    withGroups:goStoneGroups
                        andIDs:goStoneGroupIDs
                andAlterGroups:NO];
    [board setNeedsDisplay];
}

- (void)processDeadStone:(int)move {
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

- (void)resetGoBoardBeforeFlood {
    for (int i = 0; i < gridSize; ++i) {
        for (int j = 0; j < gridSize; ++j) {
            int pos = abstractBoard[i][j];
            if (pos != 1 && pos != 2) {
                abstractBoard[i][j] = 0;
            }
        }
    }
}

- (int)getEmpyNeighbor:(int)move {

    if (move % gridSize != 0) {
        int neighborStone = move - 1;
        if ([self getBoardValue:neighborStone] == 0) {
            return neighborStone;
        }
    }
    if (move % gridSize != gridSize - 1) {
        int neighborStone = move + 1;
        if ([self getBoardValue:neighborStone] == 0) {
            return neighborStone;
        }
    }
    if (move / gridSize != 0) {
        int neighborStone = move - gridSize;
        if ([self getBoardValue:neighborStone] == 0) {
            return neighborStone;
        }
    }
    if (move / gridSize != gridSize - 1) {
        int neighborStone = move + gridSize;
        if ([self getBoardValue:neighborStone] == 0) {
            return neighborStone;
        }
    }
    return -1;
}

- (NSMutableArray<NSNumber *> *)getMovesForValue:(int)val {
    NSMutableArray<NSNumber *> *result = [[NSMutableArray alloc] init];
    for (int i = 0; i < gridSize; ++i) {
        for (int j = 0; j < gridSize; ++j) {
            if (abstractBoard[i][j] == val) {
                [result addObject:[NSNumber numberWithInt:(i * gridSize + j)]];
            }
        }
    }
    return result;
}

- (void)floodForPlayer:(int)player {
    for (int move = 0; move < gridSize * gridSize; ++move) {
        if ([self getBoardValue:move] == 3 - player) {
            int emptyNeighbor = [self getEmpyNeighbor:move];
            while (emptyNeighbor > -1) {
                [self floodFillWorkerWithMove:emptyNeighbor
                                     andValue:player + 2];
                emptyNeighbor = [self getEmpyNeighbor:move];
            }
        }
    }
}

- (void)showTerritory:(id)sender {
    [self floodForPlayer:1];
    blackTerritory = [self getMovesForValue:3];
    [self resetGoBoardBeforeFlood];
    [self floodForPlayer:2];
    whiteTerritory = [self getMovesForValue:4];
    [self resetGoBoardBeforeFlood];

    int i = (int)[blackTerritory count] - 1,
        j = (int)[whiteTerritory count] - 1;
    while (i > -1 && j > -1) {
        int p1Stone = [blackTerritory objectAtIndex:i].intValue,
            p2Stone = [whiteTerritory objectAtIndex:j].intValue;
        if (p1Stone == p2Stone) {
            [blackTerritory removeObjectAtIndex:i];
            [whiteTerritory removeObjectAtIndex:j];
            --i;
            --j;
        } else if (p1Stone > p2Stone) {
            --i;
        } else {
            --j;
        }
    }

    [board setWhiteTerritory:whiteTerritory];
    [board setBlackTerritory:blackTerritory];
    [zoomedBoard setWhiteTerritory:whiteTerritory];
    [zoomedBoard setBlackTerritory:blackTerritory];
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
}

- (void)floodFillWorkerWithMove:(int)move andValue:(int)val {
    [self setValue:val forPosition:move];
    int neighbor = [self getEmpyNeighbor:move];
    while (neighbor > -1) {
        [self floodFillWorkerWithMove:neighbor andValue:val];
        neighbor = [self getEmpyNeighbor:move];
    }
}

- (void)showScore {
    [self showTerritory:nil];
    int whiteT = [whiteTerritory count], blackT = [blackTerritory count],
        whiteS = [[self getMovesForValue:1] count],
        blackS = [[self getMovesForValue:2] count];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"score", nil)
                         message:[NSString
                                     stringWithFormat:
                                         @"black: %i + %i = %i\nwhite: 7.5 "
                                         @"+ %i + %i = %i.5",
                                         blackT, blackS, blackT + blackS,
                                         whiteT, whiteS, whiteT + whiteS + 7]
                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *dismissAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"dismiss", nil)
                                 style:UIAlertActionStyleCancel
                               handler:^(UIAlertAction *action) {
                                   if (!goMarkStones) {

                                       [blackTerritory removeAllObjects];
                                       [whiteTerritory removeAllObjects];
                                       [board setNeedsDisplay];
                                       [zoomedBoard setNeedsDisplay];
                                   }
                               }];
    [alert addAction:dismissAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView:playerStats];
        [alert.popoverPresentationController setSourceRect:playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)evaluateDeadStones {
    [self showTerritory:nil];
    int whiteT = [whiteTerritory count], blackT = [blackTerritory count],
        whiteS = [[self getMovesForValue:1] count],
        blackS = [[self getMovesForValue:2] count];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:
            [NSString stringWithFormat:
                          @"black: %i + %i = %i\nwhite: 7.5 + %i + %i = %i.5",
                          blackT, blackS, blackT + blackS, whiteT, whiteS,
                          whiteT + whiteS + 7]
                         message:nil
                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *acceptAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"accept", nil)
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                   finalMove = 1;
                                   [self submitMove:nil];
                               }];
    UIAlertAction *rejectAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"reject", nil)
                                 style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action) {
                                   finalMove = 0;
                                   [self submitMove:nil];
                               }];
    [alert addAction:acceptAction];
    [alert addAction:rejectAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView:playerStats];
        [alert.popoverPresentationController setSourceRect:playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)detectCaptureOfOpponent:(int)opponentColor atPosition:(int)rowCol {
    [self syncCapturesToEngine];
    [penteGame detectCaptureOfOpponent:opponentColor atPosition:rowCol];
    [self syncCapturesFromEngine];
}

- (void)detectKeryoCaptureOfOpponent:(int)opponentColor atPosition:(int)rowCol {
    [self syncCapturesToEngine];
    [penteGame detectKeryoCaptureOfOpponent:opponentColor atPosition:rowCol];
    [self syncCapturesFromEngine];
}

- (BOOL)detectPoof:(int)myColor atPosition:(int)rowCol {
    [self syncCapturesToEngine];
    BOOL poof = [penteGame detectPoof:myColor atPosition:rowCol];
    [self syncCapturesFromEngine];
    return poof;
}

- (BOOL)detectKeryoPoof:(int)myColor atPosition:(int)rowCol {
    [self syncCapturesToEngine];
    BOOL poof = [penteGame detectKeryoPoof:myColor atPosition:rowCol];
    [self syncCapturesFromEngine];
    return poof;
}

- (BOOL)detectPenteOf:(int)color atPosition:(int)rowCol {
    return [penteGame detectPenteOf:color atPosition:rowCol];
}

- (int)parseMove:(NSString *)move {
    return [move intValue];
    //    int col = [move characterAtIndex: 0] - 65;
    //    col = (col < 8) ? col : --col;
    //    int row = 19 - [[move substringWithRange:NSMakeRange(1,[move length] -
    //    1)] intValue]; return row*19 + col;
}

- (void)resetBoard {
    finalMove = -1;
    // Zero the abstractBoard ivar so reset is behavior-neutral for ALL
    // variants. The legacy [penteGame resetBoard] aliased and zeroed this
    // 19x19 board; [engine reset] only clears the Swift engine's internal
    // state, so without this the Go replay path (which never re-zeros
    // abstractBoard) would leave ghost stones when stepping backward.
    memset(abstractBoard, 0, sizeof(abstractBoard));
    [engine reset];
}

- (void)notifyNewMessage {
    [messageButtonImageView setAnimationDuration:1.2];
    [messageButtonImageView startAnimating];
}

- (void)toggleBoardLock:(id)sender {
    UIButton *button = (UIButton *)sender;
    BOOL locked =
        [[NSUserDefaults standardUserDefaults] boolForKey:@"notBack2Dash"];
    if (locked) {
        [button setImage:[UIImage imageNamed:@"unlock.png"]
                forState:UIControlStateNormal];
        [[NSUserDefaults standardUserDefaults] setBool:NO
                                                forKey:@"notBack2Dash"];
    } else {
        [button setImage:[UIImage imageNamed:@"lock.png"]
                forState:UIControlStateNormal];
        [[NSUserDefaults standardUserDefaults] setBool:YES
                                                forKey:@"notBack2Dash"];
    }
}

- (void)messageTap:(id)sender {
    [messageButtonImageView stopAnimating];
    [receivedMessageView flashScrollIndicators];

    messagePopover = [[PopoverView alloc] init];
    [messagePopover setDelegate:self];

    [replyMessageView
        setFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 44)];
    CGPoint showPoint = [self.view convertPoint:messageButton.center
                                       fromView:messageButton];
    showPoint.y = showPoint.y + messageButton.bounds.size.height / 2;
    if (isLastMove) {
        if (activeGame) {
            if (![receivedMessage isEqualToString:@""]) {
                [messagePopover
                      showAtPoint:showPoint
                           inView:self.view
                    withViewArray:[NSArray arrayWithObjects:receivedMessageView,
                                                            replyMessageView,
                                                            nil]];
            } else {
                [replyMessageView
                    setFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40,
                                        88)];
                [messagePopover showAtPoint:showPoint
                                     inView:self.view
                            withContentView:replyMessageView];
            }
            [self.replyMessageView becomeFirstResponder];
        } else if (![receivedMessage isEqualToString:@""]) {
            [messagePopover showAtPoint:showPoint
                                 inView:self.view
                        withContentView:receivedMessageView];
        }
    } else if (![receivedMessage isEqualToString:@""]) {
        [messagePopover showAtPoint:showPoint
                             inView:self.view
                    withContentView:receivedMessageView];
    }
    //    [receivedMessageView sizeToFit];
}

- (void)cancelResignHide {
    if (activeGame) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:NSLocalizedString(@"options", nil)
                             message:nil
                      preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cancelAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"request set cancellation", nil)
                      style:UIAlertActionStyleDefault
                    handler:^(UIAlertAction *action) {
                        UIAlertController *confirmController = [UIAlertController
                            alertControllerWithTitle:NSLocalizedString(
                                                         @"Are you sure?", nil)
                                             message:NSLocalizedString(
                                                         @"Your opponent will "
                                                         @"still have "
                                                         @"to agree to your "
                                                         @"request.",
                                                         nil)
                                      preferredStyle:
                                          UIAlertControllerStyleActionSheet];
                        UIAlertAction *cancelAction = [UIAlertAction
                            actionWithTitle:NSLocalizedString(@"dismiss", nil)
                                      style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction *action){
                                    }];
                        UIAlertAction *confirmAction = [UIAlertAction
                            actionWithTitle:NSLocalizedString(
                                                @"yes, request to cancel set",
                                                nil)
                                      style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction *action) {
                                        NSError *error;

                                        NSString *post = [NSString
                                            stringWithFormat:@"sid=%@&command="
                                                             @"request&mobile=",
                                                             [self.game setID]];
                                        NSData *postData =
                                            [post dataUsingEncoding:
                                                      NSASCIIStringEncoding
                                                allowLossyConversion:YES];
                                        NSString *postLength = [NSString
                                            stringWithFormat:@"%lu",
                                                             (unsigned long)
                                                                 [postData
                                                                     length]];

                                        NSMutableURLRequest *request =
                                            [[NSMutableURLRequest alloc] init];

                                        NSURL *url =
                                            [NSURL URLWithString:
                                                       @"https://www.pente.org/"
                                                       @"gameServer/tb/cancel"];
                                        if (development) {
                                            url = [NSURL
                                                URLWithString:
                                                    @"https://localhost/"
                                                    @"gameServer/tb/cancel"];
                                        }
                                        [request setURL:url];
                                        [request setHTTPMethod:@"POST"];
                                        [request setValue:postLength
                                            forHTTPHeaderField:
                                                @"Content-Length"];
                                        [request setValue:
                                                     @"application/"
                                                     @"x-www-form-urlencoded"
                                            forHTTPHeaderField:@"Content-Type"];
                                        [request setHTTPBody:postData];
                                        [request setTimeoutInterval:7.0];
                                        __weak typeof(self) weakSelf = self;
                                        [PenteHTTPClient
                                            sendRequest:request
                                             completion:^(
                                                 NSData *responseData,
                                                 NSURLResponse *response,
                                                 NSError *error) {
                                                 NSString *dashboardString = [[NSString
                                                     alloc]
                                                     initWithData:responseData
                                                         encoding:
                                                             NSUTF8StringEncoding];
                                                 if ([dashboardString
                                                         containsString:
                                                             @"Error: Cancel "
                                                             @"request already "
                                                             @"exists."]) {
                                                     UIAlertView *alert = [[UIAlertView
                                                         alloc]
                                                             initWithTitle:
                                                                 NSLocalizedString(
                                                                     @"Error",
                                                                     nil)
                                                                   message:
                                                                       NSLocalizedString(
                                                                           @"A "
                                                                           @"ca"
                                                                           @"nc"
                                                                           @"el"
                                                                           @" r"
                                                                           @"eq"
                                                                           @"ue"
                                                                           @"st"
                                                                           @" a"
                                                                           @"lr"
                                                                           @"ea"
                                                                           @"dy"
                                                                           @" e"
                                                                           @"xi"
                                                                           @"st"
                                                                           @"s"
                                                                           @".",
                                                                           nil)
                                                                  delegate:nil
                                                         cancelButtonTitle:
                                                             NSLocalizedString(
                                                                 @"OK", nil)
                                                         otherButtonTitles:nil];
                                                     [alert show];
                                                 } else {
                                                     PenteNavigationViewController
                                                         *navControllor =
                                                             (PenteNavigationViewController
                                                                  *)weakSelf
                                                                 .navigationController;
                                                     [navControllor
                                                         setDidMove:YES];
                                                 }
                                                 [weakSelf.navigationController
                                                     popToRootViewControllerAnimated:
                                                         YES];
                                             }];
                                    }];
                        [confirmController addAction:cancelAction];
                        [confirmController addAction:confirmAction];

                        if (confirmController.popoverPresentationController !=
                            nil) {
                            [confirmController.popoverPresentationController
                                setSourceView:self.submitButton];
                            [confirmController.popoverPresentationController
                                setSourceRect:self.submitButton.bounds];
                        }

                        [self presentViewController:confirmController
                                           animated:YES
                                         completion:nil];
                    }];
        UIAlertAction *resignAction = [UIAlertAction
            actionWithTitle:NSLocalizedString(@"resign game", nil)
                      style:UIAlertActionStyleDestructive
                    handler:^(UIAlertAction *action) {
                        UIAlertController *confirmController = [UIAlertController
                            alertControllerWithTitle:NSLocalizedString(
                                                         @"Are you sure?", nil)
                                             message:
                                                 NSLocalizedString(
                                                     @"Resigning means "
                                                     @"forfeiting the game.",
                                                     nil)
                                      preferredStyle:
                                          UIAlertControllerStyleActionSheet];
                        UIAlertAction *cancelAction = [UIAlertAction
                            actionWithTitle:NSLocalizedString(@"dismiss", nil)
                                      style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction *action){
                                    }];
                        UIAlertAction *confirmAction = [UIAlertAction
                            actionWithTitle:NSLocalizedString(@"yes, resign",
                                                              nil)
                                      style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction *action) {
                                        NSString *post = [NSString
                                            stringWithFormat:@"gid=%@&command="
                                                             @"resign&mobile=",
                                                             [self.game
                                                                     gameID]];
                                        NSData *postData =
                                            [post dataUsingEncoding:
                                                      NSASCIIStringEncoding
                                                allowLossyConversion:YES];
                                        NSString *postLength = [NSString
                                            stringWithFormat:@"%lu",
                                                             (unsigned long)
                                                                 [postData
                                                                     length]];

                                        NSMutableURLRequest *request =
                                            [[NSMutableURLRequest alloc] init];

                                        NSURL *url =
                                            [NSURL URLWithString:
                                                       @"https://www.pente.org/"
                                                       @"gameServer/tb/resign"];
                                        if (development) {
                                            url = [NSURL
                                                URLWithString:
                                                    @"https://localhost/"
                                                    @"gameServer/tb/resign"];
                                        }
                                        [request setURL:url];
                                        [request setHTTPMethod:@"POST"];
                                        [request setValue:postLength
                                            forHTTPHeaderField:
                                                @"Content-Length"];
                                        [request setValue:
                                                     @"application/"
                                                     @"x-www-form-urlencoded"
                                            forHTTPHeaderField:@"Content-Type"];
                                        [request setHTTPBody:postData];
                                        [request setTimeoutInterval:7.0];

                                        [request
                                            setHTTPShouldUsePipelining:YES];

                                        __weak typeof(self) weakSelf = self;
                                        [PenteHTTPClient
                                            sendRequest:request
                                             completion:^(
                                                 NSData *responseData,
                                                 NSURLResponse *response,
                                                 NSError *error) {
                                                 PenteNavigationViewController
                                                     *navControllor =
                                                         (PenteNavigationViewController
                                                              *)weakSelf
                                                             .navigationController;
                                                 [navControllor setDidMove:YES];
                                                 [navControllor
                                                     popToRootViewControllerAnimated:
                                                         YES];
                                             }];
                                    }];
                        [confirmController addAction:cancelAction];
                        [confirmController addAction:confirmAction];

                        if (confirmController.popoverPresentationController !=
                            nil) {
                            [confirmController.popoverPresentationController
                                setSourceView:self.submitButton];
                            [confirmController.popoverPresentationController
                                setSourceRect:self.submitButton.bounds];
                        }

                        [self presentViewController:confirmController
                                           animated:YES
                                         completion:nil];
                    }];
        [alert addAction:cancelAction];
        [alert addAction:resignAction];

        PenteNavigationViewController *navControllor =
            (PenteNavigationViewController *)self.navigationController;
        if (navControllor.player.subscriber && (canUnHide || canHide)) {
            UIAlertAction *hideOrUnhideAction;
            if ((canHide && hideString.length == 0) ||
                (canUnHide && hideString.length > 0)) {
                hideOrUnhideAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(@"hide game from public",
                                                      nil)
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *action) {
                                if (hideString.length == 0) {
                                    hideString = @"&hide=yes";
                                } else {
                                    hideString = @"";
                                }
                            }];
            } else if ((canHide && hideString.length > 0) ||
                       (canUnHide && hideString.length == 0)) {
                hideOrUnhideAction = [UIAlertAction
                    actionWithTitle:NSLocalizedString(
                                        @"unhide game from public", nil)
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *action) {
                                if (hideString.length == 0) {
                                    hideString = @"&hide=no";
                                } else {
                                    hideString = @"";
                                }
                            }];
            }

            [alert addAction:hideOrUnhideAction];
        }

        [alert addAction:[UIAlertAction
                             actionWithTitle:NSLocalizedString(@"dismiss", nil)
                                       style:UIAlertActionStyleCancel
                                     handler:^(UIAlertAction *action){
                                     }]];
        if (alert.popoverPresentationController) {
            [alert.popoverPresentationController setSourceView:playerStats];
            [alert.popoverPresentationController
                setSourceRect:playerStats.bounds];
        }
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)presentCancelReply {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[self.game opponentName]
                         message:[NSString
                                     stringWithFormat:
                                         NSLocalizedString(
                                             @"is requesting that this set "
                                             @"be cancelled: %@",
                                             nil),
                                         cancelMsg]
                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *acceptCancelAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"accept", nil)
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                   [self sendCancelReply:@"Yes"];
                               }];
    UIAlertAction *declineCancelAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"decline", nil)
                                 style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action) {
                                   [self sendCancelReply:@"No"];
                               }];
    [alert addAction:acceptCancelAction];
    [alert addAction:declineCancelAction];

    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView:playerStats];
        [alert.popoverPresentationController setSourceRect:playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)sendCancelReply:(NSString *)reply {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

    NSString *post = [NSString
        stringWithFormat:@"sid=%@&gid=%@&command=%@&mobile=", [self.game setID],
                         [self.game gameID], reply];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                          allowLossyConversion:YES];
    NSString *postLength =
        [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];

    NSURL *url =
        [NSURL URLWithString:@"https://www.pente.org/gameServer/tb/cancel"];
    if (development) {
        url = [NSURL URLWithString:@"https://localhost/gameServer/tb/cancel"];
    }
    [request setURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0f];

    [request setHTTPShouldUsePipelining:YES];

    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient
        sendRequest:request
         completion:^(NSData *responseData, NSURLResponse *response,
                      NSError *error) {
             PenteNavigationViewController *navControllor =
                 (PenteNavigationViewController *)weakSelf.navigationController;
             [navControllor setDidMove:YES];
             [weakSelf.navigationController
                 popToRootViewControllerAnimated:YES];
         }];
}

- (void)presentDoublePass {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"double pass", nil)
                         message:@"Your opponent has made a pass as well. Mark "
                                 @"the stones you think are dead and press "
                                 @"submit for their evaluation."
                  preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *acceptAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"Got it", nil)
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action){
                               }];
    UIAlertAction *dismissAction =
        [UIAlertAction actionWithTitle:NSLocalizedString(@"No reminders", nil)
                                 style:UIAlertActionStyleDestructive
                               handler:^(UIAlertAction *action) {
                                   [[NSUserDefaults standardUserDefaults]
                                       setBool:YES
                                        forKey:@"doublePassInfo"];
                               }];

    [alert addAction:acceptAction];
    [alert addAction:dismissAction];
    if (alert.popoverPresentationController) {
        [alert.popoverPresentationController setSourceView:playerStats];
        [alert.popoverPresentationController setSourceRect:playerStats.bounds];
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text;
{
    if ([text isEqualToString:@"\n"]) {
        [messagePopover dismiss];
        [textView resignFirstResponder];
        return NO;
    }
    if (range.length + range.location > textView.text.length) {
        return NO;
    }

    NSUInteger newLength =
        [textView.text length] + [text length] - range.length;
    return (newLength > 255) ? NO : YES;
}

- (NSString *)URLEncodedString_ch:(NSString *)input {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[input UTF8String];
    int sourceLen = (int)strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' ') {
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' ||
                   thisChar == '~' || (thisChar >= 'a' && thisChar <= 'z') ||
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
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
    [webView
        evaluateJavaScript:@"document.body.scrollHeight;"
         completionHandler:^(NSString *result, NSError *_Nullable error) {
             int contentSize = [result intValue];
             //        int contentSize = [[webView
             //        stringByEvaluatingJavaScriptFromString:[NSString
             //        stringWithFormat:@"document.body.scrollHeight;"]]
             //        intValue],
             int webViewSize = (int)webView.scrollView.contentSize.height;
             webViewSize = (int)webView.frame.size.height;

             //    NSLog(@"%i %i", contentSize, webViewSize);
             if (contentSize * 2 > 3 * webViewSize &&
                 [moveStatsString length] > 10) {
                 [moveStatsString
                     deleteCharactersInRange:NSMakeRange(
                                                 0,
                                                 moveStatsString.length / 2)];
                 [playerStats
                     loadHTMLString:
                         [HEADERSTRING
                             stringByAppendingString:
                                 [playerStatsBaseString
                                     stringByAppendingString:moveStatsString]]
                            baseURL:nil];
             } else if (contentSize > webViewSize &&
                        [moveStatsString length] > 10) {
                 [moveStatsString
                     deleteCharactersInRange:NSMakeRange(
                                                 0, [moveStatsString
                                                        rangeOfString:@".</b> "]
                                                            .location +
                                                        6)];
                 //        NSLog(moveStatsString);
                 [playerStats
                     loadHTMLString:
                         [HEADERSTRING
                             stringByAppendingString:
                                 [playerStatsBaseString
                                     stringByAppendingString:moveStatsString]]
                            baseURL:nil];
             }
         }];
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:
                        (void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        NSString *urlString = navigationAction.request.URL.absoluteString;
        PenteWebViewController *webViewController =
            [[PenteWebViewController alloc] initWithAddress:urlString];
        [self.navigationController pushViewController:webViewController
                                             animated:YES];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)printAbstractBoard {
    for (int i = 0; i < 19; i++) {
        NSLog([NSString
            stringWithFormat:NSLocalizedString(@"%d %d %d %d %d %d %d %d %d %d "
                                               @"%d %d %d %d %d %d %d %d %d ",
                                               nil),
                             abstractBoard[i][0], abstractBoard[i][1],
                             abstractBoard[i][2], abstractBoard[i][3],
                             abstractBoard[i][4], abstractBoard[i][5],
                             abstractBoard[i][6], abstractBoard[i][7],
                             abstractBoard[i][8], abstractBoard[i][9],
                             abstractBoard[i][10], abstractBoard[i][11],
                             abstractBoard[i][12], abstractBoard[i][13],
                             abstractBoard[i][14], abstractBoard[i][15],
                             abstractBoard[i][16], abstractBoard[i][17],
                             abstractBoard[i][18]]);
    }
}

@end
