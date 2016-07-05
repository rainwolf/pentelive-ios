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
