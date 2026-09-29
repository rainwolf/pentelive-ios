//
//  PenteNavigationViewController.h
//  test1
//
//  Created by rainwolf on 09/01/13.
//  Copyright (c) 2013 Triade. All rights reserved.
//

//@import GoogleMobileAds;
#import <UIKit/UIKit.h>
// #import <GoogleMobileAds/GoogleMobileAds.h>
#import "AppDelegate.h"
#import "PentePlayer.h"

// Swift class bridged to ObjC via penteLive-Swift.h (imported in the .m files).
@class SubscriptionProduct;

@interface PenteNavigationViewController : UINavigationController {
    BOOL loggedIn, didMove, messageDeleted, challengeCancelled, needHelp,
        showSubscribe;
    int deletedMessageRow;
    NSString *activeGameToRemove, *unchallengedMessageID, *challengedUser;
    //    GADBannerView *bannerView;
    NSDictionary *receivedNotification;
    PentePlayer *player;
    SubscriptionProduct *subscription;
}
@property(nonatomic, retain) NSString *activeGameToRemove,
    *unchallengedMessageID, *challengedUser;
@property BOOL loggedIn, didMove, messageDeleted, challengeCancelled, needHelp,
    showSubscribe;
@property int deletedMessageRow;
//@property(nonatomic,retain) GADBannerView *bannerView;
@property(nonatomic, retain) NSDictionary *receivedNotification;
@property(nonatomic, retain) PentePlayer *player;
@property(nonatomic, retain) SubscriptionProduct *subscription;

//- (void)adViewWillLeaveApplication:(GADBannerView *)bannerViewl;

@end
