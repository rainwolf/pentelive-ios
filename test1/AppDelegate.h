//
//  AppDelegate.h
//  test1
//
//  Created by Walied Othman on 23/07/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PenteNavigationViewController.h"
#import "TSMessage.h"
#import "TSMessageView.h"
#import "AudioToolbox/AudioServices.h"


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (retain, nonatomic, readwrite) NSDictionary *notification;
@property (atomic) SystemSoundID sndID;

@end
