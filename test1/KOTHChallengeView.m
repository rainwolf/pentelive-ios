//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "KOTHChallengeView.h"
#import "PentePlayer.h"

@implementation KOTHChallengeView
@synthesize timeoutCell, restrictionCell;
@synthesize popoverView;
@synthesize invitee;
@synthesize gameId;

NSArray<NSString *> *restrictions;

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
    if (section == 0 && [invitee isEqualToString:@""]) {
        return 2;
    }
    return 1;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView
    numberOfRowsInComponent:(NSInteger)component {
    if (pickerView.tag == 0) {
        return 30;
    } else if (pickerView.tag == 1) {
        return restrictions.count;
    }
    return 0;
}
- (void)pickerView:(UIPickerView *)pickerView
      didSelectRow:(NSInteger)row
       inComponent:(NSInteger)component {
    if (pickerView.tag == 0) {
        timeoutCell.textField.text =
            [NSString stringWithFormat:@"%ld", (row + 1)];
        [[NSUserDefaults standardUserDefaults] setInteger:row
                                                   forKey:@"kothTimeout"];
    } else if (pickerView.tag == 1) {
        restrictionCell.textField.text = [restrictions objectAtIndex:row];
        [[NSUserDefaults standardUserDefaults] setInteger:row
                                                   forKey:@"kothRestriction"];
    }
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component {
    if (pickerView.tag == 0) {
        return [NSString stringWithFormat:@"%ld", (row + 1)];
    } else if (pickerView.tag == 1) {
        return [restrictions objectAtIndex:row];
    }
    return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            InputPickerCell *cell = (InputPickerCell *)[tableView
                dequeueReusableCellWithIdentifier:@"timeoutCell"];
            if (cell == nil) {
                cell = [[InputPickerCell alloc]
                      initWithStyle:UITableViewCellStyleValue1
                    reuseIdentifier:@"timeoutCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"Days per move:", nil);

                UIPickerView *picker = [[UIPickerView alloc] init];
                UIToolbar *toolbar = [[UIToolbar alloc]
                    initWithFrame:CGRectMake(0, 0, self.frame.size.width, 44)];
                toolbar.barStyle = UIBarStyleBlack;
                UIBarButtonItem *extraSpace = [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:
                        UIBarButtonSystemItemFlexibleSpace
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
                              integerForKey:@"kothTimeout"] -
                          1;
                if (idx < 0) {
                    idx = 6;
                }
                cell.textField.text =
                    [NSString stringWithFormat:@"%d", idx + 1];
                [picker selectRow:idx inComponent:0 animated:NO];

                timeoutCell = cell;
            }

            if (![invitee isEqualToString:@""]) {
                cell.contentView.layer.cornerRadius = 5.0f;
                cell.contentView.layer.borderWidth = 1.0f;
            }

            return cell;
        } else if (indexPath.row == 1) {
            if (!restrictions) {
                restrictions = [[NSArray alloc]
                    initWithObjects:NSLocalizedString(@"of any rating", nil),
                                    NSLocalizedString(@"not already playing",
                                                      nil),
                                    NSLocalizedString(@"of lower rating", nil),
                                    NSLocalizedString(@"of higher rating", nil),
                                    NSLocalizedString(@"of similar rating",
                                                      nil),
                                    NSLocalizedString(
                                        @"in the same rating class", nil),
                                    nil];
            }
            InputPickerCell *cell = (InputPickerCell *)[tableView
                dequeueReusableCellWithIdentifier:@"restrictionCell"];
            if (cell == nil) {
                cell = [[InputPickerCell alloc]
                      initWithStyle:UITableViewCellStyleValue1
                    reuseIdentifier:@"restrictionCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.text = NSLocalizedString(@"To players", nil);

                UIPickerView *picker = [[UIPickerView alloc] init];
                UIToolbar *toolbar = [[UIToolbar alloc]
                    initWithFrame:CGRectMake(0, 0, self.frame.size.width, 44)];
                toolbar.barStyle = UIBarStyleBlack;
                UIBarButtonItem *extraSpace = [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:
                        UIBarButtonSystemItemFlexibleSpace
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
                picker.tag = 1;
                cell.textField.inputView = picker;
                cell.textField.inputAccessoryView = toolbar;

                int idx = (int)[[NSUserDefaults standardUserDefaults]
                    integerForKey:@"kothRestriction"];
                if (idx < 0 || idx >= restrictions.count) {
                    idx = 0;
                }
                cell.textField.text = [restrictions objectAtIndex:idx];
                [picker selectRow:idx inComponent:0 animated:NO];

                restrictionCell = cell;
            }

            return cell;
        }
    } else if (indexPath.section == 1) {
        UITableViewCell *cell =
            [tableView dequeueReusableCellWithIdentifier:@"colorCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc]
                  initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:@"colorCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

        cell.textLabel.text = NSLocalizedString(@"send challenge", nil);
        cell.textColor = [UIColor whiteColor];
        cell.backgroundColor = [UIColor blueColor];
        [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
        cell.layer.cornerRadius = 10;
        cell.layer.masksToBounds = YES;

        return cell;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return 15.0;
    }
    return 0;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        [[NSUserDefaults standardUserDefaults]
            setInteger:[timeoutCell.textField.text intValue]
                forKey:@"kothTimeout"];
        [self dismissPicker:nil];

        //        NSString *gameString = self.gameStr;

        NSString *restrictString = @"A";
        if ([invitee isEqualToString:@""]) {
            [[NSUserDefaults standardUserDefaults]
                setInteger:[restrictions
                               indexOfObject:restrictionCell.textField.text]
                    forKey:@"kothRestriction"];
            if ([restrictionCell.textField.text
                    isEqualToString:NSLocalizedString(@"of any rating", nil)]) {
                restrictString = @"A";
            }
            if ([restrictionCell.textField.text
                    isEqualToString:NSLocalizedString(@"not already playing",
                                                      nil)]) {
                restrictString = @"N";
            }
            if ([restrictionCell.textField.text
                    isEqualToString:NSLocalizedString(@"of lower rating",
                                                      nil)]) {
                restrictString = @"L";
            }
            if ([restrictionCell.textField.text
                    isEqualToString:NSLocalizedString(@"of higher rating",
                                                      nil)]) {
                restrictString = @"H";
            }
            if ([restrictionCell.textField.text
                    isEqualToString:NSLocalizedString(@"of similar rating",
                                                      nil)]) {
                restrictString = @"S";
            }
            if ([restrictionCell.textField.text
                    isEqualToString:NSLocalizedString(
                                        @"in the same rating class", nil)]) {
                restrictString = @"C";
            }
        }

        NSString *post = [NSString
            stringWithFormat:@"invitee=%@&game=%i&daysPerMove=%@&"
                             @"invitationRestriction=%@&rated="
                             @"Y&inviterMessage=&mobile=&koth=",
                             self.invitee, gameId, timeoutCell.textField.text,
                             restrictString];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                              allowLossyConversion:YES];
        NSString *postLength = [NSString
            stringWithFormat:@"%lu", (unsigned long)[postData length]];

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request
            setURL:[NSURL URLWithString:
                              @"https://www.pente.org/gameServer/tb/newGame"]];
        if (development) {
            [request
                setURL:[NSURL URLWithString:
                                  @"https://localhost/gameServer/tb/newGame"]];
        }
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded"
            forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        NSURLResponse *response;
        NSError *error;
        [NSURLConnection sendSynchronousRequest:request
                              returningResponse:&response
                                          error:&error];
        //        NSData *responseData = [NSURLConnection
        //        sendSynchronousRequest:request returningResponse:&response
        //        error:&error]; NSString *dashboardString = [[NSString alloc]
        //        initWithData:responseData encoding:NSUTF8StringEncoding];

        //        [spinner performSelectorOnMainThread:@selector(stopAnimating)
        //        withObject:nil waitUntilDone:NO];
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:NSLocalizedString(@"Error", nil)
                          message:[NSString
                                      stringWithFormat:
                                          NSLocalizedString(@"Reason: %@", nil),
                                          error.localizedDescription]
                         delegate:nil
                cancelButtonTitle:@"OK"
                otherButtonTitles:nil];
            //        [alert show];
            [alert performSelectorOnMainThread:@selector(show)
                                    withObject:nil
                                 waitUntilDone:YES];
        } else {
            if ([invitee isEqualToString:@""]) {
                long openInvitationsLimit =
                    [[NSUserDefaults standardUserDefaults]
                        integerForKey:@"openInvitationsLimit"];
                openInvitationsLimit += 2;
                [[NSUserDefaults standardUserDefaults]
                    setInteger:openInvitationsLimit
                        forKey:@"openInvitationsLimit"];
            } else {
                NSUserDefaults *defaults =
                    [NSUserDefaults standardUserDefaults];
                NSString *opponent = self.invitee;
                NSMutableArray *invitedHistory =
                    [[defaults objectForKey:@"invitedHistory"] mutableCopy];
                if (invitedHistory) {
                    int i = 0;
                    for (i = 0; i < [invitedHistory count]; ++i) {
                        if ([[invitedHistory objectAtIndex:i]
                                localizedCaseInsensitiveCompare:opponent] ==
                            NSOrderedDescending)
                            break;
                    }
                    if (![invitedHistory containsObject:opponent]) {
                        [invitedHistory insertObject:opponent atIndex:i];
                    }
                } else {
                    invitedHistory = [NSMutableArray arrayWithObject:opponent];
                }
                [defaults setObject:invitedHistory forKey:@"invitedHistory"];
            }
        }

        [popoverView dismiss];
    }
}

- (void)dismissPicker:(id)sender {
    [timeoutCell.textField resignFirstResponder];
    [restrictionCell.textField resignFirstResponder];
}

@end
