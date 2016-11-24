//
//  DBAISetupView.h
//  penteLive
//
//  Created by rainwolf on 23/11/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

#ifndef DBAISetupView_h
#define DBAISetupView_h


#endif /* DBAISetupView_h */


#import <UIKit/UIKit.h>
//#import "DBBoardView.h"
#import "SimplePickerInputTableViewCell.h"
@class DatabaseViewController;


@interface DBAISetupView : UITableView <UITableViewDelegate, UITableViewDataSource, SimplePickerInputTableViewCellDelegate> {
    int difficulty;
    BOOL useOpeningBook;
    SimplePickerInputTableViewCell *difficultyCell;
    UITableViewCell *openingBookCell;
    DatabaseViewController *vc;
}
@property(atomic,readwrite, assign) int difficulty;
@property(atomic,readwrite, assign) BOOL playAsWhite, useOpeningBook;
@property(nonatomic, retain, readwrite) SimplePickerInputTableViewCell *difficultyCell;
@property(nonatomic, retain, readwrite) UITableViewCell *openingBookCell;
@property(nonatomic, retain, readwrite) DatabaseViewController *vc;
@end
