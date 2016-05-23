//
//  PentePlayer.h
//  test1
//
//  Created by rainwolf on 14/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import <Foundation/Foundation.h>

#define UIColorFromRGB(rgbValue) \
[UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
alpha:1.0]

@interface Game : NSObject {
    NSString *gameID, *setID, *gameType, *opponentName, *opponentRating, *myColor, *remainingTime, *ratedNot, *privateGame;
    UIColor *nameColor;
    int crown;
}
@property(nonatomic,retain) NSString *gameID;
@property(nonatomic,retain) NSString *setID;
@property(nonatomic,retain) NSString *gameType;
@property(nonatomic,retain) NSString *opponentName;
@property(nonatomic,retain) NSString *opponentRating;
@property(nonatomic,retain) NSString *myColor;
@property(nonatomic,retain) NSString *remainingTime;
@property(nonatomic,retain) NSString *ratedNot;
@property(nonatomic,retain) NSString *privateGame;
@property(nonatomic,retain) UIColor *nameColor;
@property(atomic, assign) int crown;
@end

@interface Message : NSObject {
    NSString *messageID, *author, *subject, *timeStamp, *unread;
    UIColor *nameColor;
    int crown;
}
@property(nonatomic,retain) NSString *messageID;
@property(nonatomic,retain) NSString *author;
@property(nonatomic,retain) NSString *subject;
@property(nonatomic,retain) NSString *timeStamp;
@property(nonatomic,retain) NSString *unread;
@property(nonatomic,retain) UIColor *nameColor;
@property(atomic, assign) int crown;

@end

@interface RatingStat : NSObject {
    NSString *game, *rating, *lastPlayed, *totalGames;
    int crown;
}
@property(nonatomic,retain) NSString *game, *rating, *lastPlayed, *totalGames;
@property(atomic, assign) int crown;

@end


@interface PentePlayer : NSObject {
    NSString *playerName;
    NSMutableArray *invitations, *sentInvitations, *activeGames, *nonActiveGames, *publicInvitations, *messages, *ratingStats;
    BOOL showAds, subscriber;
}
@property(nonatomic,retain) NSString *playerName;
@property(nonatomic,retain) NSMutableArray *invitations, *sentInvitations, *activeGames, *nonActiveGames, *publicInvitations, *messages, *ratingStats;
@property(atomic, assign) BOOL showAds, subscriber;
@end
