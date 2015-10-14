//
//  StringInputTableViewCell.h
//  ShootStudio
//
//  Created by Tom Fewster on 19/10/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HTAutocompleteTextField.h"

@class StringInputTableViewCell;

@protocol StringInputTableViewCellDelegate <NSObject>
@optional
- (void)tableViewCell:(StringInputTableViewCell *)cell didEndEditingWithString:(NSString *)value;
@end


@interface StringInputTableViewCell : UITableViewCell <UITextFieldDelegate,HTAutocompleteDataSource> {
	HTAutocompleteTextField *textField;
    NSMutableArray *invitedHistory;
}

@property (nonatomic, strong) NSString *stringValue;
@property (nonatomic, strong) HTAutocompleteTextField *textField;
@property (weak) IBOutlet id<StringInputTableViewCellDelegate> delegate;
@property(nonatomic,retain) NSMutableArray *invitedHistory;

@end
