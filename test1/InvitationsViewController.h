//
//  InvitationsViewController.h
//  test1
//
//  Created by rainwolf on 31/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StringInputTableViewCell.h"
#import "SimplePickerInputTableViewCell.h"
#import "PopoverView.h"

@interface InvitationsViewController : UITableViewController <StringInputTableViewCellDelegate, SimplePickerInputTableViewCellDelegate, UITextViewDelegate, PopoverViewDelegate> {
    NSArray *games, *colors, *restrictions;
    NSMutableArray *moveDurations;
    UITextView *invitationMessageView;
    PopoverView *messagePopover;
    NSString *invitationMessage, *challengedOpponent, *game;
    BOOL openInvitationOnly;
}
@property(nonatomic,retain) NSArray *games;
@property(nonatomic,retain) NSArray *restrictions;
@property(nonatomic,retain) NSArray *moveDurations;
@property(nonatomic,retain) NSArray *colors;
@property(nonatomic,retain) UITextView *invitationMessageView;
@property(nonatomic,retain) PopoverView *messagePopover;
@property(nonatomic,retain) NSString *invitationMessage, *challengedOpponent, *game;
@property(atomic) BOOL openInvitationOnly;
@property (weak, nonatomic) IBOutlet UISwitch *ratedSwitch;
@property (weak, nonatomic) IBOutlet UILabel *sendCell;
@property (weak, nonatomic) IBOutlet SimplePickerInputTableViewCell *timeCell;
@property (weak, nonatomic) IBOutlet SimplePickerInputTableViewCell *gameCell;
@property (weak, nonatomic) IBOutlet StringInputTableViewCell *opponentCell;
@property (weak, nonatomic) IBOutlet UISwitch *privateSwitch;
@property (weak, nonatomic) IBOutlet SimplePickerInputTableViewCell *playAsCell;
@property (weak, nonatomic) IBOutlet UILabel *playAsLabel;
@property (weak, nonatomic) IBOutlet UILabel *playAsDetailLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *privateCell;
@property (weak, nonatomic) IBOutlet UILabel *privateCellLabel;
- (IBAction)flipPrivateSwitch:(id)sender;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (weak, nonatomic) IBOutlet SimplePickerInputTableViewCell *restrictionCell;


- (IBAction)flipRatedSwitch:(id)sender;

@end
