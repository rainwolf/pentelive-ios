//
//  main.m
//  test1
//
//  Created by Walied Othman on 23/07/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#import "penteLive-Swift.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // Unit-test host only: refuse every non-localhost request before any
        // app code (delegates, view controllers, services) can issue one.
        if ([AppDelegate isRunningUnitTests]) {
            [PenteTestNetworkTripwire install];
        }
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([AppDelegate class]));
    }
}
