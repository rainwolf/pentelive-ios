//
//  PentePlayer.m
//  test1
//
//  Created by rainwolf on 14/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "PentePlayer.h"

@implementation Game
@synthesize setID;
@synthesize gameID;
@synthesize gameType;
@synthesize opponentName;
@synthesize opponentRating;
@synthesize myColor;
@synthesize remainingTime;
@synthesize ratedNot;
@synthesize privateGame;
@synthesize nameColor;
@synthesize crown;

@end

@implementation Message
@synthesize messageID;
@synthesize author;
@synthesize subject;
@synthesize timeStamp;
@synthesize unread;
@synthesize nameColor;
@synthesize crown;

@end

@implementation RatingStat
@synthesize game, rating, totalGames, lastPlayed;
@synthesize crown;

@end


@implementation PentePlayer
@synthesize playerName;
@synthesize invitations, sentInvitations, activeGames, nonActiveGames, publicInvitations, messages, ratingStats;
@synthesize showAds, subscriber;

-(id) init {
    self = [super init];
    if (self) {
        invitations = [[NSMutableArray alloc] init];
        sentInvitations = [[NSMutableArray alloc] init];
        activeGames = [[NSMutableArray alloc] init];
        nonActiveGames = [[NSMutableArray alloc] init];
        publicInvitations = [[NSMutableArray alloc] init];
        messages = [[NSMutableArray alloc] init];
        ratingStats = [[NSMutableArray alloc] init];
        showAds = YES;
        subscriber = NO;
    }
    return self;
}


@end
