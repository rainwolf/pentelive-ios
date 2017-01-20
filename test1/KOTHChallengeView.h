//
//  RatingStatsView.h
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SimplePickerInputTableViewCell.h"
#import "PopoverView.h"


@interface KOTHChallengeView : UITableView <UITableViewDelegate, UITableViewDataSource, SimplePickerInputTableViewCellDelegate> {
    SimplePickerInputTableViewCell *timeoutCell, *restrictionCell;
    PopoverView *popoverView;
    NSString *invitee;
    int gameId;
}
@property(nonatomic, retain, readwrite) SimplePickerInputTableViewCell *timeoutCell, *restrictionCell;
@property(nonatomic, retain, readwrite) PopoverView *popoverView;
@property(nonatomic, retain, readwrite) NSString *gameStr, *invitee;
@property(atomic, assign, readwrite) int gameId;

@end
