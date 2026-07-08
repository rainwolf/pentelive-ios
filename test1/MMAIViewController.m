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

#import "MMAIViewController.h"
#import "BoardView.h"
#import "MMAI.h"
#import "PenteGame.h"
#import "penteLive-Swift.h"
#import "PopoverView.h"
#import "TSMessage.h"
#import "TSMessageView.h"
#import <QuartzCore/QuartzCore.h>

// GADBannerView *bannerView_;

@implementation MMAIViewController {
    int abstractBoard[19][19];
    int finalMove, whiteCaptures, blackCaptures, lastMove;
    char coordinateLetters[19];
    BOOL aiThinking;
    // Canonical variant-aware Swift referee (bridged via penteLive-Swift.h).
    // Its ruleset is fixed at init, so it is (re)created whenever the chosen
    // variant changes; `currentVariant` tracks what `penteGame` was built for.
    SwiftPenteGame *penteGame;
    PenteVariant currentVariant;
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
@synthesize horizontalLine;
@synthesize verticalLine;
@synthesize movesList;
@synthesize messagePopover;
@synthesize activeGame;
@synthesize playerStats;
@synthesize moveStatsString;
@synthesize playerStatsBaseString;
@synthesize setupView;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    // The Swift referee owns its own internal board; it is created lazily by
    // -referee once a variant is chosen, then mirrored into `abstractBoard`
    // (the shared C array the views render) after each replay.
    penteGame = nil;

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

    UIBarButtonItem *setupButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage imageNamed:@"settings.png"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(showSetup)];
    [self.navigationItem setRightBarButtonItem:setupButton];

    [self setTitle:@"Mark Mammel's AI"];

    [board setFrame:CGRectMake(0, 0, self.view.bounds.size.width,
                               self.view.bounds.size.width)];
    [zoomedBoard setFrame:CGRectMake(0, 0, 2 * self.view.bounds.size.width,
                                     2 * self.view.bounds.size.width)];
    // Initial board colour comes from the single source of truth
    // (BoardVariantMapping) so mmai matches the rest of the app per variant.
    NSString *savedGame =
        [[NSUserDefaults standardUserDefaults] objectForKey:@"MMAIGame"];
    PenteVariant boardVariant =
        [self variantForGame:[self gameIdForChooser:savedGame]];
    UIColor *boardBg = [BoardVariantMapping backgroundColorForVariant:boardVariant
                                                            boatPente:NO];
    [board setBackgroundColor:boardBg];
    [zoomedBoard setBackgroundColor:boardBg];
    [board setLastMove:-1];
    [board setLastConnect6Move:-1];
    [zoomedBoard setLastMove:-1];
    [zoomedBoard setLastConnect6Move:-1];
    [board setAbstractBoard:abstractBoard];
    [zoomedBoard setAbstractBoard:abstractBoard];

    CGRect rect;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor clearColor];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [button setTitle:NSLocalizedString(@"  start game  ", nil)
            forState:UIControlStateNormal];
    [button addTarget:self
                  action:@selector(startGame:)
        forControlEvents:UIControlEventTouchUpInside];
    rect = button.frame;
    rect.size = [button intrinsicContentSize];
    rect.origin.y = board.frame.size.height + 2;
    rect.origin.x = self.view.bounds.size.width / 2 - rect.size.width / 2;
    button.frame = rect;
    [self.view addSubview:button];

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

    playerStatsBaseString = @"";
    playerStats = [[WKWebView alloc]
        initWithFrame:CGRectMake(2, blackStoneCaptures.frame.origin.y + 3,
                                 self.view.bounds.size.width - 4,
                                 blackStoneCaptures.frame.origin.y - 3)];
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
    //    [playerStats.scrollView setScrollEnabled:NO];
    [playerStats setNavigationDelegate:self];
    //    playerStats.contentInset = UIEdgeInsetsMake(-5.0,0.0,0,0.0);
    [self.view addSubview:playerStats];

    setupView = [[AISetupView alloc] init];
    [setupView
        setFrame:CGRectMake(0, 0, self.view.bounds.size.width * 2 / 3, 3 * 55)];
    setupView.layer.cornerRadius = 5.0f;
    setupView.layer.borderWidth = 1.0f;
    [setupView setScrollEnabled:NO];
    [setupView setDelegate:setupView];
    [setupView setDataSource:setupView];
    //    [AISetupView setUserInteractionEnabled:NO];
    [setupView setBoard:board];
    [setupView setZBoard:zoomedBoard];
}

