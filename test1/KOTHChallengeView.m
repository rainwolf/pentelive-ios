//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "KOTHChallengeView.h"

@implementation KOTHChallengeView
@synthesize timoutCell;
@synthesize popoverView;
@synthesize gameStr, invitee;



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.section == 0) {
        SimplePickerInputTableViewCell *cell = (SimplePickerInputTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"timoutCell"];
        if (cell == nil) {
            cell = [[SimplePickerInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"timoutCell"];
        }
        NSMutableArray<NSString *> *timouts = [[NSMutableArray alloc] init];
        for ( int i = 1; i < 30; ++i) {
            [timouts addObject:[NSString stringWithFormat:@"%i",i]];
        }
        cell.datarray = timouts;
        [cell setDelegate: self];
        [cell.picker reloadAllComponents];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
       
        cell.textLabel.text =  @"Days per move:";
        int idx = (int) [[NSUserDefaults standardUserDefaults] integerForKey: @"kothTimeout"] - 1;
        if (idx < 0) {
            idx = 2;
        }
        [cell.picker selectRow:idx inComponent:0 animated:NO];
        cell.detailTextLabel.text = [timouts objectAtIndex:idx];
        
        timoutCell = cell;
        
        return cell;
    } else if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"colorCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: @"colorCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  @"send challenge";
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
        [[NSUserDefaults standardUserDefaults] setInteger: [timoutCell.detailTextLabel.text intValue] forKey:@"kothTimeout"];
        [timoutCell doResign];

        NSString *gameString = self.gameStr;
        

        NSString *post = [NSString stringWithFormat:@"invitee=%@&game=%@&daysPerMove=%@&rated=Y&inviterMessage=&mobile=&koth=", self.invitee ,gameString, timoutCell.detailTextLabel.text];
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
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
//        [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
        
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

        
        [popoverView dismiss];
    }
}


@end

