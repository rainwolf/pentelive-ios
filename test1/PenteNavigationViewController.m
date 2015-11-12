//
//  PenteNavigationViewController.m
//  test1
//
//  Created by rainwolf on 09/01/13.
//  Copyright (c) 2013 Triade. All rights reserved.
//

#import "PenteNavigationViewController.h"

@interface PenteNavigationViewController ()

@end

@implementation PenteNavigationViewController
@synthesize loggedIn;
@synthesize didMove;
@synthesize messageDeleted;
@synthesize needHelp;
@synthesize deletedMessageRow;
@synthesize bannerView;
@synthesize activeGameToRemove;
@synthesize challengeCancelled;
@synthesize unchallengedMessageID;
@synthesize challengedUser;
@synthesize receivedNotification;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

//- (BOOL)shouldAutorotate {
//    return [self.visibleViewController shouldAutorotate];
//}
//-(NSUInteger)supportedInterfaceOrientations {
//    return [self.visibleViewController supportedInterfaceOrientations];
//}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    loggedIn = NO;
    didMove = NO;
    messageDeleted = NO;
    challengeCancelled = NO;
    needHelp = NO;
//    NSLog(@"kitty2");

    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    receivedNotification = appDelegate.notification;
    
    [[UIApplication sharedApplication] setStatusBarHidden: NO withAnimation: YES];
    CGPoint origin = CGPointMake(0.0, self.view.frame.size.height - self.navigationController.navigationBar.frame.size.height - kGADAdSizeBanner.size.height);
    bannerView = [[GADBannerView alloc] initWithAdSize:kGADAdSizeBanner origin:origin];
//    bannerView.adUnitID = @"567b72e8189a488c";
    bannerView.adUnitID = @"ca-app-pub-3326997956703582/8641559446";
    bannerView.rootViewController = self;
    GADRequest *request = [GADRequest request];
//    [request setTesting:YES];
//    request.testDevices = [NSArray arrayWithObjects:kGADSimulatorID, nil];
    [bannerView loadRequest:request];
    self.navigationBar.tintColor = [UIColor grayColor];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//- (void)adViewWillLeaveApplication:(GADBannerView *)bannerViewl {
//    NSLog(@"... leaving penteLive for an ad");
//    NSLog(@"The ad's adNetworkClassName: %@", bannerViewl.adNetworkClassName);
//    NSLog(@"The ad's adUnitID: %@", bannerViewl.adUnitID);
//}

@end
