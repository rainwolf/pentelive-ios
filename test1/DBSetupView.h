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
#import "StringInputTableViewCell.h"

@interface DBSetupView : UITableView <StringInputTableViewCellDelegate, UITableViewDelegate, UITableViewDataSource> {
    UITableViewCell *gameCell, *sortCell, *winnerCell;
    DBBoardView *board, *zBoard;
    StringInputTableViewCell *player1Cell, *player2Cell;
}
@property(nonatomic, retain, readwrite) UITableViewCell *gameCell, *sortCell, *winnerCell;
@property(nonatomic, retain, readwrite) DBBoardView *board, *zBoard;
@property(nonatomic, retain, readwrite) StringInputTableViewCell *player1Cell, *player2Cell;

@end
