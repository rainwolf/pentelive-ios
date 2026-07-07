//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "AISetupView.h"
#import "penteLive-Swift.h"

@implementation AISetupView
@synthesize difficulty;
@synthesize playAsWhite;
@synthesize difficultyCell;
@synthesize colorCell, gameCell;
@synthesize board, zBoard;

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView
    numberOfRowsInComponent:(NSInteger)component {
    return 8;
}
- (void)pickerView:(UIPickerView *)pickerView
      didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component {
    difficultyCell.textField.text =
        [NSString stringWithFormat:@"%ld", (row + 1)];
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component {
    return [NSString stringWithFormat:@"%ld", (row + 1)];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row == 0) {
        UITableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"gameCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc]
                  initWithStyle:UITableViewCellStyleValue1
                reuseIdentifier:@"gameCell"];
        }
        //        NSArray *colors = [[NSArray alloc]
        //        initWithObjects:@"white",@"black", nil]; [cell setDelegate:
        //        self]; cell.datarray = colors; [cell.picker
        //        reloadAllComponents];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

        cell.textLabel.text = NSLocalizedString(@"Game:", nil);
        NSString *str =
            [[NSUserDefaults standardUserDefaults] objectForKey:@"MMAIGame"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = @"Pente";
        }

        gameCell = cell;

        return cell;
    } else if (indexPath.row == 1) {
        InputPickerCell *cell = (InputPickerCell *)[tableView
            dequeueReusableCellWithIdentifier:@"difficultyCell"];
        if (cell == nil) {
            cell = [[InputPickerCell alloc]
                  initWithStyle:UITableViewCellStyleValue1
                reuseIdentifier:@"difficultyCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.text = NSLocalizedString(@"Difficulty:", nil);

            UIPickerView *picker = [[UIPickerView alloc] init];
            UIToolbar *toolbar = [[UIToolbar alloc]
                initWithFrame:CGRectMake(0, 0, self.frame.size.width, 44)];
            toolbar.barStyle = UIBarStyleBlack;
            UIBarButtonItem *extraSpace = [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                     target:nil
                                     action:nil];
            UIBarButtonItem *doneButton = [[UIBarButtonItem alloc]
                initWithTitle:NSLocalizedString(@"Done", nil)
                        style:UIBarButtonItemStyleDone
                       target:self
                       action:@selector(dismissPicker:)];
            [toolbar setItems:@[ extraSpace, doneButton ] animated:YES];
            picker.delegate = self;
            picker.dataSource = self;
            picker.tag = 0;
            cell.textField.inputView = picker;
            cell.textField.inputAccessoryView = toolbar;
            int idx = (int)[[NSUserDefaults standardUserDefaults]
                          integerForKey:@"MMAILevel"] -
                      1;
            if (idx < 0) {
                idx = 0;
            }
            [picker selectRow:idx inComponent:0 animated:NO];
            cell.textField.text = [NSString stringWithFormat:@"%ld", (idx + 1)];

            difficultyCell = cell;
        }

        return cell;
    } else if (indexPath.row == 2) {
        UITableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"colorCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc]
                  initWithStyle:UITableViewCellStyleValue1
                reuseIdentifier:@"colorCell"];
        }
        //        NSArray *colors = [[NSArray alloc]
        //        initWithObjects:@"white",@"black", nil]; [cell setDelegate:
        //        self]; cell.datarray = colors; [cell.picker
        //        reloadAllComponents];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

        cell.textLabel.text = NSLocalizedString(@"Play as:", nil);
        NSString *str =
            [[NSUserDefaults standardUserDefaults] objectForKey:@"MMAIColor"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = NSLocalizedString(@"white", nil);
        }

        colorCell = cell;

        return cell;
    }
    return nil;
}

- (void)dismissPicker:(id)sender {
    [difficultyCell.textField resignFirstResponder];
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 2) {
        [difficultyCell.textField resignFirstResponder];
        if ([colorCell.detailTextLabel.text
                isEqualToString:NSLocalizedString(@"white", nil)]) {
            [colorCell.detailTextLabel
                setText:NSLocalizedString(@"black", nil)];
        } else {
            [colorCell.detailTextLabel
                setText:NSLocalizedString(@"white", nil)];
        }
    }
    if (indexPath.row == 0) {
        [difficultyCell.textField resignFirstResponder];
        // Cycle the exposed, faithfully-refereed variants:
        // Pente -> Keryo-Pente -> Poof-Pente -> Connect6 -> (wrap to Pente).
        NSString *cur = gameCell.detailTextLabel.text;
        NSString *next;
        if ([cur isEqualToString:@"Pente"]) {
            next = @"Keryo-Pente";
        } else if ([cur isEqualToString:@"Keryo-Pente"]) {
            next = @"Poof-Pente";
        } else if ([cur isEqualToString:@"Poof-Pente"]) {
            next = @"Connect6";
        } else {
            next = @"Pente";
        }
        [gameCell.detailTextLabel setText:next];

        UIColor *bg;
        // Board colour comes from the single source of truth
        // (BoardVariantMapping) so the chooser matches the rest of the app.
        PenteVariant nextVariant = PenteVariantPente;
        if ([next isEqualToString:@"Keryo-Pente"]) {
            nextVariant = PenteVariantKeryoPente;
        } else if ([next isEqualToString:@"Poof-Pente"]) {
            nextVariant = PenteVariantPoofPente;
        } else if ([next isEqualToString:@"Connect6"]) {
            nextVariant = PenteVariantConnect6;
        }
        bg = [BoardVariantMapping backgroundColorForVariant:nextVariant
                                                  boatPente:NO];
        [board setBackgroundColor:bg];
        [zBoard setBackgroundColor:bg];
        [board setNeedsDisplay];
        [zBoard setNeedsDisplay];
    }
}

@end
