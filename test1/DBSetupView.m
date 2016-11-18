//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "DBSetupView.h"

@implementation DBSetupView
@synthesize gameCell, sortCell, winnerCell;
@synthesize beforeCell, afterCell;
@synthesize board, zBoard;
@synthesize player1Cell, player2Cell;
@synthesize beforePicker, afterPicker;
@synthesize datePickerToolbar;
@synthesize clearButton;

-(instancetype) initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        beforePicker = [[UIDatePicker alloc] init];
        beforePicker.datePickerMode = UIDatePickerModeDate;
        beforePicker.tag = 1;
        [beforePicker addTarget:self action:@selector(datePickerValueChanged:) forControlEvents:UIControlEventValueChanged]; // method to respond to changes in the picker value
        afterPicker = [[UIDatePicker alloc] init];
        afterPicker.datePickerMode = UIDatePickerModeDate;
        afterPicker.tag = 2;
        [afterPicker addTarget:self action:@selector(datePickerValueChanged:) forControlEvents:UIControlEventValueChanged]; // method to respond to changes in the picker value
        
        // Setup UIToolbar for UIDatePicker
        datePickerToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, 44)];
        [datePickerToolbar setBarStyle:UIBarStyleBlackTranslucent];
        UIBarButtonItem *extraSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done",nil) style:UIBarButtonItemStyleDone target:self action:@selector(dismissPicker:)]; // method to dismiss the picker when the "Done" button is pressed
        clearButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Clear",nil) style:UIBarButtonItemStyleDone target:self action:@selector(clearDate:)]; // method to dismiss the picker
        [datePickerToolbar setItems:[[NSArray alloc] initWithObjects: extraSpace, clearButton, doneButton, nil]];
        

    }
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 7;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"gameCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"gameCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Game:",nil);
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBGame"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = @"Pente";
        }
        
        gameCell = cell;
        [self setBoardColor];
        
        return cell;
    }
    if (indexPath.row == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"sortCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"sortCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Sort by",nil);
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBSort"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = NSLocalizedString(@"win percentage",nil);
        }
        
        sortCell = cell;
        
        return cell;
    }
    if (indexPath.row == 2) {
        StringInputTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"player1Cell"];
        if (cell == nil) {
            cell = [[StringInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"player1Cell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Player 1:",nil);
        
        player1Cell = cell;
        
        return cell;
    }
    if (indexPath.row == 3) {
        StringInputTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"player2Cell"];
        if (cell == nil) {
            cell = [[StringInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"player2Cell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Player 2:",nil);
        
        player2Cell = cell;
        
        return cell;
    }
    if (indexPath.row == 4) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"winnerCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"winnerCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Winner",nil);
        cell.detailTextLabel.text = NSLocalizedString(@"either",nil);
        
        winnerCell = cell;
        
        return cell;
    }
    if (indexPath.row == 5) {
        DateTableViewCell *cell = (DateTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"afterCell"];
        if (cell == nil) {
            cell = [[DateTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"afterCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"After:",nil);
        //        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBSort"];
        //        if (str) {
        //            cell.detailTextLabel.text = str;
        //        } else {
        //            cell.detailTextLabel.text = @"win percentage";
        //        }
//        cell.detailTextLabel.text = @"";
        cell.textField.inputView = afterPicker;
        cell.textField.tag = 1;
        cell.textField.delegate = self;
        cell.textField.inputAccessoryView = datePickerToolbar;

        afterCell = cell;
        
        return cell;
    }
    if (indexPath.row == 6) {
        DateTableViewCell *cell = (DateTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"beforeCell"];
        if (cell == nil) {
            cell = [[DateTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"beforeCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Before:",nil);
        cell.textField.tag = 2;
        cell.textField.delegate = self;
        cell.textField.inputView = beforePicker;
        cell.textField.inputAccessoryView = datePickerToolbar;
        
        beforeCell = cell;
        
        return cell;
    }
    return nil;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        [beforeCell.textField resignFirstResponder];
        [afterCell.textField resignFirstResponder];
        [player1Cell resignFirstResponder];
        [player2Cell resignFirstResponder];
        [self changeBoardColor];
        [[NSUserDefaults standardUserDefaults] setObject:gameCell.detailTextLabel.text forKey:@"DBGame"];
    }
    if (indexPath.row == 1) {
        [beforeCell.textField resignFirstResponder];
        [afterCell.textField resignFirstResponder];
        [player1Cell resignFirstResponder];
        [player2Cell resignFirstResponder];
        if ([sortCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"popularity",nil)]) {
            [sortCell.detailTextLabel setText:NSLocalizedString(@"win percentage",nil)];
        } else {
            [sortCell.detailTextLabel setText:NSLocalizedString(@"popularity",nil)];
        }
        [[NSUserDefaults standardUserDefaults] setObject:sortCell.detailTextLabel.text forKey:@"DBSort"];
    }
    if (indexPath.row == 4) {
        [beforeCell.textField resignFirstResponder];
        [afterCell.textField resignFirstResponder];
        [player1Cell resignFirstResponder];
        [player2Cell resignFirstResponder];
        if ([winnerCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"either",nil)]) {
            [winnerCell.detailTextLabel setText:NSLocalizedString(@"player 1",nil)];
        } else if ([winnerCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"player 1",nil)]) {
            [winnerCell.detailTextLabel setText:NSLocalizedString(@"player 2",nil)];
        } else {
            [winnerCell.detailTextLabel setText:NSLocalizedString(@"either",nil)];
        }
    }
    if (indexPath.row == 5 || indexPath.row == 6) {
//        [player1Cell resignFirstResponder];
//        [player2Cell resignFirstResponder];
//        if (indexPath.row == 5) {
//            clearButton.tag = 1;
//            [beforeCell.textField resignFirstResponder];
//        } else {
//            clearButton.tag = 2;
//            [afterCell.textField resignFirstResponder];
//        }
//        NSLog(@"kitty %ld", (long)clearButton.tag);

    }

}

- (void)datePickerValueChanged: (UIDatePicker *) sender {
    NSDate *selectedDate = sender.date;
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"MM/dd/YYYY"];
    UITextField *textField;
    if (sender.tag == 1) {
        textField = beforeCell.textField;
    } else if (sender.tag == 2) {
        textField = afterCell.textField;
    }
    [textField setText:[df stringFromDate:selectedDate]];
}
-(void) dismissPicker: (id) sender {
    [beforeCell.textField resignFirstResponder];
    [afterCell.textField resignFirstResponder];
}
-(void) clearDate: (UIBarButtonItem *) sender {
//    NSLog(@"kitty %ld", (long)sender.tag);
    if (sender.tag == 1) {
        [afterCell.textField setText:@""];
        [afterCell.textField resignFirstResponder];
    } else if (sender.tag == 2) {
        [beforeCell.textField setText:@""];
        [beforeCell.textField resignFirstResponder];
    }
    
}

