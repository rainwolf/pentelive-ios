//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "DBSetupView.h"

@implementation DBSetupView
@synthesize gameCell, sortCell;
@synthesize board, zBoard;



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"gameCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"gameCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  @"Game:";
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
        
        cell.textLabel.text =  @"Sort by";
        NSString *str = [[NSUserDefaults standardUserDefaults] objectForKey: @"DBSort"];
        if (str) {
            cell.detailTextLabel.text = str;
        } else {
            cell.detailTextLabel.text = @"win percentage";
        }
        
        sortCell = cell;
        
        return cell;
    }
    return nil;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        [self changeBoardColor];
        [[NSUserDefaults standardUserDefaults] setObject:gameCell.detailTextLabel.text forKey:@"DBGame"];
    }
    if (indexPath.row == 1) {
        if ([sortCell.detailTextLabel.text isEqualToString:@"popularity"]) {
            [sortCell.detailTextLabel setText:@"win percentage"];
        } else {
            [sortCell.detailTextLabel setText:@"popularity"];
        }
        [[NSUserDefaults standardUserDefaults] setObject:sortCell.detailTextLabel.text forKey:@"DBSort"];
    }

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

