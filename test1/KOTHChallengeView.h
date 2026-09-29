//
//  RatingStatsView.h
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "PentePopover.h"
#import "SimplePickerInputTableViewCell.h"
#import "penteLive-Swift.h"
#import <UIKit/UIKit.h>

@interface KOTHChallengeView
    : UITableView <UITableViewDelegate, UITableViewDataSource,
                   UIPickerViewDataSource, UIPickerViewDelegate> {
    InputPickerCell *timeoutCell, *restrictionCell;
    PentePopover *popover;
    NSString *invitee;
    int gameId;
}
@property(nonatomic, retain, readwrite) InputPickerCell *timeoutCell,
    *restrictionCell;
@property(nonatomic, retain, readwrite) PentePopover *popover;
@property(nonatomic, retain, readwrite) NSString *gameStr, *invitee;
@property(atomic, assign, readwrite) int gameId;
- (void)dismissPicker:(id)sender;

@end
