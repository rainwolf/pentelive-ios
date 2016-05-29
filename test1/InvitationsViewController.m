//
//  InvitationsViewController.m
//  test1
//
//  Created by rainwolf on 31/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "InvitationsViewController.h"
#import "PenteNavigationViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "PopoverView.h"

#define IS_IPHONE_5 ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )

@interface InvitationsViewController ()

@end

@implementation InvitationsViewController
@synthesize games;
@synthesize colors;
@synthesize moveDurations;
@synthesize gameCell;
@synthesize timeCell;
@synthesize opponentCell;
@synthesize ratedSwitch;
@synthesize privateSwitch;
@synthesize playAsCell;
@synthesize playAsLabel;
@synthesize playAsDetailLabel;
@synthesize privateCell;
@synthesize privateCellLabel;
@synthesize spinner;
@synthesize invitationMessageView;
@synthesize messagePopover;
@synthesize invitationMessage;
@synthesize challengedOpponent;
@synthesize game;
@synthesize openInvitationOnly;
@synthesize restrictionCell;
@synthesize restrictions;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (BOOL)shouldAutorotate {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    return ((interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown)
            && (interfaceOrientation != UIInterfaceOrientationLandscapeLeft) && (interfaceOrientation != UIInterfaceOrientationLandscapeRight));
}
-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
    //    return UIInterfaceOrientationLandscapeLeft | UIInterfaceOrientationLandscapeRight | UIInterfaceOrientationPortrait;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    [self setTitle:@"Send invitation"];
    [self.navigationItem setRightBarButtonItem: [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"messageBubble1.png"] style:UIBarButtonItemStylePlain target:self action:@selector(messageTap)]];

    games = [[NSArray alloc] initWithObjects:@"Pente",@"Keryo-Pente",@"Gomoku",@"D-Pente",@"G-Pente",@"Poof-Pente",@"Connect6",@"Boat-Pente", nil];
    colors = [[NSArray alloc] initWithObjects:@"White",@"Black", nil];
    restrictions = [[NSArray alloc] initWithObjects:@"of any rating",@"not already playing",@"of lower rating",@"of higher rating",@"of similar rating",@"in the same rating class", nil];
    moveDurations = [[NSMutableArray alloc] init];
    for ( int i = 1; i < 31; ++i) {
        [moveDurations addObject:[NSString stringWithFormat:@"%i",i]];
    }
    
    invitationMessageView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width - 40, 44)];
    [invitationMessageView setFont:[UIFont systemFontOfSize:15]];
    CGRect frame = invitationMessageView.frame;
    if (IS_IPHONE_5)
        frame.size.height = invitationMessageView.font.lineHeight*13;
    else
        frame.size.height = invitationMessageView.font.lineHeight*8;
    [invitationMessageView setAlpha:0.90];
    [invitationMessageView setEditable:YES];
    invitationMessageView.clipsToBounds = YES;
    invitationMessageView.layer.cornerRadius = 5.0f;
//    invitationMessageView.contentInset = UIEdgeInsetsMake(-7.0,0.0,0,0.0);
    [invitationMessageView setFrame:frame];
    [invitationMessageView setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [invitationMessageView setAutocorrectionType:UITextAutocorrectionTypeNo];
    [invitationMessageView setReturnKeyType:UIReturnKeyDone];
    [invitationMessageView setDelegate:self];
    invitationMessageView.layer.borderWidth = 2.0f;
    invitationMessageView.layer.borderColor = [[UIColor grayColor] CGColor];
    self.invitationMessage = @"";
    opponentCell.textField.text = @"";
    challengedOpponent = @"";
//    game = @"";
    [self.tableView setSeparatorColor:[UIColor blueColor]];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
}

