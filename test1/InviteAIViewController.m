//
//  InvitationsViewController.m
//  test1
//
//  Created by rainwolf on 31/12/12.
//  Copyright (c) 2012 Triade. All rights reserved.
//

#import "InviteAIViewController.h"
#import "PenteNavigationViewController.h"
#import <QuartzCore/QuartzCore.h>

#define IS_IPHONE_5 ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )


@implementation InviteAIViewController
@synthesize games;
@synthesize colors;
@synthesize difficulties;
@synthesize gameCell;
@synthesize opponentCell;
@synthesize ratedSwitch;
@synthesize playAsCell;
@synthesize ratedCell;
@synthesize playAsLabel;
@synthesize playAsDetailLabel;
@synthesize spinner;
@synthesize game;
@synthesize openInvitationOnly;
@synthesize sendLabel;

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
    [self setTitle:NSLocalizedString(@"Invite the AI",nil)];

//    games = [[NSArray alloc] initWithObjects:@"Pente",@"Keryo-Pente",@"Gomoku",@"D-Pente",@"G-Pente",@"Poof-Pente",@"Connect6",@"Boat-Pente", nil];
//    games = [[NSMutableArray alloc] initWithObjects:@"Pente",@"Gomoku", nil];
    games = [[NSMutableArray alloc] initWithObjects:@"Pente", nil];
    colors = [[NSMutableArray alloc] initWithObjects:NSLocalizedString(@"white",nil),NSLocalizedString(@"black",nil), nil];
    difficulties = [[NSMutableArray alloc] init];
    for ( int i = 1; i < 10; ++i) {
        [difficulties addObject:[NSString stringWithFormat:@"%i",i]];
    }
    
    [self.tableView setSeparatorColor:[UIColor blueColor]];
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleSingleLine];
    
    opponentCell.textLabel.text = NSLocalizedString(@"Difficulty:", nil);
    gameCell.textLabel.text = NSLocalizedString(@"Game:", nil);
    ratedCell.textLabel.text = NSLocalizedString(@"Play as white and black", nil);
    sendLabel.text = NSLocalizedString(@"Play the computer", nil);

    [self.tableView setContentInset:UIEdgeInsetsMake(-20, 0, 0, 0)];
}

