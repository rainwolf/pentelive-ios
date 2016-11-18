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
@synthesize localizedTime;
@synthesize ratedNot;
@synthesize localizedRatedNot;
@synthesize privateGame;
@synthesize nameColor;
@synthesize crown;

-(NSString *) localizedTimeString {
    if (!localizedTime) {
        if ([remainingTime containsString:@"minutes"]) {
            NSArray<NSString *>* splitTime = [remainingTime componentsSeparatedByString:@" "];
            NSString *hour = [splitTime objectAtIndex:0], *minutes = [splitTime objectAtIndex: 2];
            if ([hour isEqualToString:@"1"] && [minutes isEqualToString:@"1"]) {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ hour, %@ minute", nil), hour, minutes];
            } else if ([hour isEqualToString:@"1"]) {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ hour, %@ minutes", nil), hour, minutes];
            } else if ([minutes isEqualToString:@"1"]) {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ hours, %@ minute", nil), hour, minutes];
            } else {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ hours, %@ minutes", nil), hour, minutes];
            }
        } else if ([remainingTime containsString:@"hours"]) {
            NSArray<NSString *>* splitTime = [remainingTime componentsSeparatedByString:@" "];
            NSString *hour = [splitTime objectAtIndex:2], *days = [splitTime objectAtIndex: 0];
            if ([hour isEqualToString:@"1"] && [days isEqualToString:@"1"]) {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ day, %@ hour", nil), days, hour];
            } else if ([hour isEqualToString:@"1"]) {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ days, %@ hour", nil), days, hour];
            } else if ([days isEqualToString:@"1"]) {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ day, %@ hours", nil), days, hour];
            } else {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ days, %@ hours", nil), days, hour];
            }
        } else {
            NSString *days = [remainingTime substringToIndex:[remainingTime rangeOfString:@"days"].location];
            if ([days isEqualToString:@"1"]) {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ day per move", nil), days];
            } else {
                localizedTime = [NSString stringWithFormat: NSLocalizedString(@"%@ days per move", nil), days];
            }
        }
    }
    return localizedTime;
}
-(NSString *) localizedRatedNot {
    if (!localizedRatedNot) {
        if ([ratedNot isEqualToString:@"Rated"]) {
            localizedRatedNot = NSLocalizedString(@"Rated", nil);
        } else if ([ratedNot isEqualToString:@"Not Rated"]) {
            localizedRatedNot = NSLocalizedString(@"Not Rated", nil);
        } else if ([ratedNot isEqualToString:@"KotH"]) {
            localizedRatedNot = NSLocalizedString(@"KotH", nil);
        } else if ([ratedNot isEqualToString:@"Tournament"]) {
            localizedRatedNot = NSLocalizedString(@"Tournament", nil);
        }
    }
    return localizedRatedNot;
}

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
@synthesize member, king, canSendOpen;

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
