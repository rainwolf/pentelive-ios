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

#import "PenteSpinnerOverlay.h"
#import "DatabaseViewController.h"
#import "AppDelegate.h"
#import "BoardViewController.h"
#import "DBBoardView.h"
#import "MMAI.h"
#import "PenteAlert.h"
#import "PenteGame.h"
#import "PenteBanner.h"
#import "penteLive-Swift.h"
#import <QuartzCore/QuartzCore.h>

@interface DatabaseViewController ()
/// Created once in viewDidLoad and kept for the screen's lifetime, so its
/// scroll offset survives dismissal and re-presentation.
@property(nonatomic, strong) DBResultsViewController *resultsVC;
@end

@implementation DatabaseViewController {
    int abstractBoard[19][19];
    int finalMove, whiteCaptures, blackCaptures, lastMove;
    char coordinateLetters[19];
    BOOL aiThinking;
    LegacyPenteGame *penteGame;
    BOOL didShowSubscriptionAlert, didShowLogInAlert;
    // Test seam: when set, receives the log-in alert instead of a window.
    void (^logInAlertPresenter)(UIAlertController *);
    UILabel *dbStatusLabel;
    UIButton *dbRetryButton;
    UIBarButtonItem *heatButton;
    UILabel *dbTitleLabel, *dbSubtitleLabel;
    UIBarButtonItem *dbSetupButton, *movesButton;
    // Bottom of the under-board strip (AI button, captures, status/retry,
    // move notation), in view coordinates.
    CGFloat stripMaxY;
    BOOL didAutoPresentResults, wasShowingResultsSheet;
    // Test seam: when set, receives the results sheet instead of a window.
    void (^resultsSheetPresenter)(UIViewController *);
    // Test seam: when set, receives the game viewer instead of a push.
    void (^gameViewerPusher)(UIViewController *);
    // Test seam: when set, receives the filters sheet instead of a window.
    void (^filtersPresenter)(UIViewController *);
    // Under-board chip row: active filters summary; opens the filters sheet.
    UIButton *dbChipButton;
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
@synthesize movesList, captures;
@synthesize messagePopover;
@synthesize activeGame;
@synthesize playerStats;
@synthesize moveStatsString;
@synthesize playerStatsBaseString, game;
@synthesize progressView;
@synthesize aiButton;
@synthesize aiSetupView;
@synthesize line;
@synthesize dbService;

BoardViewController *boardController;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    penteGame = [[LegacyPenteGame alloc] init];
    penteGame.abstractBoard = abstractBoard;
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

    dbSetupButton = [[UIBarButtonItem alloc]
        initWithImage:[UIImage imageNamed:@"settings.png"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(showSetup)];
    heatButton = [[UIBarButtonItem alloc]
        initWithImage:[self heatButtonImage]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(toggleHeat)];
    heatButton.accessibilityIdentifier = @"dbHeatToggle";
    movesButton = [[UIBarButtonItem alloc]
        initWithTitle:NSLocalizedString(@"Moves", nil)
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(showResultsSheet)];
    movesButton.accessibilityIdentifier = @"dbMovesButton";
    [self.navigationItem
        setRightBarButtonItems:@[ dbSetupButton, heatButton, movesButton ]];

    [self setTitle:NSLocalizedString(@"Database & AI", nil)];
    [self setTitle:NSLocalizedString(@"Database", nil)];

    UIColor *initialColor = [DBPalette
        boardColorForGame:[DBGameCatalog
                              gameIdForName:
                                  [[NSUserDefaults standardUserDefaults]
                                      objectForKey:@"MMAIGame"]]];
    [board setBackgroundColor:initialColor];
    [zoomedBoard setBackgroundColor:initialColor];
    [board setLastMove:-1];
    [zoomedBoard setLastMove:-1];
    [board setAbstractBoard:abstractBoard];
    [zoomedBoard setAbstractBoard:abstractBoard];

    aiButton = [UIButton buttonWithType:UIButtonTypeCustom];
    aiButton.backgroundColor = [UIColor clearColor];
    aiButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [aiButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    //    [aiButton setTitle:NSLocalizedString(@"  search  ",nil)
    //    forState:UIControlStateNormal];
    [aiButton setImage:[UIImage imageNamed:@"computer"]
              forState:UIControlStateNormal];
    [aiButton addTarget:self
                  action:@selector(askAI:)
        forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:aiButton];

    playerStatsBaseString = @"";
    // Keeps only the move notation; its frame is set in layoutBoardAndStrip.
    playerStats = [[WKWebView alloc] initWithFrame:CGRectZero];
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

    if (dbService == nil) {
        dbService = [DBPositionService makeDefault];
    }
    // Game source: an injected game (BoardViewController.toDB) becomes the
    // saved filter game when supported; Go/Renju keep their name and show
    // "Not supported yet". Otherwise the saved filters pick the game.
    if (game != nil) {
        [dbService adoptInjectedGame:game];
    } else {
        game = [DBGameCatalog nameForGame:dbService.filterGameId];
    }

    if (movesList == nil) {
        movesList = [[NSMutableArray alloc] init];
        [self resetState];
    }
    // Always after the block above, so a movesList handed in by
    // BoardViewController.toDB seeds the line too.
    line = [[DBLine alloc] initWithGame:[DBGameCatalog gameIdForName:game]
                                  moves:[movesList copy]];
    heatButton.image = [self heatButtonImage];
    __weak typeof(self) weakSelf = self;
    dbService.onHeat = ^(NSDictionary<NSNumber *, UIColor *> *heat) {
        [weakSelf applyHeat:heat];
    };
    dbService.onStatsState = ^(DBLoadState state) {
        [weakSelf statsStateChanged:state];
    };
    self.resultsVC = [[DBResultsViewController alloc] initWithService:dbService];
    self.resultsVC.onPlayMove = ^(NSInteger cell) {
        [weakSelf playDBMove:cell];
    };
    self.resultsVC.onShowCountChanged = ^{
        [weakSelf showCountChanged];
    };
    self.resultsVC.onRetry = ^{
        [weakSelf positionChanged];
    };
    self.resultsVC.onLoadMore = ^{
        [weakSelf.dbService loadMoreGames];
    };
    self.resultsVC.onOpenGame = ^(int64_t gid) {
        [weakSelf openGame:gid];
    };
    dbService.onGamesChanged = ^{
        [weakSelf.resultsVC reloadGames];
    };
    dbService.onGamesState = ^(DBLoadState state) {
        [weakSelf gamesStateChanged:state];
    };

    // The storyboard only has the left (back) swipe for this scene.
    UISwipeGestureRecognizer *forwardSwipe = [[UISwipeGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(goForwardOneMoveSwipe:)];
    forwardSwipe.direction = UISwipeGestureRecognizerDirectionRight;
    [self.view addGestureRecognizer:forwardSwipe];

    // Under-board strip: "Not supported yet" label / "Couldn't load" retry.
    CGRect stripRect = CGRectZero; // laid out in layoutBoardAndStrip
    dbStatusLabel = [[UILabel alloc] initWithFrame:stripRect];
    dbStatusLabel.textAlignment = NSTextAlignmentCenter;
    dbStatusLabel.font = [UIFont systemFontOfSize:14];
    dbStatusLabel.textColor = [UIColor colorWithRed:0x4A / 255.0
                                              green:0x4F / 255.0
                                               blue:0x5A / 255.0
                                              alpha:1];
    dbStatusLabel.accessibilityIdentifier = @"dbStatusLabel";
    dbStatusLabel.hidden = YES;
    [self.view addSubview:dbStatusLabel];
    dbRetryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    dbRetryButton.frame = stripRect;
    dbRetryButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [dbRetryButton setTitle:NSLocalizedString(@"Couldn't load. Retry", nil)
                   forState:UIControlStateNormal];
    [dbRetryButton setTitleColor:[UIColor colorWithRed:0x1F / 255.0
                                                       green:0x5F / 255.0
                                                        blue:0xD6 / 255.0
                                                       alpha:1]
                        forState:UIControlStateNormal];
    [dbRetryButton addTarget:self
                      action:@selector(retryPositionStats:)
            forControlEvents:UIControlEventTouchUpInside];
    dbRetryButton.accessibilityIdentifier = @"dbRetryButton";
    dbRetryButton.hidden = YES;
    [self.view addSubview:dbRetryButton];

    dbChipButton = [UIButton buttonWithType:UIButtonTypeSystem];
    dbChipButton.titleLabel.font = [UIFont systemFontOfSize:13];
    dbChipButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    dbChipButton.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    [dbChipButton setTitleColor:[UIColor colorWithRed:0x16 / 255.0
                                                green:0x18 / 255.0
                                                 blue:0x1D / 255.0
                                                alpha:1]
                       forState:UIControlStateNormal];
    dbChipButton.backgroundColor = [UIColor colorWithRed:0xE3 / 255.0
                                                   green:0xEC / 255.0
                                                    blue:0xFC / 255.0
                                                   alpha:1];
    dbChipButton.layer.borderWidth = 1;
    dbChipButton.layer.borderColor = [UIColor colorWithRed:0xC8 / 255.0
                                                     green:0xCC / 255.0
                                                      blue:0xD4 / 255.0
                                                     alpha:1]
                                         .CGColor;
    dbChipButton.layer.cornerRadius = 13;
    [dbChipButton addTarget:self
                     action:@selector(showSetup)
           forControlEvents:UIControlEventTouchUpInside];
    dbChipButton.accessibilityIdentifier = @"dbFilterChips";
    [self.view addSubview:dbChipButton];
    [self refreshChipRow];

    self.progressView = [[PenteSpinnerOverlay alloc]
        initWithFrame:CGRectMake(0, 0, self.view.frame.size.width,
                                 self.view.frame.size.height)];
    [self layoutBoardAndStrip];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    // Also runs on size-class changes (iPad multitasking); the app is
    // portrait-only, so there is no rotation.
    [self layoutBoardAndStrip];
    [self updateResultsPresentation];
}

/// Board side = min(safe width, 62% of safe height), centred, so a tall
/// iPad leaves room below it. The under-board strip follows directly.
- (void)layoutBoardAndStrip {
    CGRect safe = self.view.safeAreaLayoutGuide.layoutFrame;
    if (CGRectIsEmpty(safe)) {
        safe = self.view.bounds;
    }
    CGFloat side = floor(MIN(safe.size.width, safe.size.height * 0.62));
    CGRect boardFrame =
        CGRectMake(safe.origin.x + floor((safe.size.width - side) / 2),
                   safe.origin.y, side, side);
    if (!CGRectEqualToRect(board.frame, boardFrame)) {
        board.frame = boardFrame;
        [board setNeedsDisplay];
    }
    // zoomedBoard and the stones keep their centres (gestures move them).
    CGSize zoomed = CGSizeMake(2 * side, 2 * side);
    if (!CGSizeEqualToSize(zoomedBoard.bounds.size, zoomed)) {
        zoomedBoard.bounds = (CGRect){CGPointZero, zoomed};
        [zoomedBoard setNeedsDisplay];
    }
    CGFloat stoneSide = 1.2 * side / 19;
    stone.bounds = CGRectMake(0, 0, stoneSide, stoneSide);
    zoomedStone.bounds = CGRectMake(0, 0, 1.5 * 2 * stoneSide, 1.5 * 2 * stoneSide);

    CGFloat left = CGRectGetMinX(boardFrame);
    CGFloat y0 = CGRectGetMaxY(boardFrame) + 2;
    CGRect r;
    r.size = [aiButton intrinsicContentSize];
    r.origin = CGPointMake(CGRectGetMaxX(boardFrame) - r.size.width - 15, y0);
    aiButton.frame = r;

    r = whiteCapturesCountLabel.frame;
    r.origin = CGPointMake(left + 24, y0);
    whiteCapturesCountLabel.frame = r;
    r = whiteStoneCaptures.frame;
    r.origin = CGPointMake(left + 8, y0 + 2);
    whiteStoneCaptures.frame = r;
    r = blackCapturesCountLabel.frame;
    r.origin = CGPointMake(left + 24, CGRectGetMaxY(whiteCapturesCountLabel.frame) + 1);
    blackCapturesCountLabel.frame = r;
    r = blackStoneCaptures.frame;
    r.origin = CGPointMake(left + 8, CGRectGetMaxY(whiteCapturesCountLabel.frame) + 3);
    blackStoneCaptures.frame = r;

    CGRect stripRect = CGRectMake(CGRectGetMidX(boardFrame) - side / 4, y0 + 4,
                                  side / 2, 22);
    dbStatusLabel.frame = stripRect;
    dbRetryButton.frame = stripRect;

    CGFloat notationY = MAX(MAX(CGRectGetMaxY(blackStoneCaptures.frame),
                                CGRectGetMaxY(blackCapturesCountLabel.frame)),
                            MAX(CGRectGetMaxY(stripRect), CGRectGetMaxY(aiButton.frame))) +
                        3;
    dbChipButton.frame = CGRectMake(left + 2, notationY, side - 4, 26);
    notationY = CGRectGetMaxY(dbChipButton.frame) + 3;
    playerStats.frame = CGRectMake(left + 2, notationY, side - 4, 44);
    stripMaxY = CGRectGetMaxY(playerStats.frame) + 4;
}

#pragma mark - Results panel / sheet

- (BOOL)usesInlineResults {
    return self.traitCollection.horizontalSizeClass ==
           UIUserInterfaceSizeClassRegular;
}

/// Regular width (iPad): the results are an inline child panel below the
/// strip and nothing is presented. Compact width: a sheet plus a Moves
/// button that re-presents it.
- (void)updateResultsPresentation {
    DBResultsViewController *results = self.resultsVC;
    if (results == nil) {
        return;
    }
    BOOL isInline = [self usesInlineResults];
    if (isInline) {
        if (results.parentViewController != self) {
            if (results.presentingViewController != nil) {
                [results dismissViewControllerAnimated:NO completion:nil];
            }
            [self addChildViewController:results];
            [self.view addSubview:results.view];
            [results didMoveToParentViewController:self];
        }
        CGRect safe = self.view.safeAreaLayoutGuide.layoutFrame;
        if (CGRectIsEmpty(safe)) {
            safe = self.view.bounds;
        }
        CGRect panel = CGRectMake(safe.origin.x, stripMaxY, safe.size.width,
                                  MAX(0, CGRectGetMaxY(safe) - stripMaxY));
        if (!CGRectEqualToRect(results.view.frame, panel)) {
            results.view.frame = panel;
        }
    } else if (results.parentViewController == self) {
        [results willMoveToParentViewController:nil];
        [results.view removeFromSuperview];
        [results removeFromParentViewController];
    }
    NSArray *items = isInline ? @[ dbSetupButton, heatButton ]
                              : @[ dbSetupButton, heatButton, movesButton ];
    if (![self.navigationItem.rightBarButtonItems isEqualToArray:items]) {
        [self.navigationItem setRightBarButtonItems:items];
    }
}

- (CGFloat)stripMaxYInWindow {
    return [self.view convertPoint:CGPointMake(0, stripMaxY) toView:nil].y;
}

/// Small detent sits below the under-board strip (iOS 16+) and stays
/// undimmed, so the board, the strip and swipes keep working.
- (void)configureResultsSheet {
    DBResultsViewController *results = self.resultsVC;
    results.modalPresentationStyle = UIModalPresentationPageSheet;
    UISheetPresentationController *sheet = results.sheetPresentationController;
    if (sheet == nil) {
        return;
    }
    if (@available(iOS 16.0, *)) {
        UISheetPresentationControllerDetentIdentifier smallId = @"belowBoard";
        __weak typeof(self) weakSelf = self;
        UISheetPresentationControllerDetent *small = [UISheetPresentationControllerDetent
            customDetentWithIdentifier:smallId
                              resolver:^CGFloat(
                                  id<UISheetPresentationControllerDetentResolutionContext>
                                      context) {
                                  CGFloat max = context.maximumDetentValue;
                                  CGFloat h = max - [weakSelf stripMaxYInWindow];
                                  return MIN(max, MAX(200, h));
                              }];
        sheet.detents = @[ small, [UISheetPresentationControllerDetent largeDetent] ];
        sheet.largestUndimmedDetentIdentifier = smallId;
        sheet.selectedDetentIdentifier = smallId;
    } else {
        // Owner-accepted fallback (Decision 10): overlaps the board bottom.
        sheet.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        sheet.largestUndimmedDetentIdentifier =
            UISheetPresentationControllerDetentIdentifierMedium;
        sheet.selectedDetentIdentifier =
            UISheetPresentationControllerDetentIdentifierMedium;
    }
    sheet.prefersGrabberVisible = YES;
    sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
}

/// Moves navbar button (compact width only).
- (void)showResultsSheet {
    [self presentResultsSheet];
}

- (BOOL)presentResultsSheet {
    DBResultsViewController *results = self.resultsVC;
    if (results == nil || [self usesInlineResults] || results.parentViewController != nil) {
        return NO;
    }
    if (resultsSheetPresenter != nil) {
        [self configureResultsSheet];
        resultsSheetPresenter(results);
        return YES;
    }
    if (self.view.window == nil || results.presentingViewController != nil ||
        self.presentedViewController != nil) {
        return NO;
    }
    [self configureResultsSheet];
    [self presentViewController:results animated:YES completion:nil];
    return YES;
}

/// A Moves row was tapped: play it like a tap on its heat dot.
- (void)playDBMove:(NSInteger)cell {
    NSInteger grid = [DBGameCatalog gridSizeForGame:[DBGameCatalog gameIdForName:game]];
    if (grid > 19 || cell < 0 || cell >= grid * grid) {
        return;
    }
    if (abstractBoard[cell / grid][cell % grid] != 0) {
        return;
    }
    [board setLastMove:-1];
    if (!game) {
        game = [DBGameCatalog nameForGame:dbService.filterGameId];
    }
    if (!game) {
        game = @"Pente";
    }
    [self syncLineGame];
    [line play:cell];
    [self lineDidChange];
}

/// "Show N" changed: recolour the board from the cached stats (no refetch)
/// and refresh the rows.
- (void)showCountChanged {
    [dbService recomputeHeat];
    [self.resultsVC reload];
}

- (void)viewWillAppear:(BOOL)animated {
    //    NSLog(@"kittyAppear %i", finalMove);
    [super viewWillAppear:animated];

    if (@available(iOS 26.0, *)) {
        self.navigationController.interactiveContentPopGestureRecognizer
            .enabled = NO;
    }

    [zoomedBoard setHidden:YES];
    [zoomedStone setHidden:YES];
    [stone setHidden:YES];
    finalMove = -1;
    [whiteStoneCaptures setStoneColor:WHITE];
    [blackStoneCaptures setStoneColor:BLACK];
    [horizontalLine setHidden:YES];
    [verticalLine setHidden:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    // game is never nil here: viewDidLoad takes it from the injected game
    // or the saved filters.
    [self setBoardColor];
    // Returning from the viewer keeps the loaded results: only a position
    // that never loaded (first appearance, failure, changed moves) refetches.
    if ([dbService shouldRefreshOnAppearWithGame:[DBGameCatalog gameIdForName:game]
                                           moves:line.moves]) {
        [self replayGame];
        [self positionChanged];
    }
    // Returning from a pushed screen re-shows the sheet where it was.
    if (wasShowingResultsSheet) {
        wasShowingResultsSheet = NO;
        [self presentResultsSheet];
    }
    //    [whiteStoneCaptures setStoneColor: WHITE];
    //    [whiteStoneCaptures setNeedsDisplay];
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // A sheet would otherwise float over the pushed or popped-to screen.
    if (self.resultsVC.presentingViewController != nil &&
        self.resultsVC.parentViewController == nil) {
        wasShowingResultsSheet = YES;
        [self.resultsVC dismissViewControllerAnimated:NO completion:nil];
    }

    if (@available(iOS 26.0, *)) {
        self.navigationController.interactiveContentPopGestureRecognizer
            .enabled = YES;
    }
}

- (void)setBoardColor {
    UIColor *c = [DBPalette boardColorForGame:[DBGameCatalog gameIdForName:game]];
    [board setBackgroundColor:c];
    [zoomedBoard setBackgroundColor:c];
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
    if (game) {
        [self updateAIButtonVisibility];
    }
    BOOL hideCaptures =
        ![DBGameCatalog hasCapturesWithGame:[DBGameCatalog gameIdForName:game]];
    [whiteStoneCaptures setHidden:hideCaptures];
    [whiteCapturesCountLabel setHidden:hideCaptures];
    [blackStoneCaptures setHidden:hideCaptures];
    [blackCapturesCountLabel setHidden:hideCaptures];
}

/// The AI only plays Pente, Speed Pente and the Keryo-Pente variants.
- (void)updateAIButtonVisibility {
    if ([game isEqualToString:@"Pente"] ||
        [game isEqualToString:@"Speed Pente"] ||
        [game containsString:@"Keryo-Pente"]) {
        [aiButton setHidden:NO];
    } else {
        [aiButton setHidden:YES];
    }
}

#pragma mark - Line, redo and position-stats

/// movesList mirrors line.moves; every line mutation ends here.
- (void)lineDidChange {
    movesList = [line.moves mutableCopy];
    [self replayGame];
    [self positionChanged];
}

/// Points line.game at the current game name. A game switch always goes
/// through resetWithMoves: so a redo stack never outlives its game.
- (void)syncLineGame {
    NSInteger gameId = [DBGameCatalog gameIdForName:game];
    if (line.game != gameId) {
        line.game = gameId;
        [line resetWithMoves:[movesList copy]];
    }
}

- (void)positionChanged {
    [board setDbOptions:nil];
    [zoomedBoard setDbOptions:nil];
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];

    // Occupied = a stone on the board after replay; captured and poofed
    // cells are free again.
    NSMutableArray<NSNumber *> *occupied = [[NSMutableArray alloc] init];
    for (int y = 0; y < 19; ++y) {
        for (int x = 0; x < 19; ++x) {
            if (abstractBoard[y][x] != 0) {
                [occupied addObject:@(y * 19 + x)];
            }
        }
    }
    [dbService positionDidChangeWithGame:[DBGameCatalog gameIdForName:game]
                                   moves:line.moves
                                occupied:occupied];
    if (!didAutoPresentResults && [self presentResultsSheet]) {
        didAutoPresentResults = YES;
    }
}

- (UIImage *)heatButtonImage {
    NSString *name = dbService.preferences.heatOnBoard ? @"flame.fill" : @"flame";
    return [UIImage systemImageNamed:name];
}

/// Flips the board-heat preference. No refetch: currentHeat is [:] while a
/// request is in flight, so this never paints stale dots.
- (void)toggleHeat {
    DBPreferences *prefs = dbService.preferences;
    prefs.heatOnBoard = !prefs.heatOnBoard;
    heatButton.image = [self heatButtonImage];
    [self applyHeat:dbService.currentHeat];
}

/// Two-line title: "Database" over the game name and capture counts.
- (void)refreshTitleView {
    if (dbTitleLabel == nil) {
        dbTitleLabel = [[UILabel alloc] init];
        dbTitleLabel.font = [UIFont boldSystemFontOfSize:15];
        dbTitleLabel.textAlignment = NSTextAlignmentCenter;
        dbTitleLabel.text = NSLocalizedString(@"Database", nil);
        dbSubtitleLabel = [[UILabel alloc] init];
        dbSubtitleLabel.textAlignment = NSTextAlignmentCenter;
        dbSubtitleLabel.adjustsFontSizeToFitWidth = YES;
        dbSubtitleLabel.minimumScaleFactor = 0.7;
        UIStackView *stack = [[UIStackView alloc]
            initWithArrangedSubviews:@[ dbTitleLabel, dbSubtitleLabel ]];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.frame = CGRectMake(0, 0, 200, 36);
        self.navigationItem.titleView = stack;
    }
    dbSubtitleLabel.attributedText = [DBSubtitleFormatter
        attributedSubtitleWithGame:[DBGameCatalog gameIdForName:game]
                             moves:movesList ?: @[]
                              font:[UIFont systemFontOfSize:12]];
}

- (void)applyHeat:(NSDictionary<NSNumber *, UIColor *> *)heat {
    NSDictionary<NSNumber *, UIColor *> *options =
        (dbService.preferences.heatOnBoard && heat.count > 0) ? heat : nil;
    [board setDbOptions:options];
    [zoomedBoard setDbOptions:options];
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
}

- (void)statsStateChanged:(DBLoadState)state {
    [self.resultsVC showState:state];
    if (state == DBLoadStateLoaded || state == DBLoadStateEmpty) {
        [self.resultsVC reload];
    }
    dbStatusLabel.hidden = YES;
    dbRetryButton.hidden = YES;
    switch (state) {
    case DBLoadStateUnsupported:
        dbStatusLabel.text = NSLocalizedString(@"Not supported yet", nil);
        dbStatusLabel.hidden = NO;
        break;
    case DBLoadStateFailed:
        dbRetryButton.hidden = NO;
        break;
    case DBLoadStateSubscriptionRequired:
        [self showSubscriptionRequired];
        break;
    case DBLoadStateUnauthorized:
        [self showLogInAgain];
        break;
    default:
        break;
    }
}

/// Games search state: the results VC shows it; 401 and subscription raise
/// the same once-per-screen alerts as position-stats.
- (void)gamesStateChanged:(DBLoadState)state {
    [self.resultsVC showGamesState:state isLoadMore:dbService.gamesStateIsLoadMore];
    if (state == DBLoadStateSubscriptionRequired) {
        [self showSubscriptionRequired];
    } else if (state == DBLoadStateUnauthorized) {
        [self showLogInAgain];
    }
}

/// A Games row was tapped. iPhone: the sheet goes away first and comes back
/// (same retained VC, same tab and scroll offset) in viewDidAppear. iPad:
/// the inline panel is a child view, so the viewer is just pushed.
- (void)openGame:(int64_t)gid {
    DBGameViewerViewController *viewer = [dbService makeGameViewerWithGid:gid];
    __weak typeof(self) weakSelf = self;
    viewer.onUnauthorized = ^(UIViewController *presenter) {
        [presenter presentViewController:[weakSelf logInAlert]
                                animated:YES
                              completion:nil];
    };
    viewer.onSubscriptionRequired = ^(UIViewController *presenter) {
        [presenter presentViewController:[weakSelf subscriptionAlertOpeningStoreFrom:presenter]
                                animated:YES
                              completion:nil];
    };
    if (gameViewerPusher != nil) {
        gameViewerPusher(viewer);
        return;
    }
    [self dismissResultsSheetForPush];
    [self.navigationController pushViewController:viewer animated:YES];
}

/// Dismisses the compact-width results sheet (if up) so a pushed screen
/// does not sit under it; viewDidAppear re-presents it on return.
- (void)dismissResultsSheetForPush {
    if (self.resultsVC.presentingViewController != nil &&
        self.resultsVC.parentViewController == nil) {
        wasShowingResultsSheet = YES;
        [self.resultsVC dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)retryPositionStats:(UIButton *)sender {
    [self positionChanged];
}

- (UIViewController *)alertPresenter {
    return self.presentedViewController ?: self;
}

/// Same copy as GamesTableViewController's openDatabase gate. Shown once per
/// screen so every swipe does not raise it again.
- (void)showSubscriptionRequired {
    if (didShowSubscriptionAlert || self.view.window == nil) {
        return;
    }
    didShowSubscriptionAlert = YES;
    [[self alertPresenter] presentViewController:[self subscriptionAlertOpeningStoreFrom:nil]
                                        animated:YES
                                      completion:nil];
}

/// "subscription info" opens the store from `presenter` (the game viewer),
/// or, when nil, from this screen with the results sheet out of the way:
/// the store pushes on the navigation stack and the sheet comes back in
/// viewDidAppear, instead of stacking a form sheet on the results sheet.
- (UIAlertController *)subscriptionAlertOpeningStoreFrom:(UIViewController *)presenter {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"Level up your game", nil)
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
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction
                         actionWithTitle:NSLocalizedString(@"dismiss", nil)
                                   style:UIAlertActionStyleCancel
                                 handler:nil]];
    __weak typeof(self) weakSelf = self;
    __weak UIViewController *weakPresenter = presenter;
    BOOL fromHost = presenter == nil;
    [alert addAction:[UIAlertAction
                         actionWithTitle:NSLocalizedString(
                                             @"subscription info", nil)
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *action) {
                                     if (!fromHost) {
                                         if (weakPresenter) {
                                             [StoreViewController presentFrom:weakPresenter];
                                         }
                                     } else {
                                         [weakSelf openStoreFromHost];
                                     }
                                 }]];
    return alert;
}

- (void)openStoreFromHost {
    [self dismissResultsSheetForPush];
    [StoreViewController presentFrom:self];
}

- (void)showLogInAgain {
    // Once per screen: several 401s in a row raise a single alert.
    if (didShowLogInAlert || (logInAlertPresenter == nil && self.view.window == nil)) {
        return;
    }
    didShowLogInAlert = YES;
    UIAlertController *alert = [self logInAlert];
    if (logInAlertPresenter != nil) {
        logInAlertPresenter(alert);
        return;
    }
    [[self alertPresenter] presentViewController:alert
                                        animated:YES
                                      completion:nil];
}

/// OK pops to the root screen (also from the pushed game viewer).
- (UIAlertController *)logInAlert {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"Please log in again", nil)
                         message:nil
                  preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction
                         actionWithTitle:@"OK"
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *action) {
                                     [weakSelf.navigationController
                                         popToRootViewControllerAnimated:YES];
                                 }]];
    return alert;
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation =
        self.view.window.windowScene.interfaceOrientation;
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