- (void)viewWillDisappear:(BOOL)animated {
    [opponentCell resign];
    [gameCell resign];
    [playAsCell resign];
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    [navController setChallengedUser:@""];
    game = nil;
    [super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated {
    [spinner setHidden:YES];
//    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.tableView setScrollEnabled:NO];
//    [self.tableView setFrame:self.view.frame];
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    [navController setChallengeCancelled:YES];
    
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    gameCell.datarray = games;
    [gameCell.picker reloadAllComponents];
    
//    NSLog(@"peep 1%@1", game);
    NSString *cellString = [defaults objectForKey:@"lastInvitedAIGame"];
    if ((game != nil) && ![game isEqualToString:@""]) {
        [gameCell.detailTextLabel setText:game];
    } else if (cellString) {
        [gameCell.detailTextLabel setText:cellString];
    }
    cellString = [defaults objectForKey:@"lastInvitedAIdifficulty"];
    if (cellString) {
        [opponentCell.detailTextLabel setText:cellString];
    }
//    if ([defaults objectForKey:@"lastInvitedTimeLimit"]) {
//        [timeCell.detailTextLabel setText:[defaults objectForKey:@"lastInvitedTimeLimit"]];
//    }
//    [ratedSwitch setOn:![defaults boolForKey:@"lastInvitationRated"] animated:YES];
    if (!ratedSwitch.on) {
        playAsCell.userInteractionEnabled = YES;
        playAsLabel.alpha = 1;
        playAsDetailLabel.alpha = 1;
    } else {
        playAsCell.userInteractionEnabled = NO;
        playAsLabel.alpha = 0.5;
        playAsDetailLabel.alpha = 0.5;
    }
//    if ([defaults objectForKey:@"lastInvitedColor"]) {
//        [playAsCell.detailTextLabel setText:[defaults objectForKey:@"lastInvitedColor"]];
//    }
    [super viewDidAppear:animated];
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
        int row = 0;
        if (indexPath.row == row) {
            [opponentCell resign];
            [playAsCell doResign];
//            [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
            gameCell.datarray = games;
            [gameCell.picker reloadAllComponents];

            NSString *cellString = [defaults objectForKey:@"lastInvitedAIGame"];
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

//            [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:NO];
//            [tableView setScrollEnabled:YES];
        }
        ++row;
        if (indexPath.row == row) {
            [gameCell doResign];
            [playAsCell doResign];
            opponentCell.datarray = difficulties;
            [opponentCell.picker reloadAllComponents];
            
//            [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
            [tableView deselectRowAtIndexPath:indexPath animated:NO];
            //            [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
//            [tableView setScrollEnabled:NO];
        }
        ++row;
        if (indexPath.row == row) {
            [opponentCell resign];
            [gameCell doResign];
            [playAsCell doResign];
            
            [ratedSwitch setOn: !ratedSwitch.on animated:YES];
            [self flipRatedSwitch:self];
//            [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
//            [tableView setScrollEnabled:NO];
        }
        ++row;
        if (indexPath.row == row) {
            [opponentCell resign];
            [gameCell doResign];
            
            playAsCell.datarray = colors;
            [playAsCell.picker reloadAllComponents];
            [playAsCell.picker selectRow: ([playAsCell.detailTextLabel.text isEqualToString:NSLocalizedString(@"White",nil)] ? 0 : 1) inComponent:0 animated:YES];
            
//            [tableView setScrollEnabled:YES];
//            CGFloat scrollY = [tableView rectForRowAtIndexPath:indexPath].origin.y;
//            [tableView scrollRectToVisible:CGRectMake(0, scrollY, 1, 1) animated:YES];
        }
    }
    if (indexPath.section == 1) {
        
//        [tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
//        [tableView setScrollEnabled:NO];
        [opponentCell resign];
        [gameCell doResign];
        [playAsCell doResign];

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
    
    
//    NSLog(@"kitty hi? %@", opponentCell.textField.text);
    NSString *post = [NSString stringWithFormat:@"invitee=computer&game=%@&difficulty=%@&daysPerMove=30&rated=%@&playAs=%@&privateGame=N&mobile=", gameString, opponentCell.detailTextLabel.text, (ratedSwitch.on) ? @"Y" : @"N",([playAsDetailLabel.text isEqualToString:NSLocalizedString(@"white",nil)]) ? @"1" : @"2"];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    if (development) {
        [request setURL:[NSURL URLWithString:@"https://development.pente.org/gameServer/tb/newGame"]];
    } else {
        [request setURL:[NSURL URLWithString:@"https://www.pente.org/gameServer/tb/newGame"]];
    }
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    NSURLResponse *response;
    NSError *error;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:gameCell.detailTextLabel.text forKey:@"lastInvitedAIGame"];
        [defaults setObject:opponentCell.detailTextLabel.text forKey:@"lastInvitedAIdifficulty"];

        if (error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:[NSString stringWithFormat:NSLocalizedString(@"Reason: %@",nil), error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            //        [alert show];
            [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
            return;
        } else if ([dashboardString rangeOfString:@"against the AI player. You can start a new one after finishing the current one."].location != NSNotFound) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error",nil) message:NSLocalizedString(@"The AI player will only play 1 game or set of each game at a time.",nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK",nil) otherButtonTitles:nil];
            [alert show];

        } else {
            PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
            [navController setDidMove: YES];
            [navController setChallengeCancelled: YES];
            
            //        [navController popToRootViewControllerAnimated:YES];
            [navController popViewControllerAnimated:YES];
        }
    });
}

//-(void) showError: (NSError *) error {
//    
//}

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{
//}




- (void)viewDidUnload {
    [self setRatedSwitch:nil];
    [self setGameCell:nil];
    [self setOpponentCell:nil];
    [self setPlayAsCell:nil];
    [self setPlayAsLabel:nil];
    [self setPlayAsDetailLabel:nil];
    [self setSpinner:nil];
    [super viewDidUnload];
}



- (IBAction)flipRatedSwitch:(id)sender {
    [self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    [self.tableView setScrollEnabled:NO];
    if (!ratedSwitch.on) {
        playAsCell.userInteractionEnabled = YES;
        playAsLabel.alpha = 1;
        playAsDetailLabel.alpha = 1;
    } else {
        playAsCell.userInteractionEnabled = NO;
        playAsLabel.alpha = 0.5;
        playAsDetailLabel.alpha = 0.5;
    }
    [opponentCell doResign];
    [self.gameCell doResign];
    [playAsCell doResign];
}







@end
