//
//  GamesTableViewController.h
//  test1
//
//  Created by rainwolf on 12/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PentePlayer.h"
#import "BoardViewController.h"
#import "MessagesViewController.h"
#import "UIPullToReloadTableViewController.h"
//#import "IASKAppSettingsViewController.h"
#import "SettingsViewController.h"
#import "InvitationsViewController.h"
#import "ICDMaterialActivityIndicatorView.h"
@import PopoverView;


@interface GameTableViewCell : UITableViewCell {
    UILabel *ratingLabel;
}
@property(nonatomic, retain, readwrite) UILabel *ratingLabel;

@end

@interface GamesTableViewController : UIPullToReloadTableViewController <UIGestureRecognizerDelegate, NSURLConnectionDelegate,
                PopoverViewDelegate> {
    PentePlayer *player;
    Game *selectedGame;
    BoardViewController *boardController;
    MessagesViewController *messagesViewController;
    InvitationsViewController *invitationsViewController;
    NSString *username, *password;
    NSIndexPath *selectedInvitationIndexPath, *selectedPublicInvitationIndexPath;
    UIButton *acceptButton, *cancelButton, *rejectButton;
    BOOL messagesCollapsed, invitationsReceivedCollapsed, activeGamesCollapsed, publicInvitationsCollapsed,
    sentInvitationsCollapsed, nonActiveGamesCollapsed, tournamentsCollapsed, kothCollapsed;
    GameTableViewCell *selectedInvitationCell, *selectedPublicInvitationCell;
    BOOL alreadyAskedAboutInvitations;
    int gamesLimit;
    PopoverView *actionPopoverView;
    ICDMaterialActivityIndicatorView *progressView;
    SettingsViewController *settingsViewController;
}
@property(nonatomic,retain) PentePlayer *player;
@property(nonatomic,retain) Game *selectedGame;
@property(nonatomic,retain) BoardViewController *boardController;
@property(nonatomic,retain) MessagesViewController *messagesViewController;
@property(nonatomic,retain) InvitationsViewController *invitationsViewController;
@property(nonatomic,retain) NSString *username;
@property(nonatomic,retain) NSString *password;
@property(nonatomic,retain) NSIndexPath *selectedInvitationIndexPath, *selectedPublicInvitationIndexPath;
@property(nonatomic,retain) UIButton *acceptButton;
@property(nonatomic,retain) UIButton *rejectButton;
@property(nonatomic,retain) UIButton *cancelButton;
@property(atomic) BOOL messagesCollapsed, invitationsReceivedCollapsed, activeGamesCollapsed, publicInvitationsCollapsed,
sentInvitationsCollapsed, nonActiveGamesCollapsed, alreadyAskedAboutInvitations, tournamentsCollapsed, kothCollapsed;
@property(atomic) int gamesLimit;
@property(nonatomic,retain) GameTableViewCell *selectedInvitationCell, *selectedPublicInvitationCell;
@property(nonatomic, retain, readwrite) PopoverView *actionPopoverView;
@property (strong,nonatomic) ICDMaterialActivityIndicatorView *progressView;
@property(nonatomic, retain) SettingsViewController *settingsViewController;

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void) sectionTap:(UIGestureRecognizer *)gestureRecognizer;
//- (void) addSectionTapRecogniser: (UITapGestureRecognizer *) sectionTapRecogniser toSubViewsOf: (UIView *) headerView;
//- (void) headerTapped: (UIButton*) sender;
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
//- (void)adViewWillLeaveApplication:(GADBannerView *)bannerView;
-(void) dashboardParse;
-(void) parseMessages;
-(void) toInvitationsWithPlayer: (NSString *) playerName;


@end


