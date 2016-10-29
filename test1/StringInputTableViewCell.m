//
//  StringInputTableViewCell.m
//  ShootStudio
//
//  Created by Tom Fewster on 19/10/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "StringInputTableViewCell.h"

@implementation StringInputTableViewCell

@synthesize delegate;
@synthesize stringValue;
@synthesize textField;
@synthesize invitedHistory;

- (void)initalizeInputView {
	// Initialization code
	self.selectionStyle = UITableViewCellSelectionStyleNone;
	self.textField = [[HTAutocompleteTextField alloc] initWithFrame:CGRectMake(self.frame.size.width*4/9, (self.frame.size.height - [UIFont systemFontOfSize:17.0f].lineHeight) / 2 , self.frame.size.width - self.frame.size.width*4/9 -10, [UIFont systemFontOfSize:17.0f].lineHeight)];
	[self addSubview:self.textField];
	self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
	self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.textField.returnKeyType = UIReturnKeyDone;
	self.textField.textAlignment = NSTextAlignmentLeft;
	self.textField.textColor = [UIColor blueColor];
	self.textField.font = [UIFont systemFontOfSize:17.0f];
	self.textField.clearButtonMode = UITextFieldViewModeNever;
//	self.textField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.accessoryType = UITableViewCellAccessoryNone;
	self.textField.delegate = self;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.invitedHistory = [defaults objectForKey:@"invitedHistory"];
//    NSMutableArray *testArray = [NSMutableArray arrayWithObjects:@"iostesterrrrrrrrrrrrrrrrrrr",@"iostest", @"selwa", nil];
    //    self.invitedHistory = (NSMutableArray *) [testArray sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    [self.textField setAutocompleteDataSource:self];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
		[self initalizeInputView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
		[self initalizeInputView];
    }
    return self;
}

- (void)setSelected:(BOOL)selected {
	[super setSelected:selected];
	if (selected) {
        self.textField.textAlignment = NSTextAlignmentLeft;
		[self.textField becomeFirstResponder];
	} else {
        self.textField.textAlignment = NSTextAlignmentRight;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	if (selected) {
        self.textField.textAlignment = NSTextAlignmentLeft;
		[self.textField becomeFirstResponder];
	} else {
        self.textField.textAlignment = NSTextAlignmentRight;
    }
}

- (void)setStringValue:(NSString *)value {
	self.textField.text = value;
}

- (NSString *)stringValue {
	return self.textField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	UITableView *tableView = (UITableView *)self.superview.superview;
    [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    [tableView setScrollEnabled:NO];
	return [self.textField resignFirstResponder];
//	return YES;
}

- (BOOL)resignFirstResponder {
    [self.textField resignFirstResponder];
    return [super resignFirstResponder];
}


-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
	self.textField.textAlignment = NSTextAlignmentLeft;
    return YES ;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
//    self.textField.frame = CGRectMake(self.frame.size.width/2, (self.frame.size.height - [UIFont systemFontOfSize:17.0f].lineHeight) / 2 , self.frame.size.width/2 -20, [UIFont systemFontOfSize:17.0f].lineHeight);
	self.textField.textAlignment = NSTextAlignmentLeft;
	UITableView *tableView = (UITableView *)self.superview.superview;
    [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    [tableView setScrollEnabled:NO];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
//    self.textField.frame = CGRectMake(self.frame.size.width/3, (self.frame.size.height - [UIFont systemFontOfSize:17.0f].lineHeight) / 2 , 2*self.frame.size.width/3-20, [UIFont systemFontOfSize:17.0f].lineHeight);
	self.textField.textAlignment = NSTextAlignmentRight;
	if (delegate && [delegate respondsToSelector:@selector(tableViewCell:didEndEditingWithString:)]) {
		[delegate tableViewCell:self didEndEditingWithString:self.stringValue];
	}
	UITableView *tableView = (UITableView *)self.superview.superview;
	[tableView deselectRowAtIndexPath:[tableView indexPathForCell:self] animated:YES];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect editFrame = CGRectInset(self.contentView.frame, 10, 10);
    self.textField.frame = CGRectMake(self.frame.size.width*4/9, (self.frame.size.height - [UIFont systemFontOfSize:17.0f].lineHeight) / 2 , self.frame.size.width - self.frame.size.width*4/9 -10, [UIFont systemFontOfSize:17.0f].lineHeight);
	
	if (self.textLabel.text && [self.textLabel.text length] != 0) {
		CGSize textSize = [self.textLabel sizeThatFits:CGSizeZero];
		editFrame.origin.x += textSize.width + 10;
		editFrame.size.width -= textSize.width + 10;
//		self.textField.textAlignment = NSTextAlignmentCenter;
	} else {
		self.textField.textAlignment = NSTextAlignmentLeft;
	}
//	self.textField.frame = editFrame;
}



- (NSString *)textField:(HTAutocompleteTextField *)htTextField
    completionForPrefix:(NSString *)prefix
             ignoreCase:(BOOL)ignoreCase
{
    NSString *stringToLookFor;
    if (ignoreCase)
    {
        stringToLookFor = [prefix lowercaseString];
    }
    else
    {
        stringToLookFor = prefix;
    }

    for (NSString *stringFromReference in self.invitedHistory)
    {
        
        NSString *stringToCompare;
        if (ignoreCase)
        {
            stringToCompare = [stringFromReference lowercaseString];
        }
        else
        {
            stringToCompare = stringFromReference;
        }
        
        if (stringToLookFor && [stringToCompare hasPrefix:stringToLookFor])
        {
            return [stringFromReference stringByReplacingCharactersInRange:[stringToCompare rangeOfString:stringToLookFor] withString:@""];
        }
        
    }
    
    return @"";
}


@end
