//
//  ShootStatusInputTableViewCell.h
//  ShootStudio
//
//  Created by Tom Fewster on 18/10/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PickerInputTableViewCell;


@interface PickerInputTableViewCell : UITableViewCell <UIKeyInput, UIPopoverControllerDelegate> {
	// For iPad
	UIPopoverController *popoverController;
	UIToolbar *inputAccessoryView;
    UIPickerView *picker;
    BOOL resign;
}
@property(atomic) BOOL resign;
@property (nonatomic, strong) UIPickerView *picker;
@property (nonatomic, retain) UIPopoverController *popoverController;

- (void) doResign;

@end
