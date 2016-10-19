//
//  RatingStatsView.h
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SimplePickerInputTableViewCell.h"
#import "DBBoardView.h"


@interface DBSetupView : UITableView <UITableViewDelegate, UITableViewDataSource> {
    UITableViewCell *gameCell, *sortCell;
    DBBoardView *board, *zBoard;
}
@property(nonatomic, retain, readwrite) UITableViewCell *gameCell, *sortCell;
@property(nonatomic, retain, readwrite) DBBoardView *board, *zBoard;

@end
