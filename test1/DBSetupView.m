//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "DBSetupView.h"

@interface DBSetupView(){
    NSMutableArray<NSString*> *ratingChoices, *gameChoices;
}
@property(nonatomic,strong) NSMutableArray<NSString*> *ratingChoices;
@end

@implementation DBSetupView
@synthesize sortCell, winnerCell, eitherOrBothp1p2Cell, excludeTimeoutCell;
@synthesize beforeCell, afterCell;
@synthesize board, zBoard;
@synthesize player1Cell, player2Cell;
@synthesize beforePicker, afterPicker;
@synthesize datePickerToolbar;
@synthesize clearButton;
@synthesize p1RatingCell, p2RatingCell, gameCell;
@synthesize ratingChoices;

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
        
        ratingChoices = [[NSMutableArray alloc] init];
        [ratingChoices addObject:@"0"];
        for (int i = 1600; i<2800; i += 100) {
            [ratingChoices addObject:[NSString stringWithFormat:@"%d",i]];
        }
        gameChoices = [[NSMutableArray alloc] initWithObjects:@"Pente", @"Keryo-Pente", @"Gomoku", @"D-Pente", @"G-Pente", @"Poof-Pente", @"Connect6", @"Boat-Pente", @"DK-Pente",
                       @"Speed Pente", @"Speed Keryo-Pente", @"Speed Gomoku", @"Speed D-Pente", @"Speed G-Pente", @"Speed Poof-Pente", @"Speed Connect6", @"Speed Boat-Pente", @"Speed DK-Pente", nil];
    }
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 11;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

-(void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    gameCell.detailTextLabel.text = [gameChoices objectAtIndex:row];
    [self setBoardColor];
    [[NSUserDefaults standardUserDefaults] setObject:gameCell.detailTextLabel.text forKey:@"DBGame"];
}

