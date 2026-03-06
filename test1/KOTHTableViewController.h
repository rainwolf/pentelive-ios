//
//  KOTHTableViewController.h
//  penteLive
//
//  Created by rainwolf on 02/07/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "KOTHChallengeView.h"
#import "PentePlayer.h"
#import "PopoverView.h"
#import <UIKit/UIKit.h>

@class Hill;

@interface Player : NSObject {
    NSString *name, *rating, *lastGame, *numberOfGames;
    BOOL canBeChallenged;
    int crown, color;
}
@property(retain, nonatomic, readwrite) NSString *name, *rating, *lastGame,
    *numberOfGames;
@property(assign, atomic, readwrite) BOOL canBeChallenged;
@property(assign, atomic, readwrite) int crown, color;
- (NSAttributedString *)attributedName:(BOOL)dark;
- (NSAttributedString *)ratingString:(BOOL)dark;
@end

@interface KOTHTableViewController
    : UITableViewController <PopoverViewDelegate, UIScrollViewDelegate> {
    Hill *hill;
    KingOfTheHill *hillSummary;
    PentePlayer *player;
    PopoverView *actionPopoverView;
    KOTHChallengeView *challengeView;
}

@property(nonatomic, retain, readwrite) PentePlayer *player;
@property(nonatomic, retain, readwrite) Hill *hill;
@property(nonatomic, retain, readwrite) KingOfTheHill *hillSummary;
@property(nonatomic, retain, readwrite) PopoverView *actionPopoverView;
@property(nonatomic, retain, readwrite) KOTHChallengeView *challengeView;

@end
