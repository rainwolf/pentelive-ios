//
//  WhosOnlineView.h
//  penteLive
//
//  Created by rainwolf on 01/11/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

#ifndef WhosOnlineView_h
#define WhosOnlineView_h

#endif /* WhosOnlineView_h */

#import "GamesTableViewController.h"
#import "KOTHTableViewController.h"
#import <UIKit/UIKit.h>

//@interface Player : NSObject {
//    NSString *playerName, *rating;
//    int color, crown;
//}
//@property(nonatomic,retain) NSString *playerName, *rating;
//@property(atomic,assign) int color, crown;
//
//
//@end
//

@interface Room : NSObject {
    NSString *name;
    NSMutableArray<Player *> *players;
}
@property(nonatomic, retain, readwrite) NSString *name;
@property(nonatomic, retain, readwrite) NSMutableArray<Player *> *players;
- (void)addPlayer:(Player *)player;

@end

@interface WhosOnlineView
    : UITableView <UITableViewDelegate, UITableViewDataSource> {
    PentePlayer *player;
    NSArray<Room *> *rooms;
    GamesTableViewController *vc;
}

@property(retain, nonatomic, readwrite) NSArray<Room *> *rooms;
@property(retain, nonatomic, readwrite) GamesTableViewController *vc;
@property(retain, nonatomic, readwrite) PentePlayer *player;

@end

@interface PlayerCell : UITableViewCell {
    UILabel *ratingLabel;
}
@property(nonatomic, retain, readwrite) UILabel *ratingLabel;

@end
