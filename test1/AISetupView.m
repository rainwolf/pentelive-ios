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
@synthesize colorCell, gameCell;
@synthesize board, zBoard;



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"gameCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"gameCell"];
        }
        //        NSArray *colors = [[NSArray alloc] initWithObjects:@"white",@"black", nil];
        //        [cell setDelegate: self];
        //        cell.datarray = colors;
        //        [cell.picker reloadAllComponents];
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  @"Game:";
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"MMAIGame"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = @"Pente";
        }
        
        gameCell = cell;
        
        return cell;
    } else if (indexPath.row == 1) {
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
    } else if (indexPath.row == 2) {
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
    if (indexPath.row == 2) {
        [difficultyCell doResign];
        if ([colorCell.detailTextLabel.text isEqualToString:@"white"]) {
            [colorCell.detailTextLabel setText:@"black"];
        } else {
            [colorCell.detailTextLabel setText:@"white"];
        }
    }
    if (indexPath.row == 0) {
        [difficultyCell doResign];
        if ([gameCell.detailTextLabel.text isEqualToString:@"Pente"]) {
            [gameCell.detailTextLabel setText:@"Keryo-Pente"];
            [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
            [zBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
        } else {
            [gameCell.detailTextLabel setText:@"Pente"];
            [board setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
            [zBoard setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
        }
        [board setNeedsDisplay];
        [zBoard setNeedsDisplay];
    }

}


@end

