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


@interface DateTableViewCell : UITableViewCell {
    UITextField *textField;
}
@property(nonatomic, retain, readwrite) UITextField *textField;

@end

@interface DBSetupView : UITableView <StringInputTableViewCellDelegate, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, SimplePickerInputTableViewCellDelegate, UIPickerViewDelegate> {
    UITableViewCell *sortCell, *winnerCell, *eitherOrBothp1p2Cell, *excludeTimeoutCell, *liveOrTBCell;
    DateTableViewCell *beforeCell, *afterCell;
    SimplePickerInputTableViewCell *p1RatingCell, *p2RatingCell, *gameCell;
    DBBoardView *board, *zBoard;
    StringInputTableViewCell *player1Cell, *player2Cell;
    UIDatePicker *beforePicker, *afterPicker;
    UIToolbar *datePickerToolbar;
    UIBarButtonItem *clearButton;
}
@property(nonatomic, retain, readwrite) UITableViewCell *sortCell, *winnerCell, *eitherOrBothp1p2Cell, *excludeTimeoutCell, *liveOrTBCell;
@property(nonatomic, retain, readwrite) DateTableViewCell *beforeCell, *afterCell;
@property(nonatomic, retain, readwrite) SimplePickerInputTableViewCell *p1RatingCell, *p2RatingCell, *gameCell;
@property(nonatomic, retain, readwrite) DBBoardView *board, *zBoard;
@property(nonatomic, retain, readwrite) StringInputTableViewCell *player1Cell, *player2Cell;
@property(nonatomic, retain, readwrite) UIDatePicker *beforePicker, *afterPicker;
@property(nonatomic, retain, readwrite) UIToolbar *datePickerToolbar;
@property(nonatomic, retain, readwrite) UIBarButtonItem *clearButton;


@end