- (IBAction)goBackOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    [board setLastMove:-1];
    if ([line back]) {
        [self lineDidChange];
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

- (IBAction)goForwardOneMoveSwipe:(UISwipeGestureRecognizer *)sender {
    [board setLastMove:-1];
    if ([line forward]) {
        [self lineDidChange];
    }
}

/// Colours the placement stones for the side to move.
- (void)prepareStoneColor {
    if ([game containsString:@"Connect6"]) {
        if ((([movesList count] % 4) == 0) || (([movesList count] % 4) == 3)) {
            [stone setStoneColor:WHITE];
            [zoomedStone setStoneColor:WHITE];
        } else {
            [stone setStoneColor:BLACK];
            [zoomedStone setStoneColor:BLACK];
        }
    } else if ([movesList count] % 2 == 1) {
        [stone setStoneColor:BLACK];
        [zoomedStone setStoneColor:BLACK];
    } else {
        [stone setStoneColor:WHITE];
        [zoomedStone setStoneColor:WHITE];
    }
    [stone setNeedsDisplay];
    [zoomedStone setNeedsDisplay];
}

- (IBAction)boardTap:(UILongPressGestureRecognizer *)recognizer {
    int i, j;
    CGPoint currentPoint = [recognizer locationInView:self.board];
    float cellSize = self.board.bounds.size.width / 19;
    j = (int)floorf(currentPoint.x / cellSize);
    i = (int)floorf(currentPoint.y / cellSize);
    BOOL onBoard = i >= 0 && i < 19 && j >= 0 && j < 19;
    // A heat dot is played with a plain tap: no magnifier over it.
    BOOL onDot = onBoard && board.dbOptions[@(19 * i + j)] != nil;

    if (onDot && [recognizer state] != UIGestureRecognizerStateEnded) {
        [board setLastMove:-1];
        [self prepareStoneColor];
        [zoomedBoard setHidden:YES];
        [zoomedStone setHidden:YES];
        [horizontalLine setHidden:YES];
        [verticalLine setHidden:YES];
        [stone setHidden:YES];
        return;
    }

    switch ([recognizer state]) {
    case UIGestureRecognizerStateBegan:
        [board setLastMove:-1];
        [self prepareStoneColor];
        [zoomedBoard setHidden:NO];
        [stone setHidden:YES];
        if (abstractBoard[i][j] == 0) {
            [zoomedStone setHidden:NO];
            [horizontalLine setHidden:NO];
            [verticalLine setHidden:NO];
        }
        break;
    case UIGestureRecognizerStateEnded:
        [zoomedBoard setHidden:YES];
        if (onBoard && abstractBoard[i][j] == 0) {
            stone.center = CGPointMake(cellSize * j + cellSize / 2,
                                       cellSize * i + cellSize / 2);
            [zoomedStone setHidden:YES];
            [horizontalLine setHidden:YES];
            [verticalLine setHidden:YES];

            finalMove = 19 * i + j;
            if (!game) {
                game = [DBGameCatalog nameForGame:dbService.filterGameId];
            }
            if (!game) {
                game = @"Pente";
            }
            [self syncLineGame];
            [line play:finalMove];
            [self lineDidChange];
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
        // re-center the zoomed board. It is a subview of board, so use
        // board's own coordinates (board is centred, not at the origin).
        CGPoint boardMid = CGPointMake(CGRectGetMidX(board.bounds),
                                       CGRectGetMidY(board.bounds));
        zoomedBoard.center =
            CGPointMake(boardMid.x - (currentPoint.x - boardMid.x),
                        boardMid.y - (currentPoint.y - boardMid.y));
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"viewGameSegue"]) {
        boardController =
            (BoardViewController *)segue.destinationViewController;
        return;
    }
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
    playerStats.scrollView.contentOffset = CGPointMake(0, 0);
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:
                        (void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        NSString *urlString = navigationAction.request.URL.absoluteString;
        [LinkPolicy open:urlString from:self];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    BOOL allowed = [LinkPolicy shouldLoadInLocalWebView:navigationAction.request.URL
                                          linkActivated:NO
                                                   from:self];
    decisionHandler(allowed ? WKNavigationActionPolicyAllow
                            : WKNavigationActionPolicyCancel);
}

- (void)startThinking {
    // The AI's spinner goes up once the popover (and its onDismiss) is gone.
    if (messagePopover != nil) {
        [messagePopover dismissWithCompletion:^{
            [self beginThinking];
        }];
    } else {
        [self beginThinking];
    }
}

- (void)beginThinking {
    if (aiPlayer == nil) {
        //        NSLog(@"kitty");
        aiPlayer = [[MMAI alloc] init];
    }
    [aiPlayer reset];
    [aiPlayer
        setLevel:[aiSetupView.difficultyCell.detailTextLabel.text intValue]];
    [aiPlayer setSeat:1 + ([movesList count] % 2)];
    [aiPlayer setMoves:movesList];
    if (game) {
        if ([game isEqualToString:@"Pente"] ||
            [game isEqualToString:@"Speed Pente"]) {
            [aiPlayer setGame:1];
        } else if ([game containsString:@"Keryo-Pente"]) {
            [aiPlayer setGame:2];
        }
    } else {
        [aiPlayer setGame:([[DBGameCatalog nameForGame:dbService.filterGameId]
                               containsString:@"Keryo-Pente"]
                               ? 2
                               : 1)];
    }
    [self.progressView startAnimating];
    [self.view addSubview:self.progressView];
    [NSThread detachNewThreadSelector:@selector(getNewAImove)
                             toTarget:self
                           withObject:nil];
}

- (void)getNewAImove {
    // -getMove's return is a base-362 packed stone PAIR for Connect6 (game
    // 13/14), not a single board index (see MMAI.h) -- this screen only ever
    // sets game 1 (Pente) or 2 (Keryo-Pente) in -startThinking above, so
    // `finalMove` below is always a plain index, but must never be wired up
    // to Connect6 without unpacking it first.
    finalMove = [aiPlayer getMove];
    [self performSelectorOnMainThread:@selector(stopThinking)
                           withObject:nil
                        waitUntilDone:NO];
}
- (void)stopThinking {
    [board setLastMove:finalMove];
    if (game == nil) {
        game = [DBGameCatalog nameForGame:dbService.filterGameId];
    }
    [self syncLineGame];
    [line play:finalMove];
    [self lineDidChange];

    [progressView stopAnimating];
    [progressView removeFromSuperview];
}

- (void)updateCaptures {
    [whiteCapturesCountLabel
        setText:[NSString stringWithFormat:@"x %i", whiteCaptures]];
    [whiteCapturesCountLabel setNeedsDisplay];
    [blackCapturesCountLabel
        setText:[NSString stringWithFormat:@"x %i", blackCaptures]];
    [blackCapturesCountLabel setNeedsDisplay];
}

- (void)replayGame {
    [self resetBoard];
    int i = 0;
    if (game == nil) {
        game = [DBGameCatalog nameForGame:dbService.filterGameId];
    }
    [self refreshTitleView];
    for (NSNumber *move in movesList) {
        int rowCol = [move intValue];
        int color = (i % 2) + 1, opponentColor = (color == 2) ? 1 : 2;
        if ([game containsString:@"Connect6"]) {
            color = (((i % 4) == 0) || ((i % 4) == 3)) ? 1 : 2;
        }
        abstractBoard[rowCol / 19][rowCol % 19] = color;
        i += 1;
        if (![game containsString:@"Gomoku"] &&
            ![game containsString:@"Connect6"]) {
            if ([game containsString:@"Poof-Pente"] ||
                [game containsString:@"O-Pente"]) {
                [self detectPoof:color atPosition:rowCol];
            }
            if ([game containsString:@"O-Pente"]) {
                [self detectKeryoPoof:color atPosition:rowCol];
            }
            [self detectCaptureOfOpponent:opponentColor atPosition:rowCol];
            if ([game containsString:@"Keryo-Pente"] ||
                [game containsString:@"DK-Pente"] ||
                [game containsString:@"Swap2-Keryo"] ||
                [game containsString:@"O-Pente"]) {
                [self detectKeryoCaptureOfOpponent:opponentColor
                                        atPosition:rowCol];
            }
        } else {
            continue;
        }
    }
    if ([game containsString:@"G-Pente"] && [movesList count] == 2) {
        [penteGame maskGPenteOpening];
    } else if ([game containsString:@"G-Pente"] && [movesList count] == 3) {
        [penteGame unmaskGPenteOpening];
    }

    [board setAbstractBoard:abstractBoard];
    [zoomedBoard setAbstractBoard:abstractBoard];
    [board setNeedsDisplay];
    [zoomedBoard setNeedsDisplay];
    [self updateCaptures];
    moveStatsString = [[NSMutableString alloc] init];
    for (int i = 0; i < [movesList count]; ++i) {
        int rowCol = [[movesList objectAtIndex:i] intValue];
        if (i == 0) {
            [moveStatsString appendString:@"<b>1.</b> "];
        } else {
            if ([game containsString:@"Connect6"]) {
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
        }
        [moveStatsString
            appendString:[NSString
                             stringWithFormat:@"%c%d",
                                              coordinateLetters[rowCol % 19],
                                              19 - (rowCol / 19)]];
    }
    [playerStats
        loadHTMLString:[HEADERSTRING
                           stringByAppendingString:
                               [playerStatsBaseString
                                   stringByAppendingString:moveStatsString]]
               baseURL:nil];
}

- (void)detectCaptureOfOpponent:(int)opponentColor atPosition:(int)rowCol {
    penteGame.captures = nil;
    penteGame.whiteCaptures = whiteCaptures;
    penteGame.blackCaptures = blackCaptures;
    [penteGame detectCaptureOfOpponent:opponentColor atPosition:rowCol];
    whiteCaptures = penteGame.whiteCaptures;
    blackCaptures = penteGame.blackCaptures;
}

- (void)detectKeryoCaptureOfOpponent:(int)opponentColor atPosition:(int)rowCol {
    penteGame.captures = nil;
    penteGame.whiteCaptures = whiteCaptures;
    penteGame.blackCaptures = blackCaptures;
    [penteGame detectKeryoCaptureOfOpponent:opponentColor atPosition:rowCol];
    whiteCaptures = penteGame.whiteCaptures;
    blackCaptures = penteGame.blackCaptures;
}

- (BOOL)detectPoof:(int)myColor atPosition:(int)rowCol {
    penteGame.captures = captures;
    penteGame.whiteCaptures = whiteCaptures;
    penteGame.blackCaptures = blackCaptures;
    BOOL poof = [penteGame detectPoof:myColor atPosition:rowCol];
    whiteCaptures = penteGame.whiteCaptures;
    blackCaptures = penteGame.blackCaptures;
    return poof;
}

- (BOOL)detectKeryoPoof:(int)myColor atPosition:(int)rowCol {
    penteGame.captures = captures;
    penteGame.whiteCaptures = whiteCaptures;
    penteGame.blackCaptures = blackCaptures;
    BOOL poof = [penteGame detectKeryoPoof:myColor atPosition:rowCol];
    whiteCaptures = penteGame.whiteCaptures;
    blackCaptures = penteGame.blackCaptures;
    return poof;
}

- (void)resetBoard {
    [penteGame resetBoard];
    [captures removeAllObjects];
    whiteCaptures = 0;
    blackCaptures = 0;
    [self updateCaptures];
}

- (void)resetState {
    moveStatsString = [[NSMutableString alloc] init];
    [moveStatsString appendString:@"<b>1.</b> K10"];
    [playerStats
        loadHTMLString:[HEADERSTRING
                           stringByAppendingString:
                               [playerStatsBaseString
                                   stringByAppendingString:moveStatsString]]
               baseURL:nil];
    [self resetBoard];
    abstractBoard[9][9] = 1;
    [movesList removeAllObjects];
    [movesList addObject:[NSNumber numberWithInt:180]];
    [line resetWithMoves:@[ @180 ]];
    [board setAbstractBoard:abstractBoard];
    [zoomedBoard setAbstractBoard:abstractBoard];
    [board setNeedsDisplay];
}

/// Opens the filters sheet over whatever is up (the iPhone results sheet
/// included). Compact width: .medium/.large sheet; regular: form sheet.
- (void)showSetup {
    __weak typeof(self) weakSelf = self;
    UIViewController *filters =
        [dbService makeFiltersViewControllerWithRegularWidth:[self usesInlineResults]
                                                   onApplied:^(BOOL gameChanged) {
                                                       [weakSelf filtersApplied:gameChanged];
                                                   }];
    if (filtersPresenter != nil) {
        filtersPresenter(filters);
        return;
    }
    if (self.view.window == nil) {
        return;
    }
    [[self alertPresenter] presentViewController:filters animated:YES completion:nil];
}

/// The service already saved and adopted the filters. A new game resets
/// the line to the centre stone (legacy resetState) and recolours; then
/// both requests refire at offset 0 and the chip row follows.
- (void)filtersApplied:(BOOL)gameChanged {
    if (gameChanged) {
        game = [DBGameCatalog nameForGame:dbService.filterGameId];
        [self resetState];
        [self syncLineGame];
        [self setBoardColor];
        [self replayGame];
    }
    [self positionChanged];
    [self refreshChipRow];
}

- (void)refreshChipRow {
    [dbChipButton setTitle:dbService.filterChipSummary forState:UIControlStateNormal];
}

- (void)askAI:(UIButton *)sender {
    if (!aiSetupView) {
        aiSetupView = [[DBAISetupView alloc]
            initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width * 2 / 3,
                                     147)];
        //        aiSetupView.layer.cornerRadius = 5.0f;
        //        aiSetupView.layer.borderWidth = 1.0f;
        [aiSetupView setScrollEnabled:NO];
        [aiSetupView setDelegate:aiSetupView];
        [aiSetupView setDataSource:aiSetupView];
        [aiSetupView setVc:self];
    }
    messagePopover = [PentePopover
        showContentView:aiSetupView
                  title:NSLocalizedString(@"ask the AI", nil)
                atPoint:CGPointMake(aiButton.center.x, aiButton.frame.origin.y)
                 inView:self.view
              onDismiss:[self aiPopoverOnDismiss]];
}

/// The "ask the AI" popover only refreshes the AI button for the current
/// game. It must not re-read the setup view's game cell or refetch.
- (void (^)(void))aiPopoverOnDismiss {
    __weak typeof(self) weakSelf = self;
    return ^{
        [weakSelf updateAIButtonVisibility];
    };
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

@end