- (void)viewWillAppear:(BOOL)animated {
    //    NSLog(@"kittyAppear %i", finalMove);
    [super viewWillAppear:animated];
    [zoomedBoard setHidden:YES];
    [zoomedStone setHidden:YES];
    [stone setHidden:YES];
    [stone setBounds:CGRectMake(0, 0, 1.2 * self.board.bounds.size.width / 19,
                                1.2 * self.board.bounds.size.width / 19)];
    [zoomedStone
        setBounds:CGRectMake(
                      0, 0, 1.2 * 1.5 * 2 * self.board.bounds.size.width / 19,
                      1.2 * 1.5 * 2 * self.board.bounds.size.width / 19)];
    finalMove = -1;
    [whiteStoneCaptures setStoneColor:WHITE];
    [blackStoneCaptures setStoneColor:BLACK];
    [horizontalLine setHidden:YES];
    [verticalLine setHidden:YES];

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
    playerStats.frame =
        CGRectMake(2,
                   blackStoneCaptures.frame.origin.y + 3 +
                       blackStoneCaptures.frame.size.height,
                   self.view.bounds.size.width - 4,
                   newOriginY - blackStoneCaptures.frame.origin.y - 5 -
                       blackStoneCaptures.frame.size.height - bottomOffset);
    [self.view addSubview:playerStats];
}

- (void)viewDidAppear:(BOOL)animated {
    [self showSetup];
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)viewDidUnload {
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
    [self setMovesList:nil];
    [self setBoardTapRecognizer:nil];
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

- (void)startGame:(id)sender {
    aiThinking = NO;
    [((UIButton *)sender) setTitle:NSLocalizedString(@"restart game", nil)
                          forState:UIControlStateNormal];
    [((UIButton *)sender) sizeToFit];
    if (aiPlayer == nil) {
        //        NSLog(@"kitty");
        aiPlayer = [[MMAI alloc] init];
    }
    [aiPlayer reset];
    //    [aiPlayer setGame:1];
    //    [aiPlayer addMove:180];
    //    [aiPlayer addMove:161];
    //    [aiPlayer addMove:104];
    //    [aiPlayer addMove:200];
    //    [aiPlayer addMove:144];
    //    [aiPlayer addMove:198];
    //    [aiPlayer addMove:201];
    //    [aiPlayer setSeat:2];
    //    [aiPlayer setLevel:3];
    //    NSLog(@"kitty %d", [aiPlayer getMove]);
    //    return;
    [aiPlayer setLevel:[setupView.difficultyCell.textField.text intValue]];
    [aiPlayer setSeat:([setupView.colorCell.detailTextLabel.text
                           isEqualToString:NSLocalizedString(@"white", nil)]
                           ? 2
                           : 1)];
    //    NSLog(@"kitty %@", setupView.colorCell.detailTextLabel.text);
    [aiPlayer addMove:180];
    [aiPlayer setGame:[self gameIdForChooser:setupView.gameCell.detailTextLabel
                                                 .text]];
    if (aiPlayer.seat == 1) {
        [stone setStoneColor:BLACK];
        [zoomedStone setStoneColor:BLACK];
        activeGame = YES;
        [self replayGame:[[aiPlayer moves] count]];
    } else {
        [stone setStoneColor:WHITE];
        [zoomedStone setStoneColor:WHITE];
        [self getNewAImove];
    }
    [stone setNeedsDisplay];
    [zoomedStone setNeedsDisplay];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:[aiPlayer level] forKey:@"MMAILevel"];
    [defaults setObject:setupView.colorCell.detailTextLabel.text
                 forKey:@"MMAIColor"];
    [defaults setObject:setupView.gameCell.detailTextLabel.text
                 forKey:@"MMAIGame"];
}

