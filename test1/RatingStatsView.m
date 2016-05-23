//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "RatingStatsView.h"

@implementation RatingStatsView
@synthesize ratingStats;


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [ratingStats count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString * cellIdentifier = @"Cell";
    
    RatingStatCell *cell = (RatingStatCell *) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[RatingStatCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    cell.textLabel.text =  [ratingStats objectAtIndex: indexPath.row].game;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Last: %@, total: %@", [ratingStats objectAtIndex: indexPath.row].lastPlayed, [ratingStats objectAtIndex: indexPath.row].totalGames];
    NSMutableString *ratingStr = [NSMutableString stringWithString:@"\u25A0 "];
    if ([[ratingStats objectAtIndex: indexPath.row].rating length] == 3) {
        [ratingStr appendString:@"  "];
    }
    [ratingStr appendString: [ratingStats objectAtIndex: indexPath.row].rating];
    NSMutableAttributedString *tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
    [self addColorOfRating: [ratingStats objectAtIndex: indexPath.row].rating toString: tmpStr];
    cell.ratingLabel.attributedText = tmpStr;
    
    return cell;
}


-(void) addColorOfRating: (NSString *) rating toString: (NSMutableAttributedString *) str {
    int ratingInt = [rating intValue];
    UIColor *ratingColor = [UIColor blackColor];
    if (ratingInt >= 1900) {
        ratingColor = [UIColor redColor];
    } else if (ratingInt >= 1700) {
        ratingColor = [UIColor colorWithRed:0.98 green:0.96 blue:0.03 alpha:1.0];
    } else if (ratingInt >= 1400) {
        ratingColor = [UIColor blueColor];
    } else if (ratingInt >= 1000) {
        ratingColor = [UIColor colorWithRed:30.0/255 green: 130.0/255 blue:76.0/255 alpha:1.0];
    } else {
        ratingColor = [UIColor grayColor];
    }
    NSString *strString = [str string];
    [str addAttribute:NSForegroundColorAttributeName value: ratingColor range: [strString rangeOfString: @"\u25A0"]];
    [str addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Bold" size:12.f] range: [strString rangeOfString: @"\u25A0"]];
}

@end


@implementation RatingStatCell
@synthesize ratingLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        ratingLabel = [[UILabel alloc] init];
        [ratingLabel setTextAlignment:NSTextAlignmentRight];
        [self.ratingLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.f]];
        [self.contentView addSubview: ratingLabel];
    }
    return self;
}


- (void) layoutSubviews {
    [super layoutSubviews];
    CGFloat screenWidth = self.contentView.bounds.size.width;
    CGFloat imageWidth = 0;
    if (self.imageView) {
        imageWidth = self.imageView.frame.size.width;
    }
    CGFloat accessoryWidth;
    if (self.accessoryType == UITableViewCellAccessoryDisclosureIndicator) {
        accessoryWidth = 20;
    } else {
        accessoryWidth = 0;
    }
    [self.textLabel setFrame:CGRectMake(imageWidth + 10, 2, (screenWidth - imageWidth - accessoryWidth + 60)/2, 22)];
    [self.ratingLabel setFrame:CGRectMake(imageWidth + 10 + (screenWidth - imageWidth - accessoryWidth - 20)/2, 2, (screenWidth - imageWidth - accessoryWidth - 60)/2, 22)];
    [self.detailTextLabel setFrame:CGRectMake(imageWidth + 10, 24, screenWidth - imageWidth - accessoryWidth - 20, 18)];
    [self.imageView setFrame:CGRectMake(0, 0, imageWidth, imageWidth)];
    
    //        NSLog(@"kittenfont ");
}

@end