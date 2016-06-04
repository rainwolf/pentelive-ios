//
//  ViewController.h
//  test1
//
//  Created by Walied Othman on 23/07/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BoardView.h"
#import "PenteNavigationViewController.h"
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "PopoverView.h"

//#define IS_IPHONE_5 ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )

@interface BoardViewController : UIViewController <GADBannerViewDelegate, UITextViewDelegate, PopoverViewDelegate, UIWebViewDelegate, UIAlertViewDelegate> {
    Game *game;
    GADBannerView *bannerView;
    BOOL showedAd;
    NSMutableArray *movesList, *captures, *receivedMessages;
    NSString *receivedMessage, *replyMessage, *playerStatsBaseString;
    NSMutableString *moveStatsString;
    UIImageView *messageButtonImageView;
    UITextView *receivedMessageView, *replyMessageView;
    UIWebView *playerStats;
    PopoverView *messagePopover;
    NSMutableDictionary *messagesHistory;
    BOOL activeGame, isLastMove, showAds;
}
@property(atomic) BOOL showedAd;
@property(atomic) BOOL activeGame, isLastMove;
@property(atomic) BOOL showAds;
@property(nonatomic,retain) Game *game;
@property(nonatomic,retain) GADBannerView *bannerView;
@property(nonatomic,retain) NSMutableArray *movesList, *captures, *receivedMessages;
@property(nonatomic, retain) NSString *receivedMessage, *replyMessage, *playerStatsBaseString;
@property(nonatomic, retain) NSMutableString *moveStatsString;
@property(nonatomic,retain) NSDictionary *messagesHistory;
//@property(nonatomic,retain) GamesTableViewController *gamesTable;
@property (weak, nonatomic) IBOutlet BoardView *board;
@property (weak, nonatomic) IBOutlet BoardView *zoomedBoard;
@property (weak, nonatomic) IBOutlet StoneView *stone;
@property (weak, nonatomic) IBOutlet StoneView *zoomedStone;
@property (weak, nonatomic) IBOutlet VerticalLine *verticalLine;
@property (weak, nonatomic) IBOutlet HorizontalLine *horizontalLine;
@property (weak, nonatomic) IBOutlet UIButton *submitButton;
@property (weak, nonatomic) IBOutlet UIButton *player2Button;
@property (weak, nonatomic) IBOutlet UIButton *player1Button;
@property (weak, nonatomic) IBOutlet UILabel *dPenteChoiceLabel;
@property (weak, nonatomic) IBOutlet UILabel *whiteCapturesCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *blackCapturesCountLabel;
@property (weak, nonatomic) IBOutlet StoneView *whiteStoneCaptures;
@property (weak, nonatomic) IBOutlet StoneView *blackStoneCaptures;
- (IBAction)dPentePlayer1:(id)sender;
- (IBAction)dPentePlayer2:(id)sender;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property(nonatomic,retain) UIImageView *messageButtonImageView;
@property(nonatomic,retain) UITextView *receivedMessageView, *replyMessageView;
@property(nonatomic,retain) UIWebView *playerStats;
@property(nonatomic,retain) PopoverView *messagePopover;
- (IBAction)goForwardOneMoveSwipe:(UISwipeGestureRecognizer *)sender;
- (IBAction)goBackOneMoveSwipe:(UISwipeGestureRecognizer *)sender;

@property (strong, nonatomic) IBOutlet UILongPressGestureRecognizer *boardTapRecognizer;

- (IBAction)boardTap:(UILongPressGestureRecognizer *)recognizer;
//- (IBAction)zoomGesture:(UIPanGestureRecognizer *)recognizer;
- (IBAction)submitMove:(id)sender;
-(void) replayGame;
//-(void) replayGame: (int) untilMove;
//-(void) replayPenteGame: (int) untilMove;
//-(void) replayGPenteGame: (int) untilMove;
//-(void) replayKeryoPenteGame: (int) untilMove;
//-(void) replayGomokuGame: (int) untilMove;
//-(void) replayConnect6Game: (int) untilMove;
//-(void) replayDPenteGame: (int) untilMove;
//-(void) replayPoofPenteGame: (int) untilMove;
//-(void) submitMoveToServer;
//-(int) parseMove: (NSString *) move;
//-(void) resetBoard;
//-(void) detectCaptureOfOpponent: (int) opponentColor atPosition: (int) rowCol;
//-(void) detectKeryoCaptureOfOpponent: (int) opponentColor atPosition: (int) rowCol;
//-(BOOL) detectPoof: (int) myColor atPosition: (int) rowCol;
- (void)adViewWillPresentScreen:(GADBannerView *)bannerView;

@property (weak, nonatomic) IBOutlet UIButton *messageButton;
@end
