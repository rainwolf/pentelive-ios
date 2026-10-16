//
//  PenteNavigationViewController.m
//  test1
//
//  Created by rainwolf on 09/01/13.
//  Copyright (c) 2013 Triade. All rights reserved.
//

#import "PenteNavigationViewController.h"
#import "penteLive-Swift.h"

@interface PenteNavigationViewController ()

@end

@implementation PenteNavigationViewController
@synthesize loggedIn;
@synthesize didMove;
@synthesize messageDeleted;
@synthesize needHelp;
@synthesize deletedMessageRow;
//@synthesize bannerView;
@synthesize activeGameToRemove;
@synthesize challengeCancelled;
@synthesize unchallengedMessageID;
@synthesize challengedUser;
@synthesize receivedNotification;
@synthesize player;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (BOOL)loggedIn {
    return loggedIn;
}

// Every login (launch, Settings, account switch) and every logout goes
// through here.
- (void)setLoggedIn:(BOOL)value {
    loggedIn = value;
    self.loggedInUsername =
        value ? [[[NSUserDefaults standardUserDefaults] stringForKey:@"username"]
                    lowercaseString]
              : nil;
    // The Store forgets the previous account's info, and after login posts
    // what StoreKit still holds, with the once-per-account migration sweep
    // (spec 5.1, 5.4). Only a started service: never in the unit-test host.
    if ([StoreService shared].isStarted) {
        [[StoreService shared] sessionDidChangeWithLoggedIn:value];
    }
}

//- (BOOL)shouldAutorotate {
//    return [self.visibleViewController shouldAutorotate];
//}
//-(NSUInteger)supportedInterfaceOrientations {
//    return [self.visibleViewController supportedInterfaceOrientations];
//}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    loggedIn = NO;
    didMove = NO;
    messageDeleted = NO;
    challengeCancelled = NO;
    needHelp = NO;
    self.player = [[PentePlayer alloc] init];
    //    NSLog(@"kitty2");

    AppDelegate *appDelegate =
        (AppDelegate *)[[UIApplication sharedApplication] delegate];
    receivedNotification = appDelegate.notification;

    //    CGPoint origin = CGPointMake(0.0, self.view.frame.size.height -
    //    self.navigationController.navigationBar.frame.size.height -
    //    kGADAdSizeBanner.size.height); bannerView = [[GADBannerView alloc]
    //    initWithAdSize:kGADAdSizeBanner origin:origin];
    ////    bannerView.adUnitID = @"567b72e8189a488c";
    //    bannerView.adUnitID = @"ca-app-pub-3326997956703582/8641559446";
    //    bannerView.rootViewController = self;
    //    GADRequest *request = [GADRequest request];
    //    request.testDevices = [NSArray arrayWithObjects:kGADSimulatorID, nil];
    //    [bannerView loadRequest:request];

    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance =
            [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        [appearance setBackgroundColor:[UIColor grayColor]];
        [self.navigationBar setStandardAppearance:appearance];
        [self.navigationBar
            setScrollEdgeAppearance:self.navigationBar.standardAppearance];
    } else {
        // Fallback on earlier versions
        self.navigationBar.tintColor = [UIColor grayColor];
    }
    [self.navigationBar setTranslucent:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//- (void)adViewWillLeaveApplication:(GADBannerView *)bannerViewl {
//    NSLog(@"... leaving penteLive for an ad");
//    NSLog(@"The ad's adNetworkClassName: %@", bannerViewl.adNetworkClassName);
//    NSLog(@"The ad's adUnitID: %@", bannerViewl.adUnitID);
//}

@end
