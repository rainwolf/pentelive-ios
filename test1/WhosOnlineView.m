//
//  WhosOnlineView.m
//  penteLive
//
//  Created by rainwolf on 01/11/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

#import <Foundation/Foundation.h>

//
//  RatingStatsView.m
//  penteLive
//
//  Created by rainwolf on 23/05/16.
//  Copyright © 2016 Triade. All rights reserved.
//

#import "WhosOnlineView.h"
#import "SVWebViewController.h"

//@implementation Player
//@synthesize playerName, rating;
//@synthesize color, crown;
//@end

@implementation WhosOnlineView
@synthesize player;
@synthesize players;
@synthesize vc;


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [players count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString * cellIdentifier = @"Cell";
    
    PlayerCell *cell = (PlayerCell *) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[PlayerCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    Player *playr = [players objectAtIndex:indexPath.row];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    NSMutableString *txtStr = [[NSMutableString alloc] initWithString: [playr name]];
    int crown = [playr crown];
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
        case 4:
            textAttachment.image = [UIImage imageNamed:@"kothcrown.gif"];
            break;
            
        default:
            break;
    }
    NSAttributedString *crownStr = [NSAttributedString attributedStringWithAttachment:textAttachment];
    NSMutableString *ratingStr = [NSMutableString stringWithString:@"\u25A0 "];
    if ([[playr rating] length] == 3) {
        [ratingStr appendString:@"  "];
    }
    [ratingStr appendString: [playr rating]];
    NSMutableAttributedString *tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
    [self addColorOfRating: [playr rating] toString: tmpStr];
    ((PlayerCell *) cell).ratingLabel.attributedText = tmpStr;
    
    tmpStr = [[NSMutableAttributedString alloc] initWithString: txtStr];
    [tmpStr addAttribute:NSForegroundColorAttributeName value:UIColorFromRGB([playr color]) range:NSMakeRange(0, [[playr name] length])];
    [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
    if ([playr color] != 0) {
        [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[playr name] length])];
    }
    [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
    [tmpStr appendAttributedString:crownStr];
    cell.textLabel.attributedText = tmpStr;
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

    cell.detailTextLabel.text = [NSString stringWithFormat:@"Total games: %@", [playr numberOfGames]];
    cell.backgroundColor = [UIColor colorWithRed: 222.0/256 green:236.0/256 blue:222.0/256 alpha:1];

    if (playr.color != 0) {
        UIImage *imgV = [player.avatars objectForKey: playr.name];
        cell.imageView.image = imgV;
    } else {
        cell.imageView.image = nil;
    }
//    cell.textLabel.text =  [players objectAtIndex: indexPath.row].name;
//    NSMutableString *ratingStr = [NSMutableString stringWithString:@"\u25A0 "];
//    if ([[players objectAtIndex: indexPath.row].rating length] == 3) {
//        [ratingStr appendString:@"  "];
//    }
//    [ratingStr appendString: [players objectAtIndex: indexPath.row].rating];
//    NSMutableAttributedString *tmpStr = [[NSMutableAttributedString alloc] initWithString: ratingStr];
//    [self addColorOfRating: [players objectAtIndex: indexPath.row].rating toString: tmpStr];
//    cell.ratingLabel.attributedText = tmpStr;
//    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [vc toInvitationsWithPlayer:[players objectAtIndex:indexPath.row].name];

//    NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:@"username"];
//    NSString *game = nil;
//    if ([[[ratingStats objectAtIndex: indexPath.row] game] isEqualToString:@"Pente"])
//        game = @"51";
//    if ([[[ratingStats objectAtIndex: indexPath.row] game] isEqualToString:@"Gomoku"])
//        game = @"55";
//    if ([[[ratingStats objectAtIndex: indexPath.row] game] isEqualToString:@"D-Pente"])
//        game = @"57";
//    if ([[[ratingStats objectAtIndex: indexPath.row] game] isEqualToString:@"G-Pente"])
//        game = @"59";
//    if ([[[ratingStats objectAtIndex: indexPath.row] game] isEqualToString:@"Boat-Pente"])
//        game = @"65";
//    if ([[[ratingStats objectAtIndex: indexPath.row] game] isEqualToString:@"Poof-Pente"])
//        game = @"61";
//    if ([[[ratingStats objectAtIndex: indexPath.row] game] isEqualToString:@"Connect6"])
//        game = @"63";
//    if ([[[ratingStats objectAtIndex: indexPath.row] game] isEqualToString:@"Keryo-Pente"])
//        game = @"53";
//    NSString *urlString = [NSString stringWithFormat:@"https://www.pente.org/gameServer/viewLiveGames?p=%@&g=%@", username, game];
//    SVWebViewController *webViewController = [[SVWebViewController alloc] initWithAddress: urlString];
//    [vc.actionPopoverView dismiss];
//    [vc.navigationController pushViewController:webViewController animated:YES];
    
    
}


-(void) addColorOfRating: (NSString *) rating toString: (NSMutableAttributedString *) str {
    int ratingInt = [rating intValue];
    UIColor *ratingColor = [UIColor blackColor];
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
    NSString *strString = [str string];
    [str addAttribute:NSForegroundColorAttributeName value: ratingColor range: [strString rangeOfString: @"\u25A0"]];
    [str addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue-Bold" size:12.f] range: [strString rangeOfString: @"\u25A0"]];
}

@end


@implementation PlayerCell
@synthesize ratingLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        ratingLabel = [[UILabel alloc] init];
        [ratingLabel setTextAlignment:NSTextAlignmentRight];
        [self.ratingLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.f]];
        [self.contentView addSubview: ratingLabel];
    }
    return self;
}


- (void) layoutSubviews {
    [super layoutSubviews];
    CGFloat screenWidth = self.contentView.bounds.size.width;
    CGFloat imageWidth = 0;
    if (self.imageView.image) {
        [self.imageView setFrame:CGRectMake(0, 0, self.contentView.frame.size.height, self.contentView.frame.size.height)];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageWidth = self.imageView.frame.size.width;
    } else {
        [self.imageView setFrame:CGRectMake(0, 0, 0, 0)];
    }
    CGFloat accessoryWidth;
    //    if (self.accessoryType == UITableViewCellAccessoryDisclosureIndicator) {
    //        accessoryWidth = 20;
    //    } else {
    //        accessoryWidth = 0;
    //    }
    accessoryWidth = 0;
    [self.textLabel setFrame:CGRectMake(imageWidth + 10, 2, (screenWidth - imageWidth - accessoryWidth + 60)*2/3, 22)];
    [self.ratingLabel setFrame:CGRectMake(imageWidth + 10 + (screenWidth - imageWidth - accessoryWidth - 20)*2/3, 2, (screenWidth - imageWidth - accessoryWidth - 60)/2, 22)];
    [self.detailTextLabel setFrame:CGRectMake(imageWidth + 10, 24, screenWidth - imageWidth - accessoryWidth - 20, 18)];
    [self.imageView setFrame:CGRectMake(0, 0, imageWidth, imageWidth)];
    
    //        NSLog(@"kittenfont ");
}

@end
