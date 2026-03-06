//
//  RatingStatsView.h
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "GamesTableViewController.h"
#import "PentePlayer.h"
#import <UIKit/UIKit.h>

@interface RatingStatCell : UITableViewCell {
    UILabel *ratingLabel;
}
@property(nonatomic, retain, readwrite) UILabel *ratingLabel;

@end

@interface RatingStatsView
    : UITableView <UITableViewDelegate, UITableViewDataSource> {
    NSArray<RatingStat *> *ratingStats;
    GamesTableViewController *vc;
}
@property(retain, nonatomic, readwrite) NSArray<RatingStat *> *ratingStats;
@property(retain, nonatomic, readwrite) GamesTableViewController *vc;

@end
