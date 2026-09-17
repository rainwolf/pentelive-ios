//
//  AppDelegate.h
//  test1
//
//  Created by Walied Othman on 23/07/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
@import AudioToolbox;

// Forward declaration, deliberately NOT an #import: PenteNavigationViewController.h
// already imports this header, so importing it back here would form a cycle. The
// #import lives in AppDelegate.m, which already has it.
@class PenteNavigationViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property(retain, nonatomic, readwrite, nullable) NSDictionary *notification;
@property(atomic) SystemSoundID sndID, broadcastSndID;

/// The root navigation controller of the active window scene.
///
/// Replaces the retired app-global @c window property: there is no longer one
/// window that belongs to the application, so the root view controller is
/// resolved per scene, at the moment it is asked for. Returns nil when no window
/// scene is connected yet (notably during
/// -application:didFinishLaunchingWithOptions:, which runs before
/// -scene:willConnectToSession:options:) or when the scene's root view
/// controller is not a PenteNavigationViewController. Callers must nil-check.
+ (nullable PenteNavigationViewController *)rootNavigationController;

@end
