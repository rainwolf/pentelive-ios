//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "AISetupView.h"

@implementation AISetupView
@synthesize difficulty;
@synthesize playAsWhite;
@synthesize difficultyCell;
@synthesize colorCell;



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row == 0) {
        SimplePickerInputTableViewCell *cell = (SimplePickerInputTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"difficultyCell"];
        if (cell == nil) {
            cell = [[SimplePickerInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"difficultyCell"];
        }
        NSMutableArray<NSString *> *difficulties = [[NSMutableArray alloc] init];
        for ( int i = 1; i < 13; ++i) {
            [difficulties addObject:[NSString stringWithFormat:@"%i",i]];
        }
        cell.datarray = difficulties;
        [cell setDelegate: self];
        [cell.picker reloadAllComponents];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
       
        cell.textLabel.text =  @"Difficulty:";
        int idx = (int) [[NSUserDefaults standardUserDefaults] integerForKey: @"MMAILevel"] - 1;
        if (idx < 0) {
            idx = 0;
        }
        [cell.picker selectRow:idx inComponent:0 animated:NO];
        cell.detailTextLabel.text = [difficulties objectAtIndex:idx];
        
        difficultyCell = cell;
        
        return cell;
    } else if (indexPath.row == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"colorCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"colorCell"];
        }
//        NSArray *colors = [[NSArray alloc] initWithObjects:@"white",@"black", nil];
//        [cell setDelegate: self];
//        cell.datarray = colors;
//        [cell.picker reloadAllComponents];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  @"Play as:";
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"MMAIColor"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = @"white";
        }
        
        colorCell = cell;
        
        return cell;
    }
    return nil;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 1) {
        if ([colorCell.detailTextLabel.text isEqualToString:@"white"]) {
            [colorCell.detailTextLabel setText:@"black"];
        } else {
            [colorCell.detailTextLabel setText:@"white"];
        }
    }
}



@end