-(void)textFieldDidBeginEditing:(UITextField *)textField {
    clearButton.tag = textField.tag;
}

-(void) changeBoardColor {
    [board setDbOptions:nil];
    [zBoard setDbOptions:nil];
    if ([gameCell.detailTextLabel.text isEqualToString:@"Pente"]) {
        [gameCell.detailTextLabel setText:@"Keryo-Pente"];
//        [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha: 0.5]];
//        [zBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha: 0.5]];
        [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Keryo-Pente"]) {
        [gameCell.detailTextLabel setText:@"Gomoku"];
        [board setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Gomoku"]) {
        [gameCell.detailTextLabel setText:@"D-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"D-Pente"]) {
        [gameCell.detailTextLabel setText:@"G-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"G-Pente"]) {
        [gameCell.detailTextLabel setText:@"Poof-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Poof-Pente"]) {
        [gameCell.detailTextLabel setText:@"Boat-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Boat-Pente"]) {
        [gameCell.detailTextLabel setText:@"Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
    }
    [board setNeedsDisplay];
    [zBoard setNeedsDisplay];
}

-(void) setBoardColor {
    if ([gameCell.detailTextLabel.text isEqualToString:@"Keryo-Pente"]) {
        [gameCell.detailTextLabel setText:@"Keryo-Pente"];
//        [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha: 0.5]];
//        [zBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha: 0.5]];
        [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Gomoku"]) {
        [gameCell.detailTextLabel setText:@"Gomoku"];
        [board setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"D-Pente"]) {
        [gameCell.detailTextLabel setText:@"D-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"G-Pente"]) {
        [gameCell.detailTextLabel setText:@"G-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Poof-Pente"]) {
        [gameCell.detailTextLabel setText:@"Poof-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Boat-Pente"]) {
        [gameCell.detailTextLabel setText:@"Boat-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Pente"]) {
        [gameCell.detailTextLabel setText:@"Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
    }
    [board setNeedsDisplay];
    [zBoard setNeedsDisplay];
}


@end





@implementation DateTableViewCell
@synthesize textField;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        textField = [[UITextField alloc] init];
        [textField setTextAlignment:NSTextAlignmentRight];
//        [self.ratingLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.f]];
        [self.contentView addSubview: textField];
    }
    return self;
}


- (void) layoutSubviews {
    [super layoutSubviews];
    CGFloat tfX = self.textLabel.frame.origin.x + self.textLabel.frame.size.width + 15,
        tfW = self.contentView.frame.size.width - tfX - 15;
    
    [self.textField setFrame:CGRectMake(tfX, 4, tfW, 36)];
}


@end














