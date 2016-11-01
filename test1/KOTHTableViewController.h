//
//  KOTHTableViewController.h
//  penteLive
//
//  Created by rainwolf on 02/07/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PentePlayer.h"
@import GoogleMobileAds;
#import "PopoverView.h"
#import "KOTHChallengeView.h"

@class Hill;

@interface Player : NSObject {
    NSString *name, *rating, *lastGame, *numberOfGames;
    BOOL canBeChallenged;
    int crown, color;
}
@property(retain, nonatomic, readwrite) NSString *name, *rating, *lastGame, *numberOfGames;
@property(assign, atomic, readwrite) BOOL canBeChallenged;
@property(assign, atomic, readwrite) int crown, color;
@end


@interface KOTHTableViewController : UITableViewController <GADBannerViewDelegate, PopoverViewDelegate, UIScrollViewDelegate> {
    Hill *hill;
    KingOfTheHill *hillSummary;
    PentePlayer *player;
    GADBannerView *bannerView;
    PopoverView *actionPopoverView;
    KOTHChallengeView *challengeView;
}

@property(nonatomic, retain, readwrite) PentePlayer *player;
@property(nonatomic, retain, readwrite) Hill *hill;
@property(nonatomic, retain, readwrite) KingOfTheHill *hillSummary;
@property(nonatomic,retain) GADBannerView *bannerView;
@property(nonatomic, retain, readwrite) PopoverView *actionPopoverView;
@property(nonatomic, retain, readwrite) KOTHChallengeView *challengeView;

@end