- (IBAction)goBackOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    if ([[aiPlayer moves] count] > 1 && !aiThinking) {
        int n = (int)[[aiPlayer moves] count];
        int human = [self humanColor];
        SwiftPenteGame *ref = [self referee];

        // Lookahead undo (same semantics as the Android fix). Popping a
        // fixed number of moves is wrong in general: colorForMoveAt: assigns
        // each SLOT in the move list to a colour by position, independent of
        // history, so whether "pop exactly one" lands on the human's turn
        // depends entirely on the active variant's cadence. Search backward
        // from n-1 for the LARGEST t in [1, n-1] whose slot -- i.e. who
        // moves next once the list has been truncated to t entries,
        // colorForMoveAt:t -- belongs to the human, and truncate to exactly
        // that many moves. Concretely, for the shapes this app can be in:
        //   (a) plain Pente/Keryo mid-game (alternating cadence): the slot
        //       at t = n-1 belongs to the OTHER colour from the one that
        //       plays at t = n-2 (alternating flips every slot), so t = n-1
        //       is the AI's and the search continues to t = n-2, which is
        //       the human's own slot again. Net effect: pops the AI's reply
        //       AND the human's own last move, same as the old app.
        //   (b) Connect6, human retracting the FIRST of their own two still-
        //       open stones (the AI's last pair is fully played; the human
        //       has placed only one of their two): t = n-1 already belongs
        //       to the human (both slots of a pair share one colour), so
        //       this degenerates to a plain single-move pop.
        //   (c) Connect6, immediately after the AI's very first (lone,
        //       unpaired) opening stone: the only in-range candidate,
        //       t = 1, is still the first half of the AI's very next pair,
        //       so no candidate satisfies the search. The swipe is a no-op
        //       rather than freezing the board (activeGame = NO with
        //       nothing left to re-launch the AI) or corrupting the move
        //       list.
        int foundT = -1;
        for (int t = n - 1; t >= 1; t--) {
            if ((int)[ref colorForMoveAt:t] == human) {
                foundT = t;
                break;
            }
        }
        if (foundT >= 0) {
            [[aiPlayer moves]
                removeObjectsInRange:NSMakeRange(foundT, n - foundT)];
            [self replayGame:[[aiPlayer moves] count]];
            // Recomputed from -nextMoveIsAI (not hardcoded YES): by
            // construction foundT's slot belongs to the human, but routing
            // through the same check -boardTap: uses keeps this correct if
            // that invariant is ever loosened.
            activeGame = ![self nextMoveIsAI];
        }
        // else: no in-range truncation point hands the next move to the
        // human -- leave `moves` untouched (no-op) instead of freezing the
        // board or truncating past a sensible boundary.
    }
}

