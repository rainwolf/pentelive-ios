//
//  PenteNavigationViewController.h
//  test1
//
//  Created by rainwolf on 09/01/13.
//  Copyright (c) 2013 Triade. All rights reserved.
//

//@import GoogleMobileAds;
#import <UIKit/UIKit.h>
@import StoreKit;
//#import <GoogleMobileAds/GoogleMobileAds.h>
#import "AppDelegate.h"
#import "PentePlayer.h"


@interface PenteNavigationViewController : UINavigationController {
    BOOL loggedIn, didMove, messageDeleted, challengeCancelled, needHelp;
    int deletedMessageRow;
    NSString *activeGameToRemove, *unchallengedMessageID, *challengedUser;
//    GADBannerView *bannerView;
    NSDictionary *receivedNotification;
    PentePlayer *player;
    SKProduct *subscription;
}
@property(nonatomic,retain) NSString *activeGameToRemove, *unchallengedMessageID, *challengedUser;
@property BOOL loggedIn, didMove, messageDeleted, challengeCancelled, needHelp;
@property int deletedMessageRow;
//@property(nonatomic,retain) GADBannerView *bannerView;
@property(nonatomic,retain) NSDictionary *receivedNotification;
@property(nonatomic,retain) PentePlayer *player;
@property(nonatomic,retain) SKProduct *subscription;

//- (void)adViewWillLeaveApplication:(GADBannerView *)bannerViewl;

@end
