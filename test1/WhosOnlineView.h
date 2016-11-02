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

#import <UIKit/UIKit.h>
#import "GamesTableViewController.h"
#import "KOTHTableViewController.h"

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

@interface PlayerCell : UITableViewCell {
    UILabel *ratingLabel;
}
@property(nonatomic, retain, readwrite) UILabel *ratingLabel;

@end


@interface WhosOnlineView : UITableView <UITableViewDelegate, UITableViewDataSource> {
    PentePlayer *player;
    NSArray<Player *> *players;
    GamesTableViewController *vc;
}

@property(retain, nonatomic, readwrite) NSArray<Player *> *players;
@property(retain, nonatomic, readwrite) GamesTableViewController *vc;
@property(retain, nonatomic, readwrite) PentePlayer *player;

@end
