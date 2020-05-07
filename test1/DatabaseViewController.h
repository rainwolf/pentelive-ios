//
//  ViewController.h
//  test1
//
//  Created by Walied Othman on 23/07/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DBBoardView.h"
#import "BoardView.h"
#import "PenteNavigationViewController.h"
#import <GoogleMobileAds/GoogleMobileAds.h>
#import "PopoverView.h"
#import "DBSetupView.h"
#import "DBAISetupView.h"
#import "ICDMaterialActivityIndicatorView.h"
@class MMAI;

//#define IS_IPHONE_5 ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )

@interface DatabaseViewController : UIViewController <GADBannerViewDelegate, PopoverViewDelegate, UIAlertViewDelegate, WKNavigationDelegate> {
    GADBannerView *bannerView;
    BOOL showedAd;
    NSMutableArray *movesList, *captures;
    NSString *playerStatsBaseString, *game;
    NSMutableString *moveStatsString;
    WKWebView *playerStats;
    PopoverView *messagePopover;
    BOOL activeGame, showAds;
    MMAI *aiPlayer;
    DBSetupView *setupView;
    DBAISetupView *aiSetupView;
    ICDMaterialActivityIndicatorView *progressView;
    UIButton *aiButton;
    
}
@property(atomic) BOOL showedAd;
@property(atomic) BOOL activeGame;
@property(atomic) BOOL showAds;
@property(nonatomic,retain) GADBannerView *bannerView;
@property(nonatomic,retain) NSMutableArray *movesList, *captures;
@property(nonatomic, retain) NSString *playerStatsBaseString, *game;
@property(nonatomic, retain) NSMutableString *moveStatsString;
@property (weak, nonatomic) IBOutlet DBBoardView *board;
@property (weak, nonatomic) IBOutlet DBBoardView *zoomedBoard;
@property (weak, nonatomic) IBOutlet StoneView *stone;
@property (weak, nonatomic) IBOutlet StoneView *zoomedStone;
@property (weak, nonatomic) IBOutlet VerticalLine *verticalLine;
@property (weak, nonatomic) IBOutlet HorizontalLine *horizontalLine;
@property (weak, nonatomic) IBOutlet UILabel *whiteCapturesCountLabel;
@property (weak, nonatomic) IBOutlet UILabel *blackCapturesCountLabel;
@property (weak, nonatomic) IBOutlet StoneView *whiteStoneCaptures;
@property (weak, nonatomic) IBOutlet StoneView *blackStoneCaptures;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property(nonatomic,retain) WKWebView *playerStats;
@property(nonatomic,retain) PopoverView *messagePopover;
- (IBAction)goBackOneMoveSwipe:(UISwipeGestureRecognizer *)sender;

@property (strong, nonatomic) IBOutlet UILongPressGestureRecognizer *boardTapRecognizer;

- (IBAction)boardTap:(UILongPressGestureRecognizer *)recognizer;
- (void)adViewWillPresentScreen:(GADBannerView *)bannerView;

@property(nonatomic, retain, readwrite) MMAI *aiPlayer;
@property(nonatomic, retain, readwrite) DBSetupView *setupView;
@property(nonatomic, retain, readwrite) DBAISetupView *aiSetupView;
@property (strong,nonatomic) ICDMaterialActivityIndicatorView *progressView;
@property(nonatomic, retain, readwrite) UIButton *aiButton;
-(void) startThinking;

@end
