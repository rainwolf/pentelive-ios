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
        } else if ([ratedNot isEqualToString:@"Rated, beginner"]) {
            localizedRatedNot = NSLocalizedString(@"Rated, beginner", nil);
        } else if ([ratedNot isEqualToString:@"Not Rated, beginner"]) {
            localizedRatedNot = NSLocalizedString(@"Not Rated, beginner", nil);
        }
    }
    return localizedRatedNot;
}

-(NSAttributedString *) attributedName {
    NSMutableAttributedString *txtStr;
    if ([opponentName isEqualToString:@"Anyone"]) {
        txtStr = [[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Anyone", nil)];
    } else {
        txtStr = [[NSMutableAttributedString alloc] initWithString:opponentName];
    }
    if (![nameColor isEqual:UIColorFromRGB(0)]) {
        [txtStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [txtStr length])];
    } else {
        [txtStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue" size:16] range:NSMakeRange(0, [txtStr length])];
    }
    [txtStr addAttribute:NSForegroundColorAttributeName value:nameColor range:NSMakeRange(0, [txtStr length])];
    [txtStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
    if (crown > 0) {
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        switch (crown) {
            case 1:
                textAttachment.image = [UIImage imageNamed:@"crown.gif"];
                break;
            case 2:
                textAttachment.image = [UIImage imageNamed:@"scrown.gif"];
                break;
            case 3:
                textAttachment.image = [UIImage imageNamed:@"bcrown.gif"];
                break;
            default:
                if (crown > 3) {
                    textAttachment.image = [UIImage imageNamed: [NSString stringWithFormat:@"kothcrown%i", crown-3]];
                }
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        [txtStr appendAttributedString:crownStr];
    }
    return txtStr;
}

-(NSAttributedString *) ratingString {
    int ratingInt = [opponentRating intValue];
    UIColor *ratingColor;
    if (ratingInt >= 1900) {
        ratingColor = [UIColor redColor];
    } else if (ratingInt >= 1700) {
        ratingColor = [UIColor colorWithRed:0.98 green:0.96 blue:0.03 alpha:1.0];
    } else if (ratingInt >= 1400) {
        ratingColor = [UIColor blueColor];
    } else if (ratingInt >= 1000) {
        ratingColor = [UIColor colorWithRed:30.0/255 green: 130.0/255 blue:76.0/255 alpha:1.0];
    } else {
        ratingColor = [UIColor grayColor];
    }
    NSMutableAttributedString *txtStr = [[NSMutableAttributedString alloc] initWithString:@"\u25A0 "];
    [txtStr addAttribute:NSForegroundColorAttributeName value: ratingColor range: NSMakeRange(0, 1)];
    if ([opponentRating length]<4) {
        [txtStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"  "]];
    }
    [txtStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Bold" size:12.f] range: NSMakeRange(0, 1)];
    [txtStr appendAttributedString:[[NSAttributedString alloc] initWithString:opponentRating]];
    return txtStr;
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
-(NSAttributedString *) attributedName {
    NSMutableAttributedString *txtStr;
    txtStr = [[NSMutableAttributedString alloc] initWithString:author];
    if (![nameColor isEqual:UIColorFromRGB(0)]) {
        [txtStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [txtStr length])];
    } else {
        [txtStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue" size:16] range:NSMakeRange(0, [txtStr length])];
    }
    [txtStr addAttribute:NSForegroundColorAttributeName value:nameColor range:NSMakeRange(0, [txtStr length])];
    [txtStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
    if (crown > 0) {
        NSTextAttachment *textAttachment = [[NSTextAttachment alloc] init];
        switch (crown) {
            case 1:
                textAttachment.image = [UIImage imageNamed:@"crown.gif"];
                break;
            case 2:
                textAttachment.image = [UIImage imageNamed:@"scrown.gif"];
                break;
            case 3:
                textAttachment.image = [UIImage imageNamed:@"bcrown.gif"];
                break;
            default:
                if (crown > 3) {
                    textAttachment.image = [UIImage imageNamed: [NSString stringWithFormat:@"kothcrown%i", crown-3]];
                }
                break;
        }
        NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
        [txtStr appendAttributedString:crownStr];
    }
    return txtStr;
}
@end

@implementation RatingStat
@synthesize game, rating, totalGames, lastPlayed;
@synthesize crown, gameId;
@end

@implementation Tournament
@synthesize name, tournamentID, tournamentState, date, round, game;
@end

@implementation KingOfTheHill
@synthesize game, numPlayers, currentKing;
@synthesize member, king, canSendOpen;
@synthesize gameId;

@end

@implementation PentePlayer
@synthesize playerName;
@synthesize invitations, sentInvitations, activeGames, nonActiveGames, publicInvitations, messages, ratingStats, tournaments, hills;
//@synthesize showAds, subscriber;
@synthesize dbAccess, emailMe;
@synthesize avatars;
@synthesize pendingAvatarChecks;
@synthesize myColor;
@synthesize tbHills, tbRatings;
@synthesize onlinePlayers;

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
        dbAccess = NO;
        emailMe = YES;
        
        pendingAvatarChecks = [[NSMutableArray alloc] init];
        
        onlinePlayers = [[NSDictionary alloc] init];
    }
    return self;
}

-(void) addUser: (NSString *) username {
    if ([pendingAvatarChecks containsObject: username]) {
        return;
    }
    [pendingAvatarChecks addObject:username];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString: [NSString stringWithFormat:@"https://www.pente.org/gameServer/avatar?name=%@", username]];
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

-(NSAttributedString *) markIfOnline: (NSString *) name andAttributedName: (NSAttributedString *) attributedString {
    if ([onlinePlayers objectForKey:name]) {
        NSMutableAttributedString *tmpStr = [[NSMutableAttributedString alloc] initWithAttributedString:attributedString];
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString: [NSString stringWithFormat:@" \u25CF"]]];
        [tmpStr addAttribute:NSForegroundColorAttributeName value:[UIColor greenColor] range:NSMakeRange([tmpStr length] - 1, 1)];
        return tmpStr;
    }
    return attributedString;
}


-(BOOL) showAds {
    if (development) {
        return YES;
    }
    return showAds;
}
-(BOOL) subscriber {
    if (development) {
        return NO;
    }
    return subscriber;
}
-(void) setShowAds:(BOOL)showAdss {
    showAds = showAdss;
}
-(void) setSubscriber:(BOOL)subscribers {
    subscriber = subscribers;
}

@end
