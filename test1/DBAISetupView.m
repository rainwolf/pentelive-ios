//
//  DBAISetupView.m
//  penteLive
//
//  Created by rainwolf on 23/11/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

#import <Foundation/Foundation.h>

//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "DBAISetupView.h"
#import "DatabaseViewController.h"

@implementation DBAISetupView
@synthesize difficulty;
@synthesize useOpeningBook;
@synthesize difficultyCell;
@synthesize openingBookCell;
@synthesize vc;


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"openingBookCell"];
            if (cell == nil) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"openingBookCell"];
            }
            //        NSArray *colors = [[NSArray alloc] initWithObjects:@"white",@"black", nil];
            //        [cell setDelegate: self];
            //        cell.datarray = colors;
            //        [cell.picker reloadAllComponents];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            
            cell.textLabel.text =  NSLocalizedString(@"Opening book:",nil);
            
            useOpeningBook = [[NSUserDefaults standardUserDefaults] boolForKey: @"DBAIOpeningBook"];
            
            UISwitch *openingBookSwitch = [[UISwitch alloc] init];
//            [openingBookSwitch intrinsicContentSize];
            openingBookSwitch.center = CGPointMake(self.frame.size.width - openingBookSwitch.frame.size.width / 2 - 10, 22);
//            openingBookSwitch.center = CGPointMake(20,20);
            [openingBookSwitch setOn:useOpeningBook];
            [openingBookSwitch addTarget:self action:@selector(changeSwitch:) forControlEvents:UIControlEventValueChanged];
            [cell addSubview:openingBookSwitch];
            
            openingBookCell = cell;
            
            return cell;
        } else if (indexPath.row == 1) {
            SimplePickerInputTableViewCell *cell = (SimplePickerInputTableViewCell *) [tableView dequeueReusableCellWithIdentifier: @"difficultyCell"];
            if (cell == nil) {
                cell = [[SimplePickerInputTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier: @"difficultyCell"];
            }
            NSMutableArray<NSString *> *difficulties = [[NSMutableArray alloc] init];
            for ( int i = 1; i < 9; ++i) {
                [difficulties addObject:[NSString stringWithFormat:@"%i",i]];
            }
            cell.datarray = difficulties;
            [cell setDelegate: self];
            [cell.picker reloadAllComponents];
            [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
            
            cell.textLabel.text =  NSLocalizedString(@"Difficulty:",nil);
            int idx = (int) [[NSUserDefaults standardUserDefaults] integerForKey: @"DBAILevel"] - 1;
            if (idx < 0) {
                idx = 0;
            }
            [cell.picker selectRow:idx inComponent:0 animated:NO];
            cell.detailTextLabel.text = [difficulties objectAtIndex:idx];
            
            difficultyCell = cell;
            
            return cell;
        }
    }
    if (indexPath.section == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: @"buttonCell"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: @"buttonCell"];
        }
        [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
        
        cell.textLabel.text =  NSLocalizedString(@"ask the AI",nil);
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.backgroundColor = [UIColor blueColor];
        [cell.textLabel setTextAlignment: NSTextAlignmentCenter];
        cell.layer.cornerRadius = 10;
        cell.layer.masksToBounds = YES;
        
        return cell;
    }
    return nil;
}
-(void) changeSwitch: (UISwitch *) sender {
    if ([sender isOn]) {
        useOpeningBook = YES;
    } else {
        useOpeningBook = NO;
    }
    [[NSUserDefaults standardUserDefaults] setBool:useOpeningBook forKey: @"DBAIOpeningBook"];
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return 15.0;
    }
    return 0;
}


-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        [[NSUserDefaults standardUserDefaults] setInteger: [difficultyCell.detailTextLabel.text integerValue] forKey:@"DBAILevel"];
        [difficultyCell doResign];
        [vc startThinking];
    }
//    if (indexPath.row == 2) {
//        [difficultyCell doResign];
//        if ([colorCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"white",nil)]) {
//            [colorCell.detailTextLabel setText:NSLocalizedString(@"black",nil)];
//        } else {
//            [colorCell.detailTextLabel setText:NSLocalizedString(@"white",nil)];
//        }
//    }
//    if (indexPath.row == 0) {
//        [difficultyCell doResign];
//        if ([gameCell.detailTextLabel.text isEqualToString:@"Pente"]) {
//            [gameCell.detailTextLabel setText:@"Keryo-Pente"];
//            [board setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
//            [zBoard setBackgroundColor:[UIColor colorWithRed:0.702 green:1 blue:0.518 alpha:1]];
//        } else {
//            [gameCell.detailTextLabel setText:@"Pente"];
//            [board setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
//            [zBoard setBackgroundColor:[UIColor colorWithRed:0.984 green:0.851 blue:0.541 alpha:1]];
//        }
//        [board setNeedsDisplay];
//        [zBoard setNeedsDisplay];
//    }
//    
}


@end

