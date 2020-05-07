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

#define development NO
#define HEADERSTRING @"<header><meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no'></header>"

@interface Game : NSObject {
    NSString *gameID, *setID, *gameType, *opponentName, *opponentRating, *myColor, *remainingTime, *ratedNot, *privateGame, *localizedTime, *localizedRatedNot;
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
@property(nonatomic,retain, getter=localizedTimeString) NSString *localizedTime;
@property(nonatomic,retain, getter=localizedRatedNot) NSString *localizedRatedNot;

@property(nonatomic,retain) NSString *ratedNot;
@property(nonatomic,retain) NSString *privateGame;
@property(nonatomic,retain) UIColor *nameColor;
@property(atomic, assign) int crown;

-(NSAttributedString *) attributedName;
-(NSAttributedString *) ratingString;
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
-(NSAttributedString *) attributedName;
@end

@interface RatingStat : NSObject {
    NSString *game, *rating, *lastPlayed, *totalGames;
    int crown, gameId;
}
@property(nonatomic,retain) NSString *game, *rating, *lastPlayed, *totalGames;
@property(atomic, assign) int crown, gameId;
@end

@interface Tournament : NSObject {
    NSString *game, *name, *tournamentID, *round, *tournamentState, *date;
}
@property(nonatomic,retain) NSString *game, *name, *tournamentID, *round, *tournamentState, *date;
@end

@interface KingOfTheHill : NSObject {
    NSString *game, *numPlayers, *currentKing;
    BOOL member, king, canSendOpen;
    int gameId;
}
@property(nonatomic,retain) NSString *game, *numPlayers, *currentKing;
@property(assign, atomic) BOOL member, king, canSendOpen;
@property(assign, atomic) int gameId;
@end



@interface PentePlayer : NSObject {
    NSString *playerName;
    NSMutableArray *invitations, *sentInvitations, *activeGames, *nonActiveGames, *publicInvitations, *messages, *ratingStats, *tournaments, *hills;
    int tbHills, tbRatings;
    BOOL showAds, subscriber, dbAccess, emailMe;
    NSMutableDictionary<NSString *, UIImage *> *avatars;
    NSMutableArray<NSString *> *pendingAvatarChecks;
    UIColor *myColor;
    NSDictionary<NSString *, NSString *> *onlinePlayers;
}
@property(nonatomic,retain) NSString *playerName;
@property(nonatomic,retain) NSMutableArray *invitations, *sentInvitations, *activeGames, *nonActiveGames, *publicInvitations, *messages, *ratingStats, *tournaments, *hills;
@property(atomic, assign) BOOL dbAccess, emailMe;
@property(atomic, assign, getter=subscriber, setter=setSubscriber:) BOOL subscriber;
@property(atomic, assign, getter=showAds, setter=setShowAds:) BOOL showAds;
@property(nonatomic, retain, readwrite) NSMutableDictionary<NSString *, UIImage *> *avatars;
@property(nonatomic, retain, readwrite) NSMutableArray<NSString *> *pendingAvatarChecks;
@property(nonatomic, retain, readwrite) UIColor *myColor;
@property(atomic, assign) int tbHills, tbRatings;
@property(nonatomic, retain, readwrite) NSDictionary<NSString *, NSString *> *onlinePlayers;

-(void) addUser: (NSString *) username;
-(NSAttributedString *) markIfOnline: (NSString *) name andAttributedName: (NSAttributedString *) attributedString;

@end
