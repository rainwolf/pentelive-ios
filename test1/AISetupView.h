//
//  RatingStatsView.h
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SimplePickerInputTableViewCell.h"
#import "BoardView.h"


@interface AISetupView : UITableView <UITableViewDelegate, UITableViewDataSource, SimplePickerInputTableViewCellDelegate> {
    int difficulty;
    BOOL playAsWhite;
    SimplePickerInputTableViewCell *difficultyCell;
    UITableViewCell *colorCell, *gameCell;
    BoardView *board, *zBoard;
}
@property(atomic,readwrite, assign) int difficulty;
@property(atomic,readwrite, assign) BOOL playAsWhite;
@property(nonatomic, retain, readwrite) SimplePickerInputTableViewCell *difficultyCell;
@property(nonatomic, retain, readwrite) UITableViewCell *colorCell, *gameCell;
@property(nonatomic, retain, readwrite) BoardView *board, *zBoard;

@end