- (IBAction)boardTap:(UILongPressGestureRecognizer *)recognizer {
    int i, j;
    CGPoint currentPoint = [recognizer locationInView:self.board];
    float cellSize = self.board.bounds.size.width / 19;
    j = (int)floorf(currentPoint.x / cellSize);
    i = (int)floorf(currentPoint.y / cellSize);

    switch ([recognizer state]) {
    case UIGestureRecognizerStateBegan:
        [zoomedBoard setHidden:NO];
        [stone setHidden:YES];
        if (abstractBoard[i][j] == 0 && activeGame) {
            [zoomedStone setHidden:NO];
            [horizontalLine setHidden:NO];
            [verticalLine setHidden:NO];
        }
        break;
    case UIGestureRecognizerStateEnded:
        [zoomedBoard setHidden:YES];
        if (abstractBoard[i][j] == 0 && activeGame) {
            stone.center = CGPointMake(cellSize * j + cellSize / 2,
                                       cellSize * i + cellSize / 2);
            [zoomedStone setHidden:YES];
            [horizontalLine setHidden:YES];
            [verticalLine setHidden:YES];

            finalMove = 19 * i + j;

            [aiPlayer addMove:finalMove];
            [self replayGame:[[aiPlayer moves] count]];
            // Launch the AI only when the game is still live AND the next move
            // belongs to the AI. For multi-stone turns (Connect6) the human's
            // first stone leaves the next move still theirs, so activeGame stays
            // YES and we just wait for the second tap; only once the turn flips
            // to the AI do we launch its single getMove, which appends the AI's
            // whole turn (two stones for Connect6) in one shot.
            if (activeGame && [self nextMoveIsAI]) {
                activeGame = NO;
                spinner.center = stone.center;
                [spinner setColor:([self nextMoveColor] == 2)
                                      ? [UIColor blackColor]
                                      : [UIColor whiteColor]];
                [spinner setHidden:NO];
                [spinner startAnimating];
                aiThinking = YES;
                [NSThread detachNewThreadSelector:@selector(getNewAImove)
                                         toTarget:self
                                       withObject:nil];
            }

            //                [self detectCaptureOfOpponent:(([[stone
            //                stoneColor] isEqual: [UIColor blackColor]]) ? 1 :
            //                2) atPosition: finalMove];
        }
        break;
    default:
        break;
    }
    if ((currentPoint.x < 0) ||
        (currentPoint.x > self.board.bounds.size.width) ||
        (currentPoint.y < 0) ||
        (currentPoint.y > self.board.bounds.size.height)) {
        [zoomedBoard setHidden:YES];
        [zoomedStone setHidden:YES];
        [horizontalLine setHidden:YES];
        [verticalLine setHidden:YES];
    } else {
        if ([zoomedBoard isHidden] &&
            ([recognizer state] != UIGestureRecognizerStateEnded) &&
            (abstractBoard[i][j] == 0)) {
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
        float cellSize = self.zoomedBoard.bounds.size.width / 19;
        if ((fabs(zoomedStone.center.x - 2 * currentPoint.x) >= cellSize / 2) ||
            (fabs(zoomedStone.center.y - 2 * currentPoint.y) >= cellSize / 2)) {

            zoomedStone.center = CGPointMake(cellSize * j + cellSize / 2,
                                             cellSize * i + cellSize / 2);
            verticalLine.center = CGPointMake(
                cellSize * j + cellSize / 2, zoomedBoard.bounds.size.width / 2);
            horizontalLine.center =
                CGPointMake(zoomedBoard.bounds.size.height / 2,
                            cellSize * i + cellSize / 2);
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

- (void)getNewAImove {
    [aiPlayer getMove];
    //    NSLog(@"kitty move %i", newMove);
    // Defense in depth: -getMove is contracted to append the AI's WHOLE turn
    // (both stones for a mid-game Connect6 pair, one stone otherwise -- see
    // MMAI.mm) before returning, so the next move per the referee's cadence
    // should always belong to the human by the time we get here, making it
    // safe to unlock the board unconditionally. But if -getMove ever again
    // returns having appended only PART of an AI turn (e.g. a future
    // regression reintroduces the fallback-cadence bug this branch fixes),
    // blindly setting activeGame = YES would hand the tap gesture to the
    // human while the AI still owes a stone, corrupting the move list. Re-
    // check -nextMoveIsAI and refuse to unlock in that case instead. With the
    // MMAI.mm fallback fix in place this branch should be unreachable -- if
    // it fires, that means the append contract broke, so log loudly.
    if ([self nextMoveIsAI]) {
        NSLog(@"[MMAIViewController] *** getNewAImove: AI still owes a move "
              @"after -getMove returned (moves.count=%lu); NOT unlocking the "
              @"human -- this should be unreachable, investigate the AI "
              @"append path. ***",
              (unsigned long)[[aiPlayer moves] count]);
        activeGame = NO;
    } else {
        activeGame = YES;
    }
    // sleep for 0.x seconds
    [NSThread sleepForTimeInterval:0.18];
    [self replayGame:[[aiPlayer moves] count]];
    aiThinking = NO;
    [spinner performSelectorOnMainThread:@selector(stopAnimating)
                              withObject:nil
                           waitUntilDone:NO];
}

- (void)updateCaptures {
    [whiteCapturesCountLabel
        setText:[NSString stringWithFormat:@"x %i", whiteCaptures]];
    [whiteCapturesCountLabel setNeedsDisplay];
    [blackCapturesCountLabel
        setText:[NSString stringWithFormat:@"x %i", blackCaptures]];
    [blackCapturesCountLabel setNeedsDisplay];
}

// ---------------------------------------------------------------------------
// Variant wiring. The AISetupView chooser stores a display string; -startGame
// maps it to a canonical MMAI engine id (see MMAI.h) via -gameIdForChooser:,
// and the Swift referee is selected from that id via -variantForGame:. ONE
// place documents the chooser -> (engine id, PenteVariant) table:
//     Pente        -> (1,  PenteVariantPente)
//     Keryo-Pente  -> (3,  PenteVariantKeryoPente)  (the engine maps legacy 2
//                                                     and canonical 3 alike)
//     Poof-Pente   -> (11, PenteVariantPoofPente)
//     Connect6     -> (13, PenteVariantConnect6)
//     Boat-Pente   -> (15, PenteVariantBoatPente) (Pente rules + unbreakable-five)
//     O-Pente      -> (25, PenteVariantOPente) (Keryo poof + unbreakable-five with
//                                               triple breaks, capture threshold 15)
// ---------------------------------------------------------------------------
- (int)gameIdForChooser:(NSString *)name {
    if ([name isEqualToString:@"Keryo-Pente"]) return 3;
    if ([name isEqualToString:@"Poof-Pente"]) return 11;
    if ([name isEqualToString:@"Connect6"]) return 13;
    if ([name isEqualToString:@"Boat-Pente"]) return 15;
    if ([name isEqualToString:@"O-Pente"]) return 25;
    return 1; // Pente (default)
}

- (PenteVariant)variantForGame:(int)game {
    switch (game) {
        case 3:  return PenteVariantKeryoPente;
        case 11: return PenteVariantPoofPente;
        case 13: return PenteVariantConnect6;
        case 15: return PenteVariantBoatPente;
        case 25: return PenteVariantOPente;
        default: return PenteVariantPente;
    }
}

// Lazily (re)build the referee for the chosen variant. Its ruleset is fixed at
// init, so a fresh instance is created whenever the variant changes.
- (SwiftPenteGame *)referee {
    PenteVariant v = [self variantForGame:aiPlayer.game];
    if (penteGame == nil || v != currentVariant) {
        currentVariant = v;
        penteGame = [[SwiftPenteGame alloc] initWithVariant:v];
    }
    return penteGame;
}

// Referee colour (1 white, 2 black) the human plays, from the colour chooser.
- (int)humanColor {
    return [setupView.colorCell.detailTextLabel.text
               isEqualToString:NSLocalizedString(@"white", nil)]
               ? 1
               : 2;
}

// Colour to play the NEXT move (index == moves already played), per the active
// variant's cadence. Drives Connect6's two-stone turns.
- (int)nextMoveColor {
    return (int)[[self referee] colorForMoveAt:(int)[[aiPlayer moves] count]];
}

- (BOOL)nextMoveIsAI {
    return [self nextMoveColor] != [self humanColor];
}

// Single referee-driven replay path (collapses the former replayPenteGame /
// replayKeryoPenteGame + winnerForVariant): replays the move list through the
// Swift engine, mirrors its board into `abstractBoard`, refreshes the capture
// labels, reads MoveResult.winner for the game-over banner, and rebuilds the
// move-list HTML. Board-view / capture-label plumbing is unchanged.
- (void)replayGame:(unsigned long)untilMove {
    SwiftPenteGame *game = [self referee];
    MoveResult *result = [game replay:[aiPlayer moves] until:(int)untilMove];
    whiteCaptures = game.whiteCaptures;
    blackCaptures = game.blackCaptures;

    // Mirror the engine's board into the shared C array the views render.
    // stoneAt: -> 0 empty / 1 white / 2 black / -1 masked; the -1 overlay is
    // preserved so an opening-restricted cell still blocks a human tap
    // (boardTap only accepts abstractBoard[i][j] == 0).
    for (int idx = 0; idx < 361; idx++) {
        abstractBoard[idx / 19][idx % 19] = (int)[game stoneAt:idx];
    }

    [board setAbstractBoard:abstractBoard];
    int lastPlayed = [[[aiPlayer moves] objectAtIndex:untilMove - 1] intValue];
    [board setLastMove:lastPlayed];
    // Connect6: also highlight the earlier stone of the two-stone turn (the move
    // before last, when it shares the same colour). Other variants clear it.
    if (aiPlayer.game == 13 && untilMove >= 2 &&
        [game colorForMoveAt:(int)(untilMove - 1)] ==
            [game colorForMoveAt:(int)(untilMove - 2)]) {
        [board setLastConnect6Move:
                   [[[aiPlayer moves] objectAtIndex:untilMove - 2] intValue]];
    } else {
        [board setLastConnect6Move:-1];
    }
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard:abstractBoard];
        [zoomedBoard setLastMove:lastPlayed];
        [zoomedBoard setLastConnect6Move:board.lastConnect6Move];
    }
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
    [self updateCaptures];

    NSString *message = nil;
    BOOL iWin = YES;
    int winner = (int)result.winner;
    if (winner == 1) {
        message = NSLocalizedString(@"White wins", nil);
    } else if (winner == 2) {
        message = NSLocalizedString(@"Black wins", nil);
    }
    if (message) {
        activeGame = NO;
        if ([message isEqualToString:NSLocalizedString(@"White wins", nil)]) {
            if ([setupView.colorCell.detailTextLabel.text
                    isEqualToString:NSLocalizedString(@"black", nil)]) {
                iWin = NO;
            }
        } else {
            if ([setupView.colorCell.detailTextLabel.text
                    isEqualToString:NSLocalizedString(@"white", nil)]) {
                iWin = NO;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [TSMessage
                showNotificationInViewController:self.navigationController
                                           title:NSLocalizedString(@"Game Over",
                                                                   nil)
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
        });
    }
    NSString *colorStr = NSLocalizedString(@"Color:", nil),
             *difficultyStr = NSLocalizedString(@"difficulty:", nil);
    moveStatsString = [[NSMutableString alloc]
        initWithString:
            [NSString stringWithFormat:
                          @"<center><b>%@</b> %@, <b>%@</b> %@</center><hr>",
                          colorStr, setupView.colorCell.detailTextLabel.text,
                          difficultyStr,
                          setupView.difficultyCell.textField.text]];
    int i = 0;
    for (NSNumber *move in [aiPlayer moves]) {
        int rowCol = [move intValue];
        if (i == 0) {
            [moveStatsString appendString:@"<b>1.</b> "];
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
        [moveStatsString
            appendString:[NSString
                             stringWithFormat:@"%c%d",
                                              coordinateLetters[rowCol % 19],
                                              19 - (rowCol / 19)]];
        ++i;
    }
    [playerStats
        loadHTMLString:[HEADERSTRING stringByAppendingString:moveStatsString]
               baseURL:nil];
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
    [webView
        evaluateJavaScript:@"document.body.offsetHeight;"
         completionHandler:^(NSString *result, NSError *_Nullable error) {
             NSInteger height = [result intValue];
             NSString *javascript = [NSString
                 stringWithFormat:@"window.scrollBy(0, %ld);", (long)height];
             [webView evaluateJavaScript:javascript
                       completionHandler:^(id res, NSError *_Nullable error) {
                           return;
                       }];
         }];
}

- (void)showSetup {

    messagePopover = [PopoverView
        showPopoverAtPoint:CGPointMake(self.view.bounds.size.width - 20, 0)
                    inView:self.view
                 withTitle:NSLocalizedString(@"settings", nil)
           withContentView:setupView
                  delegate:self];
    [messagePopover layoutSubviews];
}

- (void)popoverViewDidDismiss:(PopoverView *)popoverView {
    [setupView.difficultyCell.textField resignFirstResponder];
}

@end
