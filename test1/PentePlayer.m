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

@implementation Tournament
@synthesize name, tournamentID, tournamentState, date, round, game;
@end

@implementation KingOfTheHill
@synthesize game, numPlayers, currentKing;
@synthesize member, king;

@end

@implementation PentePlayer
@synthesize playerName;
@synthesize invitations, sentInvitations, activeGames, nonActiveGames, publicInvitations, messages, ratingStats, tournaments, hills;
@synthesize showAds, subscriber;
@synthesize avatars;
@synthesize pendingAvatarChecks;
@synthesize myColor;


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
        tournaments = [[NSMutableArray alloc] init];
        hills = [[NSMutableArray alloc] init];
        avatars = [[NSMutableDictionary alloc] init];
        showAds = YES;
        subscriber = NO;
        
        pendingAvatarChecks = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void) addUser: (NSString *) username {
    if ([pendingAvatarChecks containsObject: username]) {
        return;
    }
    [pendingAvatarChecks addObject:username];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString: [NSString stringWithFormat:@"https://pente.org/gameServer/avatar?name=%@", username]];
        NSURLSessionDownloadTask *downloadPhotoTask = [[NSURLSession sharedSession]
                                                       downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                                                           UIImage *downloadedImage = [UIImage imageWithData: [NSData dataWithContentsOfURL:location]];
//                                                           UIImageView *imgV = [[UIImageView alloc] initWithImage: downloadedImage];
                                                           if (downloadedImage) {
                                                               [avatars setObject: downloadedImage forKey:username];
                                                           }
                                                       }];
        [downloadPhotoTask resume];
    });
}


@end
