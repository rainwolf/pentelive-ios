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

#import "penteLive-Swift.h"

//@implementation Player
//@synthesize playerName, rating;
//@synthesize color, crown;
//@end


@implementation Room
@synthesize name;
@synthesize players;

-(void) addPlayer: (Player *) player {
    if (!players) {
        players = [[NSMutableArray alloc] init];
    }
    [players addObject:player];
}
@end

@implementation WhosOnlineView
@synthesize player;
@synthesize rooms;
@synthesize vc;


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [rooms count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[rooms objectAtIndex:section].players count];
}

-(NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [[rooms objectAtIndex:section] name];
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString * cellIdentifier = @"Cell";
    
    PlayerCell *cell = (PlayerCell *) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[PlayerCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    Player *playr = [[rooms objectAtIndex:indexPath.section].players objectAtIndex:indexPath.row];
    if ([[[rooms objectAtIndex:indexPath.section] name] isEqualToString:@"Mobile"]) {
        cell.backgroundColor = [UIColor colorWithRed: 222.0/256 green:236.0/256 blue:222.0/256 alpha:1];
//        [cell setUserInteractionEnabled:YES];
    } else {
        if (@available(iOS 13.0, *)) {
            cell.backgroundColor = [UIColor systemBackgroundColor];
        } else {
            cell.backgroundColor = [UIColor whiteColor];
        }
    }
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
        default:
            if (crown > 3) {
                textAttachment.image = [UIImage imageNamed: [NSString stringWithFormat:@"kothcrown%i", crown-3]];
            }
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
    if ([playr color] != 0 || [[[rooms objectAtIndex:indexPath.section] name] isEqualToString:@"Mobile"]) {
        [tmpStr addAttribute:NSForegroundColorAttributeName value:UIColorFromRGB([playr color]) range:NSMakeRange(0, [[playr name] length])];
    }
    [tmpStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"HelveticaNeue" size:16.f] range:NSMakeRange(0, [tmpStr length])];
    if ([playr color] != 0) {
        [tmpStr addAttribute:NSFontAttributeName value: [UIFont fontWithName:@"HelveticaNeue-Bold" size:16] range:NSMakeRange(0, [[playr name] length])];
    }
    if (crown > 0) {
        [tmpStr appendAttributedString:[[NSMutableAttributedString alloc] initWithString:@" "]];
        [tmpStr appendAttributedString:crownStr];
    }
    cell.textLabel.attributedText = tmpStr;
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];

    cell.detailTextLabel.text = [NSString stringWithFormat: NSLocalizedString(@"Total games: %@",nil), [playr numberOfGames]];

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
//    NSLog(@"didselect");
    if ([[self tableView:tableView titleForHeaderInSection:indexPath.section] isEqualToString:@"Mobile"]) {
//        NSLog(@"mobile");
        [vc toInvitationsWithPlayer:[[rooms objectAtIndex:indexPath.section].players objectAtIndex:indexPath.row].name];
    } else {
        NSString *username = [[NSUserDefaults standardUserDefaults] objectForKey:@"username"];
        NSString *password = [[NSUserDefaults standardUserDefaults] objectForKey:@"password"];
//        NSLog(@"else %@", [[rooms objectAtIndex:indexPath.section].players objectAtIndex:indexPath.row].name);
        NSString *address = [NSString stringWithFormat:@"https://www.pente.org/gameServer/profile?viewName=%@&name2=%@&password2=%@", [[rooms objectAtIndex:indexPath.section].players objectAtIndex:indexPath.row].name, username, password];
        PenteWebViewController *webVC = [[PenteWebViewController alloc] initWithAddress:address];
        [vc.navigationController pushViewController:webVC animated:YES];
        [vc.actionPopoverView dismiss];
    }


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
        [self.textLabel setFont:[UIFont fontWithName:@"HelveticaNeue" size:16.f]];
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
    CGFloat accessoryWidth = self.accessoryView.frame.size.width;
    [self.textLabel setFrame:CGRectMake(imageWidth + 10, 2, (screenWidth - imageWidth - accessoryWidth + 60)/2, 22)];
    [self.ratingLabel setFrame:CGRectMake(imageWidth + 10 + (screenWidth - imageWidth - accessoryWidth - 20)/2, 2, (screenWidth - imageWidth - accessoryWidth - 20)/2, 22)];
    [self.detailTextLabel setFrame:CGRectMake(imageWidth + 10, 24, screenWidth - imageWidth - accessoryWidth - 20, 18)];
    [self.imageView setFrame:CGRectMake(0, 0, imageWidth, imageWidth)];
    
    //        NSLog(@"kittenfont ");
}

@end
