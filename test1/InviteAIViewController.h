//
//  InvitationsViewController.h
//  test1
//
//  Created by rainwolf on 31/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SimplePickerInputTableViewCell.h"

@interface InviteAIViewController : UITableViewController <SimplePickerInputTableViewCellDelegate> {
    NSMutableArray<NSString *> *games, *colors, *difficulties;
    NSString *game;
    BOOL openInvitationOnly;
}
@property(nonatomic,retain) NSMutableArray<NSString *> *games, *difficulties, *colors;
@property(nonatomic,retain) NSString *game;
@property(atomic) BOOL openInvitationOnly;
@property (weak, nonatomic) IBOutlet UISwitch *ratedSwitch;
@property (weak, nonatomic) IBOutlet UILabel *sendLabel;
@property (weak, nonatomic) IBOutlet SimplePickerInputTableViewCell *gameCell;
@property (weak, nonatomic) IBOutlet SimplePickerInputTableViewCell *opponentCell;
@property (weak, nonatomic) IBOutlet SimplePickerInputTableViewCell *playAsCell;
@property (weak, nonatomic) IBOutlet UITableViewCell *ratedCell;
@property (weak, nonatomic) IBOutlet UILabel *playAsLabel;
@property (weak, nonatomic) IBOutlet UILabel *playAsDetailLabel;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@end