- (void)viewWillDisappear:(BOOL)animated {
    [opponentCell.textField resignFirstResponder];
    [gameCell resign];
    [timeCell resign];
    [playAsCell resign];
    [restrictionCell resign];
    self.invitationMessage = @"";
    opponentCell.textField.text = @"";
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    [navController setChallengedUser:@""];
    challengedOpponent = @"";
    game = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [spinner setHidden:YES];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.tableView setScrollEnabled:NO];
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    [navController setChallengeCancelled:YES];
    self.opponentCell.textField.text = navController.challengedUser;
    
    if (self.openInvitationOnly) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults boolForKey:@"stopGamesLimitHassle"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"New account limit reached." message:@"You cannot accept more games. You can, however, play more games by posting open invitations. \n This limit will gradually increase as you finish more games." delegate:self cancelButtonTitle:@"Got it." otherButtonTitles:@"Do not remind me again.", nil];
            [alert setTag: 0];
            [alert show];
        }

        [self.opponentCell setUserInteractionEnabled:NO];
//        NSLog(@"kitty no");
    } else {
//        NSLog(@"kitty yes");
        [self.opponentCell setUserInteractionEnabled:YES];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    gameCell.datarray = games;
    [gameCell.picker reloadAllComponents];
    
//    NSLog(@"peep 1%@1", game);
    NSString *cellString = [defaults objectForKey:@"lastInvitedGame"];
    if ((game != nil) && ![game isEqualToString:@""]) {
        [gameCell.detailTextLabel setText:game];
    } else if (cellString) {
        [gameCell.detailTextLabel setText:cellString];
    }
    if ([defaults objectForKey:@"lastInvitedTimeLimit"]) {
        [timeCell.detailTextLabel setText:[defaults objectForKey:@"lastInvitedTimeLimit"]];
    }
    if ([defaults objectForKey:@"lastInvitationRestriction"]) {
        [restrictionCell.detailTextLabel setText:[defaults objectForKey:@"lastInvitationRestriction"]];
    }
    [ratedSwitch setOn:![defaults boolForKey:@"lastInvitationRated"] animated:YES];
    if (!ratedSwitch.on) {
        playAsCell.userInteractionEnabled = YES;
        playAsLabel.alpha = 1;
        playAsDetailLabel.alpha = 1;
        privateCell.userInteractionEnabled = YES;
        privateCellLabel.alpha = 1;
        privateSwitch.alpha = 1;
    } else {
        playAsCell.userInteractionEnabled = NO;
        playAsLabel.alpha = 0.5;
        playAsDetailLabel.alpha = 0.5;
        privateCell.userInteractionEnabled = NO;
        privateCellLabel.alpha = 0.5;
        privateSwitch.alpha = 0.5;
        [privateSwitch setOn:NO animated:YES];
    }
    if ([defaults objectForKey:@"lastInvitedColor"]) {
        [playAsCell.detailTextLabel setText:[defaults objectForKey:@"lastInvitedColor"]];
    }
    [privateSwitch setOn:[defaults boolForKey:@"lastInvitationPrivate"]];
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 0) {
        if (buttonIndex == 0) {
//                        NSLog(@"button 0");
        }
        else if (buttonIndex == 1) {
//                        NSLog(@"button 1");
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setBool:YES forKey:@"stopGamesLimitHassle"];
        }
    }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//{
//    // Return the number of sections.
//}
//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//{
//    // Return the number of rows in the section.
//}
//
//- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

