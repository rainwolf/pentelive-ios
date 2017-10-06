//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "KOTHChallengeView.h"

@implementation KOTHChallengeView
@synthesize timeoutCell, restrictionCell;
@synthesize popoverView;
@synthesize invitee;
@synthesize gameId;



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0 && [invitee isEqualToString:@""]) {
        return 2;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            SimplePickerInputTableViewCell *cell = (SimplePickerInputTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"timeoutCell"];
            if (cell == nil) {
                cell = [[SimplePickerInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"timeoutCell"];
            }
            NSMutableArray<NSString *> *timouts = [[NSMutableArray alloc] init];
            for ( int i = 1; i < 30; ++i) {
                [timouts addObject:[NSString stringWithFormat:@"%i",i]];
            }
            cell.datarray = timouts;
            [cell setDelegate: self];
            [cell.picker reloadAllComponents];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            
            cell.textLabel.text =  NSLocalizedString(@"Days per move:",nil);
            int idx = (int) [[NSUserDefaults standardUserDefaults] integerForKey: @"kothTimeout"] - 1;
            if (idx < 0) {
                idx = 6;
            }
            [cell.picker selectRow:idx inComponent:0 animated:NO];
            cell.detailTextLabel.text = [timouts objectAtIndex:idx];
            
            if (![invitee isEqualToString:@""]) {
                cell.contentView.layer.cornerRadius = 5.0f;
                cell.contentView.layer.borderWidth = 1.0f;
            }

            timeoutCell = cell;
            
            return cell;
        } else if (indexPath.row == 1) {
            SimplePickerInputTableViewCell *cell = (SimplePickerInputTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"restrictionCell"];
            if (cell == nil) {
                cell = [[SimplePickerInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"restrictionCell"];
            }
            NSArray<NSString *> *restrictions = [[NSArray alloc] initWithObjects:NSLocalizedString(@"of any rating",nil),NSLocalizedString(@"not already playing",nil),NSLocalizedString(@"of lower rating",nil),NSLocalizedString(@"of higher rating",nil),NSLocalizedString(@"of similar rating",nil),NSLocalizedString(@"in the same rating class",nil), nil];

            cell.datarray = restrictions;
            [cell setDelegate: self];
            [cell.picker reloadAllComponents];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            
            cell.textLabel.text =  NSLocalizedString(@"To players",nil);
            int idx = (int) [[NSUserDefaults standardUserDefaults] integerForKey: @"kothRestriction"] - 1;
            if (idx < 0) {
                idx = 0;
            }
            [cell.picker selectRow:idx inComponent:0 animated:NO];
            cell.detailTextLabel.text = [restrictions objectAtIndex:idx];
            
//            cell.contentView.layer.cornerRadius = 5.0f;
//            cell.contentView.layer.borderWidth = 1.0f;

            restrictionCell = cell;
            
            return cell;
        }
    } else if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"colorCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: @"colorCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"send challenge",nil);
        cell.textColor = [UIColor whiteColor];
        cell.backgroundColor = [UIColor blueColor];
        [cell.textLabel setTextAlignment: NSTextAlignmentCenter];
        cell.layer.cornerRadius = 10;
        cell.layer.masksToBounds = YES;
        
        return cell;
    }
    return nil;
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return 15.0;
    }
    return 0;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        [[NSUserDefaults standardUserDefaults] setInteger: [timeoutCell.detailTextLabel.text intValue] forKey:@"kothTimeout"];
        [timeoutCell doResign];
        [restrictionCell doResign];
        

//        NSString *gameString = self.gameStr;

        NSString *restrictString = @"A";
        if ([invitee isEqualToString:@""]) {
            [[NSUserDefaults standardUserDefaults] setInteger: [restrictionCell.detailTextLabel.text intValue] forKey:@"kothRestriction"];
            [restrictionCell doResign];
            if ([restrictionCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"of any rating",nil)]) {
                restrictString = @"A";
            }
            if ([restrictionCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"not already playing",nil)]) {
                restrictString = @"N";
            }
            if ([restrictionCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"of lower rating",nil)]) {
                restrictString = @"L";
            }
            if ([restrictionCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"of higher rating",nil)]) {
                restrictString = @"H";
            }
            if ([restrictionCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"of similar rating",nil)]) {
                restrictString = @"S";
            }
            if ([restrictionCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"in the same rating class",nil)]) {
                restrictString = @"C";
            }
        }


        NSString *post = [NSString stringWithFormat:@"invitee=%@&game=%i&daysPerMove=%@&invitationRestriction=%@&rated=Y&inviterMessage=&mobile=&koth=", self.invitee ,gameId, timeoutCell.detailTextLabel.text, restrictString];
        NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
        NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setURL:[NSURL URLWithString:@"https://www.pente.org/gameServer/tb/newGame"]];
//        [request setURL:[NSURL URLWithString:@"https://development.pente.org/gameServer/tb/newGame"]];
        [request setHTTPMethod:@"POST"];
        [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:postData];
        [request setTimeoutInterval:7.0];
        NSURLResponse *response;
        NSError *error;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
//        [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            //        [alert show];
            [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
        } else {
            if ([invitee isEqualToString:@""]) {
                long openInvitationsLimit = [[NSUserDefaults standardUserDefaults] integerForKey:@"openInvitationsLimit"];
                openInvitationsLimit += 2;
                [[NSUserDefaults standardUserDefaults] setInteger: openInvitationsLimit forKey:@"openInvitationsLimit"];
            } else {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                NSString *opponent = self.invitee;
                NSMutableArray *invitedHistory =  [[defaults objectForKey:@"invitedHistory"] mutableCopy];
                if (invitedHistory) {
                    int i = 0;
                    for ( i = 0; i < [invitedHistory count]; ++i) {
                        if ([[invitedHistory objectAtIndex:i] localizedCaseInsensitiveCompare: opponent] == NSOrderedDescending)
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


@end