-(NSString*) pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [gameChoices objectAtIndex:row];
    return @"";
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int i = -1;
    if (indexPath.row == ++i) {
        SimplePickerInputTableViewCell *cell = (SimplePickerInputTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"gameCell"];
        if (cell == nil) {
            cell = [[SimplePickerInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"gameCell"];
            cell.datarray = gameChoices;
            NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBGame"];
            if (str) {
                cell.detailTextLabel.text = str;
                unsigned long idx = [gameChoices indexOfObject:str];
                [cell.picker selectRow:idx inComponent:0 animated:NO];
                [cell.picker setDelegate:self];
            } else {
                cell.detailTextLabel.text = @"Pente";
            }
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Game:",nil);
        
        gameCell = cell;
        [self setBoardColor];
        
        return cell;
    }
    if (indexPath.row == ++i) {
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
    if (indexPath.row == ++i) {
        StringInputTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"player1Cell"];
        if (cell == nil) {
            cell = [[StringInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"player1Cell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Player 1:",nil);
        
        player1Cell = cell;
        
        return cell;
    }
    if (indexPath.row == ++i) {
        StringInputTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"player2Cell"];
        if (cell == nil) {
            cell = [[StringInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"player2Cell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Player 2:",nil);
        
        player2Cell = cell;
        
        return cell;
    }
    if (indexPath.row == ++i) {
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
    if (indexPath.row == ++i) {
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
    if (indexPath.row == ++i) {
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
    if (indexPath.row == ++i) {
        SimplePickerInputTableViewCell *cell = (SimplePickerInputTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"p1RatingCell"];
        if (cell == nil) {
            cell = [[SimplePickerInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"p1RatingCell"];
            cell.datarray = ratingChoices;
        }
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBP1Rating"];
        if (str) {
            cell.detailTextLabel.text = str;
            unsigned long idx = [ratingChoices indexOfObject:str];
            [cell.picker selectRow:idx inComponent:0 animated:NO];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"P1 rating above:",nil);
        
        p1RatingCell = cell;
        
        return cell;
    }
    if (indexPath.row == ++i) {
        SimplePickerInputTableViewCell *cell = (SimplePickerInputTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"p2RatingCell"];
        if (cell == nil) {
            cell = [[SimplePickerInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"p2RatingCell"];
            cell.datarray = ratingChoices;
        }
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBP2Rating"];
        if (str) {
            cell.detailTextLabel.text = str;
            unsigned long idx = [ratingChoices indexOfObject:str];
            [cell.picker selectRow:idx inComponent:0 animated:NO];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"P2 rating above:",nil);
        
        p2RatingCell = cell;
        
        return cell;
    }
    if (indexPath.row == ++i) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"bothOrEitherCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"bothOrEitherCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Match players",nil);
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBBothOrEither"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = NSLocalizedString(@"both",nil);
        }
        
        eitherOrBothp1p2Cell = cell;
        
        return cell;
    }
    if (indexPath.row == ++i) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"excludeTimeoutCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"excludeTimeoutCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"Exclude timeouts",nil);
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBExcludeTimeouts"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = NSLocalizedString(@"no",nil);
        }
        
        excludeTimeoutCell = cell;
        
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
    }
    if (indexPath.row == 1) {
        if ([sortCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"popularity",nil)]) {
            [sortCell.detailTextLabel setText:NSLocalizedString(@"win percentage",nil)];
        } else {
            [sortCell.detailTextLabel setText:NSLocalizedString(@"popularity",nil)];
        }
        [[NSUserDefaults standardUserDefaults] setObject:sortCell.detailTextLabel.text forKey:@"DBSort"];
    }
    if (indexPath.row == 4) {
        if ([winnerCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"either",nil)]) {
            [winnerCell.detailTextLabel setText:NSLocalizedString(@"player 1",nil)];
        } else if ([winnerCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"player 1",nil)]) {
            [winnerCell.detailTextLabel setText:NSLocalizedString(@"player 2",nil)];
        } else {
            [winnerCell.detailTextLabel setText:NSLocalizedString(@"either",nil)];
        }
    }
    if (indexPath.row == 9) {
        if ([eitherOrBothp1p2Cell.detailTextLabel.text isEqualToString:NSLocalizedString(@"either",nil)]) {
            [eitherOrBothp1p2Cell.detailTextLabel setText:NSLocalizedString(@"both",nil)];
        } else {
            [eitherOrBothp1p2Cell.detailTextLabel setText:NSLocalizedString(@"either",nil)];
        }
        [[NSUserDefaults standardUserDefaults] setObject:eitherOrBothp1p2Cell.detailTextLabel.text forKey:@"DBBothOrEither"];
    }
    if (indexPath.row == 10) {
        if ([excludeTimeoutCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"yes",nil)]) {
            [excludeTimeoutCell.detailTextLabel setText:NSLocalizedString(@"no",nil)];
        } else {
            [excludeTimeoutCell.detailTextLabel setText:NSLocalizedString(@"yes",nil)];
        }
        [[NSUserDefaults standardUserDefaults] setObject:excludeTimeoutCell.detailTextLabel.text forKey:@"DBExcludeTimeouts"];
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
    [tableView deselectRowAtIndexPath:indexPath animated:NO];

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
    [p1RatingCell.picker resignFirstResponder];
    [p2RatingCell.picker resignFirstResponder];
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

//-(void) changeBoardColor {
//    [board setDbOptions:nil];
//    [zBoard setDbOptions:nil];
//    if ([gameCell.detailTextLabel.text isEqualToString:@"Pente"]) {
//        [gameCell.detailTextLabel setText:@"Keryo-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Keryo-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Gomoku"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Gomoku"]) {
//        [gameCell.detailTextLabel setText:@"D-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"D-Pente"]) {
//        [gameCell.detailTextLabel setText:@"G-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"G-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Poof-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Poof-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Connect6"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Connect6"]) {
//        [gameCell.detailTextLabel setText:@"Boat-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Boat-Pente"]) {
//        [gameCell.detailTextLabel setText:@"DK-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"DK-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Speed Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed Pente"]) {
//        [gameCell.detailTextLabel setText:@"Speed Keryo-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed Keryo-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Speed Gomoku"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed Gomoku"]) {
//        [gameCell.detailTextLabel setText:@"Speed D-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed D-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Speed G-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed G-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Speed Poof-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed Poof-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Speed Connect6"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed Connect6"]) {
//        [gameCell.detailTextLabel setText:@"Speed Boat-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed Boat-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Speed DK-Pente"];
//    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Speed DK-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Pente"];
//    }
//    [self setBoardColor];
//}

-(void) setBoardColor {
    [board setDbOptions:nil];
    [zBoard setDbOptions:nil];
    if ([gameCell.detailTextLabel.text isEqualToString:@"Keryo-Pente"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed Keryo-Pente"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Gomoku"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed Gomoku"]) {
//        [gameCell.detailTextLabel setText:@"Gomoku"];
        [board setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.612 green:1 blue:0.898 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"D-Pente"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed D-Pente"]) {
//        [gameCell.detailTextLabel setText:@"D-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.584 green:0.753 blue:0.98 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"G-Pente"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed G-Pente"]) {
//        [gameCell.detailTextLabel setText:@"G-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.616 green:0.545 blue:0.965 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Poof-Pente"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed Poof-Pente"]) {
        //        [gameCell.detailTextLabel setText:@"Poof-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Connect6"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed Connect6"]) {
        [board setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.929 green:0.639 blue:0.992 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Boat-Pente"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed Boat-Pente"]) {
//        [gameCell.detailTextLabel setText:@"Boat-Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.145 green:0.729 blue:1 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"Pente"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed Pente"]) {
        //        [gameCell.detailTextLabel setText:@"Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
    } else if ([gameCell.detailTextLabel.text isEqualToString:@"DK-Pente"] || [gameCell.detailTextLabel.text isEqualToString:@"Speed DK-Pente"]) {
        //        [gameCell.detailTextLabel setText:@"Pente"];
        [board setBackgroundColor:[UIColor colorWithRed:1 green:165.0/255.0 blue:0 alpha:1]];
        [zBoard setBackgroundColor:[UIColor colorWithRed:1 green:165.0/255.0 blue:0 alpha:1]];
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