//- (BOOL)becomeFirstResponder
//{
//    NSLog(@"kittyResponds");
//    return [super becomeFirstResponder];
//}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    CGFloat tableVisibleHeight = UIScreen.mainScreen.bounds.size.height - self.navigationController.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [gameCell doResign];
            [timeCell doResign];
            [playAsCell doResign];
            [restrictionCell doResign];
            [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
            [tableView deselectRowAtIndexPath:indexPath animated:NO];
//            [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
            [tableView setScrollEnabled:NO];
        }
        if (indexPath.row == 1) {
            [opponentCell.textField resignFirstResponder];
            [timeCell doResign];
            [playAsCell doResign];
            [restrictionCell doResign];
//            [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
            gameCell.datarray = games;
            [gameCell.picker reloadAllComponents];

            NSString *cellString = [defaults objectForKey:@"lastInvitedGame"];
            if (cellString) {
                for(int i = 0; i < [games count]; ++i) {
                    if ([[games objectAtIndex:i] isEqualToString:cellString]) {
                        [gameCell.picker selectRow:i inComponent:0 animated:YES];
                        break;
                    }
                }
            } else {
                [gameCell.picker selectRow: 0 inComponent:0 animated:NO];
            }
            [tableView deselectRowAtIndexPath:indexPath animated:NO];

            [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
            [tableView setScrollEnabled:YES];
        }
        if (indexPath.row == 2) {
            [gameCell doResign];
            [playAsCell doResign];
            [opponentCell.textField resignFirstResponder];
            [restrictionCell doResign];

            timeCell.datarray = moveDurations;
            [timeCell.picker reloadAllComponents];
            
            NSString *cellString = [defaults objectForKey:@"lastInvitedTimeLimit"];
            
            if (cellString) {
                for(int i = 0; i < [moveDurations count]; ++i) {
                    if ([[moveDurations objectAtIndex:i] isEqualToString:cellString]) {
                        [timeCell.picker selectRow:i inComponent:0 animated:YES];
                        break;
                    }
                }
            } else {
                [timeCell.picker selectRow: 6 inComponent:0 animated:NO];
            }
            
            [tableView deselectRowAtIndexPath:indexPath animated:NO];

            [tableView setScrollEnabled:YES];
//            [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
//            CGFloat scrollY = [tableView rectForRowAtIndexPath:indexPath].origin.y + [tableView rectForRowAtIndexPath:indexPath].size.height;
            CGFloat scrollY = [tableView rectForRowAtIndexPath:indexPath].origin.y;
            [tableView scrollRectToVisible:CGRectMake(0, scrollY, 1, 1) animated:YES];
        }
        if (indexPath.row == 3) {
            [opponentCell.textField resignFirstResponder];
            [gameCell doResign];
            [timeCell doResign];
            [playAsCell doResign];
            [restrictionCell doResign];
            
            [ratedSwitch setOn: !ratedSwitch.on animated:YES];
            [self flipRatedSwitch:self];
            [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
            [tableView setScrollEnabled:NO];
        }
        if (indexPath.row == 4) {
            [opponentCell.textField resignFirstResponder];
            [gameCell doResign];
            [timeCell doResign];
            [playAsCell doResign];
            restrictionCell.datarray = restrictions;
            [restrictionCell.picker reloadAllComponents];
            [restrictionCell.picker selectRow: 0 inComponent:0 animated:YES];
            
            [tableView setScrollEnabled:YES];
            CGFloat scrollY = [tableView rectForRowAtIndexPath:indexPath].origin.y;
            [tableView scrollRectToVisible:CGRectMake(0, scrollY, 1, 1) animated:YES];
        }
        if (indexPath.row == 5) {
            [opponentCell.textField resignFirstResponder];
            [gameCell doResign];
            [timeCell doResign];
            [restrictionCell doResign];
            
            playAsCell.datarray = colors;
            [playAsCell.picker reloadAllComponents];
            [playAsCell.picker selectRow: ([playAsCell.detailTextLabel.text isEqualToString:@"White"] ? 0 : 1) inComponent:0 animated:YES];
            
            [tableView setScrollEnabled:YES];
            CGFloat scrollY = [tableView rectForRowAtIndexPath:indexPath].origin.y;
            [tableView scrollRectToVisible:CGRectMake(0, scrollY, 1, 1) animated:YES];
        }
        if (indexPath.row == 6) {
            [opponentCell.textField resignFirstResponder];
            [gameCell doResign];
            [timeCell doResign];
            [playAsCell doResign];
            [restrictionCell doResign];

            [privateSwitch setOn: !privateSwitch.on animated:YES];
            [self flipPrivateSwitch:self];
            [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
            [tableView setScrollEnabled:NO];
        }
    }
    if (indexPath.section == 1) {
        
        [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        [tableView setScrollEnabled:NO];
        [opponentCell.textField resignFirstResponder];
        [gameCell doResign];
        [timeCell doResign];
        [playAsCell doResign];
        [restrictionCell doResign];

        [spinner setHidden:NO];
        [spinner startAnimating];
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
        [NSThread detachNewThreadSelector:@selector(submitInvitation) toTarget:self withObject:nil];
    }
}


-(void) submitInvitation {
    
//    NSLog(@"testkitty %@, %@, %@, %@", opponentCell.detailTextLabel.text, gameCell.detailTextLabel.text, timeCell.detailTextLabel.text , (ratedSwitch.on) ? @"YES" : @"NO");
    
    NSString *gameString;
    if ([gameCell.detailTextLabel.text isEqualToString:@"Pente"])
        gameString = @"51";
    if ([gameCell.detailTextLabel.text isEqualToString:@"Gomoku"])
        gameString = @"55";
    if ([gameCell.detailTextLabel.text isEqualToString:@"D-Pente"])
        gameString = @"57";
    if ([gameCell.detailTextLabel.text isEqualToString:@"G-Pente"])
        gameString = @"59";
    if ([gameCell.detailTextLabel.text isEqualToString:@"Boat-Pente"])
        gameString = @"65";
    if ([gameCell.detailTextLabel.text isEqualToString:@"Poof-Pente"])
        gameString = @"61";
    if ([gameCell.detailTextLabel.text isEqualToString:@"Connect6"])
        gameString = @"63";
    if ([gameCell.detailTextLabel.text isEqualToString:@"Keryo-Pente"])
        gameString = @"53";
    
    NSString *restrictString = @"A";
    if ([restrictionCell.detailTextLabel.text isEqualToString:@"of any rating"]) {
        restrictString = @"A";
    }
    if ([restrictionCell.detailTextLabel.text isEqualToString:@"not already playing"]) {
        restrictString = @"N";
    }
    if ([restrictionCell.detailTextLabel.text isEqualToString:@"of lower rating"]) {
        restrictString = @"L";
    }
    if ([restrictionCell.detailTextLabel.text isEqualToString:@"of higher rating"]) {
        restrictString = @"H";
    }
    if ([restrictionCell.detailTextLabel.text isEqualToString:@"of similar rating"]) {
        restrictString = @"S";
    }
    if ([restrictionCell.detailTextLabel.text isEqualToString:@"of same rating class"]) {
        restrictString = @"C";
    }
    
    if (opponentCell.textField.text.length == 0) {
        long openInvitationsLimit = [[NSUserDefaults standardUserDefaults] integerForKey:@"openInvitationsLimit"];
        openInvitationsLimit += 2;
        [[NSUserDefaults standardUserDefaults] setInteger: openInvitationsLimit forKey:@"openInvitationsLimit"];
//            [[NSUserDefaults standardUserDefaults] setInteger: 3 forKey:@"openInvitationsLimit"];
    }
    
//    NSLog(@"kitty hi? %@", opponentCell.textField.text);
    NSString *post = [NSString stringWithFormat:@"invitationRestriction=%@&invitee=%@&game=%@&daysPerMove=%@&rated=%@&playAs=%@&privateGame=%@&inviterMessage=%@&mobile=", restrictString, opponentCell.textField.text ,gameString,timeCell.detailTextLabel.text,(ratedSwitch.on) ? @"Y" : @"N",([playAsDetailLabel.text isEqualToString:@"White"]) ? @"1" : @"2",(privateSwitch.on) ? @"Y" : @"N",[self URLEncodedString_ch: invitationMessage]];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:@"https://www.pente.org/gameServer/tb/newGame"]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    NSURLResponse *response;
    NSError *error;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    
    [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];

    if ([dashboardString rangeOfString:[NSString stringWithFormat:@"Player not found: %@",opponentCell.textField.text]].length != 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"The username %@ does not exist.", opponentCell.textField.text] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
    } else {
        PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
        [navController setDidMove: YES];
        [navController setChallengeCancelled: YES];

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([opponentCell.textField.text length] > 0) {
            NSString *opponent = [opponentCell.textField.text lowercaseString];
            NSMutableArray *invitedHistory =  [[defaults objectForKey:@"invitedHistory"] mutableCopy];
            if (invitedHistory) {
                int i = 0;
                for ( i = 0; i < [invitedHistory count]; ++i) {
                    if ([[invitedHistory objectAtIndex:i] localizedCaseInsensitiveCompare:opponentCell.textField.text] == NSOrderedDescending)
                        break;
                }
                if (![invitedHistory containsObject:opponent]) {
                    [invitedHistory insertObject:opponent atIndex:i];
                }
            } else {
                invitedHistory = [NSMutableArray arrayWithObject:opponent];
            }
            [defaults setObject:invitedHistory forKey:@"invitedHistory"];
            [opponentCell setInvitedHistory:invitedHistory];
        }
        [defaults setObject:gameCell.detailTextLabel.text forKey:@"lastInvitedGame"];
        [defaults setObject:restrictionCell.detailTextLabel.text forKey:@"lastInvitationRestriction"];
        [defaults setObject:timeCell.detailTextLabel.text forKey:@"lastInvitedTimeLimit"];
        [defaults setBool:!ratedSwitch.on forKey:@"lastInvitationRated"];
        [defaults setObject:playAsCell.detailTextLabel.text forKey:@"lastInvitedColor"];
        [defaults setBool:privateSwitch.on forKey:@"lastInvitationPrivate"];

//        [navController popToRootViewControllerAnimated:YES];
        [navController popViewControllerAnimated:YES];
    }
}



