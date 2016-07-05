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
    SimplePickerInputTableViewCell *timoutCell;
    PopoverView *popoverView;
    NSString *gameStr, *invitee;
}
@property(nonatomic, retain, readwrite) SimplePickerInputTableViewCell *timoutCell;
@property(nonatomic, retain, readwrite) PopoverView *popoverView;
@property(nonatomic, retain, readwrite) NSString *gameStr, *invitee;

@end