//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//}




- (void)viewDidUnload {
    [self setRatedSwitch:nil];
    [self setSendCell:nil];
    [self setTimeCell:nil];
    [self setGameCell:nil];
    [self setRestrictionCell:nil];
    [self setOpponentCell:nil];
    [self setPrivateSwitch:nil];
    [self setPlayAsCell:nil];
    [self setPrivateCell:nil];
    [self setPrivateCellLabel:nil];
    [self setPlayAsLabel:nil];
    [self setPlayAsDetailLabel:nil];
    [self setPrivateSwitch:nil];
    [self setPrivateCellLabel:nil];
    [self setPrivateCellLabel:nil];
    [self setSpinner:nil];
    [super viewDidUnload];
}


- (IBAction)flipPrivateSwitch:(id)sender {
    [self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    [self.tableView setScrollEnabled:NO];
    [opponentCell.textField resignFirstResponder];
    [gameCell doResign];
    [timeCell doResign];
    [playAsCell doResign];
    [restrictionCell doResign];
}

- (IBAction)flipRatedSwitch:(id)sender {
    [self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    [self.tableView setScrollEnabled:NO];
    if (!ratedSwitch.on) {
        playAsCell.userInteractionEnabled = YES;
        playAsLabel.alpha = 1;
        playAsDetailLabel.alpha = 1;
        privateCell.userInteractionEnabled = YES;
        privateCellLabel.alpha = 1;
        privateSwitch.alpha = 1;
    } else {
        playAsCell.userInteractionEnabled = NO;
        playAsLabel.alpha = 0.5;
        playAsDetailLabel.alpha = 0.5;
        privateCell.userInteractionEnabled = NO;
        privateCellLabel.alpha = 0.5;
        privateSwitch.alpha = 0.5;
        [privateSwitch setOn:NO animated:YES];
    }
    [opponentCell.textField resignFirstResponder];
    [self.gameCell doResign];
    [timeCell doResign];
    [playAsCell doResign];
    [restrictionCell doResign];
}

- (NSString *) URLEncodedString_ch: (NSString *) input{
    NSMutableString * output = [NSMutableString string];
    const unsigned char * source = (const unsigned char *)[input UTF8String];
    int sourceLen = (int) strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}



-(void) messageTap {
    messagePopover = [[PopoverView alloc] init];
    [messagePopover setDelegate:self];
    
    [messagePopover showAtPoint:CGPointMake(self.view.frame.size.width, 0) inView:self.view withContentView:self.invitationMessageView];
    [invitationMessageView becomeFirstResponder];
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
{
    if ([text isEqualToString:@"\n"] ) {
        invitationMessage = invitationMessageView.text;
        [messagePopover dismiss];
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    invitationMessage = invitationMessageView.text;
}



@end
