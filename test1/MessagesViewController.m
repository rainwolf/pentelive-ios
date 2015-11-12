//
//  MessagesViewController.m
//  penteLive
//
//  Created by rainwolf on 17/03/13.
//  Copyright (c) 2013 Triade. All rights reserved.
//

#import "MessagesViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "InvitationsViewController.h"

#define IS_IPHONE_5 ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )
#define usernameKey @"username"
#define passwordKey @"password"


@interface MessagesViewController ()

@end

@implementation MessagesViewController
@synthesize messageID;
@synthesize author;
@synthesize subject;
@synthesize receivedMessageView, replyMessageView;
@synthesize sendButton;
@synthesize subjectField;
@synthesize toField;
@synthesize spinner;
@synthesize toHistory;
@synthesize bannerView;
@synthesize player;
@synthesize gamesLimit;
@synthesize showAds;
@synthesize boardController;

InvitationsViewController *invitationVC;



- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

//- (BOOL)shouldAutorotate {
//    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
//    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
//}
//-(NSUInteger)supportedInterfaceOrientations {
//        return UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight | UIInterfaceOrientationMaskPortrait;
//}


-(void) viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide) name:UIKeyboardWillHideNotification object:nil];
    
    
    [super viewWillAppear:animated];
}

-(void) viewDidAppear:(BOOL)animated {
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    [navController setDelegate:self];
    if (navController.challengeCancelled) {
        [self setMessageID:navController.unchallengedMessageID];
        [self setTitle: author];
        if ([subject length] > 3) {
            [subjectField setText: ([[subject substringWithRange:NSMakeRange(0, 4)] isEqualToString:@"Re: "]) ? subject : [@"Re: " stringByAppendingString:subject]];
        } else {
            [subjectField setText: [@"Re: " stringByAppendingString:subject]];
        }
        [self.view addSubview:subjectField];
        [self.view addSubview:receivedMessageView];
        [self.view addSubview:replyMessageView];
        [self.view addSubview:sendButton];
        if (showAds) {
            [self.view addSubview:bannerView];
        }
        return;
    }

    [UIView animateWithDuration:0.3f animations:^ {
        if (messageID) {
            [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects: [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"trash"] style:UIBarButtonItemStylePlain target:self action:@selector(deleteMessageTap)], [[UIBarButtonItem alloc] initWithTitle:@"Play?" style:UIBarButtonItemStylePlain target:self action:@selector(challengeTap)], nil]];
        } else {
            [self.navigationItem setRightBarButtonItem:nil];
            [self.navigationItem setRightBarButtonItems:nil];
        }
    }];
    if (showAds) {
        PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
        bannerView = navControllor.bannerView;
        bannerView.rootViewController = self;
        [bannerView setDelegate:self];
        CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
        CGFloat newOriginY = screenHeight - navControllor.navigationBar.frame.size.height - [UIApplication sharedApplication].statusBarFrame.size.height - bannerView.frame.size.height;
        CGRect newBannerViewFrame = CGRectMake(bannerView.frame.origin.x, newOriginY, bannerView.frame.size.width, bannerView.frame.size.height);
        bannerView.frame = newBannerViewFrame;
        [self.view addSubview:bannerView];
    }
    

    if (showAds) {
        [sendButton setFrame:CGRectMake(4, self.view.bounds.size.height - 47 - bannerView.frame.size.height, self.view.bounds.size.width - 8, 44)];
    } else {
        [sendButton setFrame:CGRectMake(4, self.view.bounds.size.height - 47, self.view.bounds.size.width - 8, 44)];
    }

    [spinner setHidden:YES];
    [sendButton addSubview:spinner];
    [spinner setHidesWhenStopped:YES];
    
    float halfScreenSize = (self.view.frame.size.height - subjectField.frame.size.height - subjectField.frame.origin.y - sendButton.frame.size.height - 9)/2;
    if (messageID) {
        [self setTitle: author];
        
        if ([subject length] > 3) {
            [subjectField setText: ([[subject substringWithRange:NSMakeRange(0, 4)] isEqualToString:@"Re: "]) ? subject : [@"Re: " stringByAppendingString:subject]];
        } else {
            [subjectField setText: [@"Re: " stringByAppendingString:subject]];
        }
        [self.view addSubview:subjectField];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        NSString *url;
        NSURLResponse *response;
        NSError *error;
        NSData *responseData;
        
        // load the message
        url = [NSString stringWithFormat:@"http://www.pente.org/gameServer/mymessages?command=view&mid=%@", messageID];
        [request setURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"GET"];
        [request setTimeoutInterval:7.0];
        responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        NSRange tmpRange = [dashboardString rangeOfString:@"        <br>\r\n          "];
        int myTurnStart = (int) tmpRange.location + (int) tmpRange.length;
        NSRange msgRange = [dashboardString rangeOfString:@"          <br><br>"];
        msgRange = NSMakeRange(myTurnStart, msgRange.location - myTurnStart - 2);
        
        NSString *tmpText = [[dashboardString substringWithRange: msgRange] stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
        
        NSString *receivedText = [self stripURL: [self replaceWithSmileys: tmpText]];
        
        NSDictionary *fontAttributes = [NSDictionary dictionaryWithObject:[receivedMessageView font] forKey:NSFontAttributeName];
        [self.view addSubview:receivedMessageView];
        CGRect textFrame = [receivedText boundingRectWithSize:CGSizeMake(receivedMessageView.contentSize.width + receivedMessageView.contentOffset.x - receivedMessageView.contentInset.left - receivedMessageView.contentInset.right, halfScreenSize) options:NSStringDrawingUsesLineFragmentOrigin attributes:fontAttributes context:nil];
        [receivedMessageView setText: receivedText];
        CGFloat fontLineHeight = [[receivedMessageView font] lineHeight];
        

        [UIView animateWithDuration:0.3f animations:^ {
            CGRect frame = subjectField.frame;
            frame = subjectField.frame;
            frame.origin.y = 2;
            [subjectField setFrame:frame];
            frame = receivedMessageView.frame;
            if ((textFrame.size.height - receivedMessageView.contentInset.top - receivedMessageView.contentInset.bottom + receivedMessageView.contentOffset.y + fontLineHeight) < halfScreenSize) {
//                NSLog(@"kitty %f %f %f", textFrame.size.height,(receivedMessageView.contentSize.height - receivedMessageView.contentInset.top - receivedMessageView.contentInset.bottom), halfScreenSize);
                frame.size.height = textFrame.size.height - receivedMessageView.contentInset.top - receivedMessageView.contentInset.bottom + receivedMessageView.contentOffset.y + fontLineHeight;
            } else {
                frame.size.height = halfScreenSize;
            }
            frame.origin.y = subjectField.frame.origin.y + subjectField.frame.size.height;
            [receivedMessageView setFrame:frame];
//            [sendButton setFrame:CGRectMake(2, bannerView.frame.origin.y - 42, self.view.bounds.size.width - 4, 40)];
            [replyMessageView setFrame:CGRectMake(3, receivedMessageView.frame.origin.y + receivedMessageView.frame.size.height + 3, self.view.bounds.size.width - 6, sendButton.frame.origin.y - receivedMessageView.frame.origin.y - receivedMessageView.frame.size.height - 6)];
        }];
    } else {
        [self setTitle: @"new message"];
        
        [toField setFrame:CGRectMake(3, 3, self.view.bounds.size.width - 6, 30)];
        self.toField.textColor = [UIColor blueColor];
        [self.view addSubview:toField];
        
        [subjectField setFrame:CGRectMake(3, toField.frame.origin.y + toField.frame.size.height + 3, self.view.bounds.size.width - 6, 30)];
        [self.view addSubview:subjectField];
        
        [replyMessageView setFrame:CGRectMake(3, subjectField.frame.origin.y + subjectField.frame.size.height + 3, self.view.bounds.size.width - 6, 44)];
        CGRect frame = replyMessageView.frame;
        frame.size.height = sendButton.frame.origin.y - subjectField.frame.origin.y - subjectField.frame.size.height - 6;
        [replyMessageView setFrame:frame];
        [self.view addSubview:replyMessageView];

        if ([navController needHelp]) {
            [navController setNeedHelp:NO];
            [toField setText:@"rainwolf"];
            [subjectField setText:[NSString stringWithFormat:@"penteLive help for %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"username"]]];
        }
        
//        [replyMessageView setFrame:CGRectMake(5, 5, self.view.bounds.size.width - 10, 44)];
    }
}

-(void) viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [receivedMessageView removeFromSuperview];
    [replyMessageView removeFromSuperview];
    [subjectField removeFromSuperview];
    [sendButton removeFromSuperview];
    [spinner removeFromSuperview];
    [toField removeFromSuperview];
    messageID = nil;
    [bannerView removeFromSuperview];
    [super viewDidDisappear:animated];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.

    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"preferencesBG.png"]];
    
    toField = [[HTAutocompleteTextField alloc] initWithFrame:CGRectMake(2, -32, self.view.frame.size.width - 4, 30)];
    [toField setBackgroundColor:[UIColor whiteColor]];
    [toField setFont:[UIFont systemFontOfSize:15]];
    [toField setTextAlignment:NSTextAlignmentLeft];
    [toField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    toField.layer.borderWidth = 1.0f;
    toField.layer.borderColor = [[UIColor grayColor] CGColor];
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 20)];
    self.toField.leftView             = paddingView;
    self.toField.leftViewMode         = UITextFieldViewModeAlways;
    paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    self.toField.rightView             = paddingView;
    self.toField.rightViewMode         = UITextFieldViewModeAlways;
    UILabel *tmpLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 40, 20)];
    [tmpLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.f]];
    [tmpLabel setText:@"To: "];
    [self.toField addSubview:tmpLabel];
    [toField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [toField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [toField setReturnKeyType:UIReturnKeyDone];
    [toField setDelegate:self];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.toHistory = [defaults objectForKey:@"invitedHistory"];
    [self.toField setAutocompleteDataSource:self];

    subjectField = [[UITextField alloc] initWithFrame:CGRectMake(2, toField.frame.origin.y - 32, self.view.frame.size.width - 4, 30)];
    [subjectField setBackgroundColor:[UIColor whiteColor]];
    [subjectField setFont:[UIFont systemFontOfSize:15]];
    [subjectField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    subjectField.layer.borderWidth = 1.0f;
    subjectField.layer.borderColor = [[UIColor grayColor] CGColor];
    paddingView           = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 75, 20)];
    tmpLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 75, 20)];
    [tmpLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.f]];
    [tmpLabel setText:@"Subject: "];
    [self.subjectField addSubview:tmpLabel];
    self.subjectField.leftView             = paddingView;
    self.subjectField.leftViewMode         = UITextFieldViewModeAlways;
//    [subjectField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
//    [subjectField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [subjectField setReturnKeyType:UIReturnKeyDone];
    [subjectField setDelegate:self];
    
    
    receivedMessageView = [[UITextView alloc] initWithFrame:CGRectMake(2, subjectField.frame.origin.y -46, self.view.bounds.size.width - 4, 44)];
    [receivedMessageView setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.f]];
    //    NSLog(@"kitty history %@", messagesHistory);
    [receivedMessageView setEditable:NO];
    [receivedMessageView setAlpha:0.90];
    [receivedMessageView setBackgroundColor:[UIColor colorWithRed:0.98f green:0.98f blue:0.98f alpha:0.95]];
    receivedMessageView.clipsToBounds = YES;
    receivedMessageView.layer.cornerRadius = 1.0f;
    receivedMessageView.layer.borderWidth = 1.0f;
    receivedMessageView.layer.borderColor = [[UIColor grayColor] CGColor];
    //    receivedMessageView.contentInset = UIEdgeInsetsMake(7.0,7.0,0,0.0);
    [receivedMessageView setDataDetectorTypes:UIDataDetectorTypeLink];
    [receivedMessageView setUserInteractionEnabled:YES];
    receivedMessageView.contentInset = UIEdgeInsetsMake(-5.0,0.0,0,0.0);
    [receivedMessageView setDelegate:self];
    
    replyMessageView = [[UITextView alloc] initWithFrame:CGRectMake(5, receivedMessageView.frame.origin.y - 49, self.view.bounds.size.width - 10, 44)];
    [replyMessageView setFont:[UIFont systemFontOfSize:15]];
    CGRect frame = replyMessageView.frame;
    [replyMessageView setAlpha:0.90];
    [replyMessageView setEditable:YES];
    replyMessageView.clipsToBounds = YES;
    replyMessageView.layer.cornerRadius = 4.0f;
//    replyMessageView.contentInset = UIEdgeInsetsMake(-5.0,5.0,5,5.0);
    [replyMessageView setTextContainerInset:UIEdgeInsetsMake(5, 5, 5, 5)];
    [replyMessageView setFrame:frame];
    [replyMessageView setAutocapitalizationType:UITextAutocapitalizationTypeSentences];
//    [replyMessageView setAutocorrectionType:UITextAutocorrectionTypeNo];
    [replyMessageView setReturnKeyType:UIReturnKeyDone];
    [replyMessageView setDelegate:self];
    replyMessageView.layer.borderWidth = 1.5f;
    replyMessageView.layer.borderColor = [[UIColor grayColor] CGColor];
    
    //    sendButton = [[UIButton alloc] initWithFrame:CGRectMake(10, self.view.bounds.size.height - 44, self.view.bounds.size.width - 20, 40)];
    sendButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    sendButton.backgroundColor = [UIColor whiteColor];
    sendButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:17.f];
    [sendButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [sendButton addTarget:self action:@selector(sendButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [sendButton setTitle:@"send" forState:UIControlStateNormal];
    [sendButton setFrame:CGRectMake(2, replyMessageView.frame.origin.y - 40, self.view.bounds.size.width , 40)];
    sendButton.layer.borderWidth = 1.5f;
    sendButton.layer.borderColor = [[UIColor blueColor] CGColor];
    sendButton.layer.cornerRadius = 4.0f;
    
    spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.color = [UIColor blueColor];
    
    [self.view addSubview:toField];
    [self.view addSubview:subjectField];
    [self.view addSubview:receivedMessageView];
    [self.view addSubview:replyMessageView];
    [self.view addSubview:sendButton];
}


-(void) sendButtonTap: (UIButton *) sender {
    if (!messageID && ([toField.text length] == 0)) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No recipient entered." message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    if ([subjectField.text length] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No subject entered." message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    if ([replyMessageView.text length] == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No message found." message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    spinner.center = CGPointMake(sendButton.frame.size.width/4, sendButton.frame.size.height/2);
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(sendMessage:) toTarget:self withObject:replyMessageView.text];
}

-(void) sendMessage: (NSString *) replyMessage {
    if (!messageID) {
        author = toField.text;
        subject = subjectField.text;
    }
    NSString *post = [NSString stringWithFormat:@"command=create&to=%@&subject=%@&body=%@&mobile=", author, [self URLEncodedString_ch: subject], [self URLEncodedString_ch: replyMessage]];
    //    NSLog(@"kitty %@", post);
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:@"http://www.pente.org/gameServer/mymessages"]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    NSURLResponse *response;
    NSError *error;
//    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//    NSLog(@"kitty %@", dashboardString);

    if ([dashboardString rangeOfString:[NSString stringWithFormat:@"Error: Player %@ not found.",toField.text]].length != 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"The username %@ does not exist.", toField.text] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//        [alert show];
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
    } else {
        if ([toField.text length] > 0) {
            NSString *opponent = [toField.text lowercaseString];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            toHistory = [defaults objectForKey:@"invitedHistory"];
            if (toHistory) {
                int i = 0;
                for ( i = 0; i < [toHistory count]; ++i) {
                    if ([[toHistory objectAtIndex:i] localizedCaseInsensitiveCompare:toField.text] == NSOrderedDescending)
                        break;
                }
                if (![toHistory containsObject:opponent]) {
                    [toHistory insertObject:opponent atIndex:i];
                }
            } else {
                toHistory = [NSMutableArray arrayWithObject:opponent];
            }
            [defaults setObject:toHistory forKey:@"invitedHistory"];
        }
        [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
        [self.navigationController performSelectorOnMainThread:@selector(popToRootViewControllerAnimated:) withObject:nil waitUntilDone:NO];
    }
    [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
}


- (void) deleteMessageTap {
    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
    [navControllor setMessageDeleted:YES];
    spinner.center = CGPointMake(sendButton.frame.size.width/4, sendButton.frame.size.height/2);
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(deleteMessage) toTarget:self withObject:nil];
}


- (void) deleteMessage {
//    self.view.layer.borderWidth = 1.5;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *username = [defaults objectForKey:usernameKey];
    NSString *password = [defaults objectForKey:passwordKey];
    
    NSString *post = [NSString stringWithFormat:@"command=delete&mid=%@&name2=%@&password2=%@&mobile=", messageID,username,password];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    [request setURL:[NSURL URLWithString:@"http://pente.org/gameServer/mymessages"]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    
    [request setHTTPShouldUsePipelining: YES];
    
    NSURLResponse *response;
    NSError *error;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

    
    //        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    //        NSString *dashboardString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    //        //        [self login];
    //        NSLog(@"kitty %@", dashboardString);
    
    [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
    [self.navigationController performSelectorOnMainThread:@selector(popToRootViewControllerAnimated:) withObject:nil waitUntilDone:NO];
}



- (void) challengeTap {
    long count = [[player activeGames] count] + [[player nonActiveGames] count];
    for (Game *game in [player sentInvitations]) {
        if ([[game opponentName] isEqualToString:@"Anyone"]) {
            continue;
        }
        if ([[game ratedNot] isEqualToString:@"rated"]) {
            count += 2;
        } else {
            ++count;
        }
    }
    if (count > gamesLimit) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults boolForKey:@"stopGamesLimitHassle"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Free account limit reached." message:@"You can only post open invitations until the number of (non-)active games drops below the limit.\n To remove this limit, log in at pente.org and upgrade your account." delegate:self cancelButtonTitle:@"Got it." otherButtonTitles:@"Do not remind me again.", nil];
            [alert setTag: 0];
            [alert show];
        }
        return;
    }
    PenteNavigationViewController *navControllor = (PenteNavigationViewController *) self.navigationController;
    [navControllor setDidMove: YES];
    spinner.center = CGPointMake(sendButton.frame.size.width/4, sendButton.frame.size.height/2);
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(challenge) toTarget:self withObject:nil];
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



- (void) challenge {
    //    self.view.layer.borderWidth = 1.5;
    [spinner performSelectorOnMainThread:@selector(stopAnimating) withObject:nil waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(performChallengeSegue) withObject:nil waitUntilDone:NO];

//    [self.navigationController performSelectorOnMainThread:@selector(popToRootViewControllerAnimated:) withObject:nil waitUntilDone:YES];
}

-(void) performChallengeSegue {
    [self performSegueWithIdentifier:@"challengeSegue" sender:self];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    PenteNavigationViewController *navController = (PenteNavigationViewController *) self.navigationController;
    if([segue.identifier isEqualToString:@"viewGameTap"]){
        [navController setUnchallengedMessageID:messageID];
        boardController = (BoardViewController *)segue.destinationViewController;
        [boardController setShowAds: showAds];
        return;
    } else if ([segue.identifier isEqualToString:@"challengeSegue"]) {
        invitationVC = (InvitationsViewController *) segue.destinationViewController;
        [navController setUnchallengedMessageID:messageID];
        [navController setChallengedUser: author];
    }
//    NSLog(@"kitten");
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
//        NSLog(@"kitty 1");
    return YES;
}



//- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
//	// Do any additional setup after loading the view.
//    if (messageID) {
//        CGRect frame = receivedMessageView.frame;
//        if (receivedMessageView.contentSize.height < (2*receivedMessageView.font.lineHeight)) {
//            frame.size.height = receivedMessageView.contentSize.height;
//        } else {
//            frame.size.height = receivedMessageView.font.lineHeight * 2;
//        }
//        [receivedMessageView setFrame:frame];
//    }
//    
//    CGRect frame = replyMessageView.frame;
//    frame.size.height = replyMessageView.font.lineHeight*3;
//    frame.origin.y = messageID ? receivedMessageView.frame.origin.y + 10 + receivedMessageView.frame.size.height : 0;
//    [replyMessageView setFrame:frame];
//    
//    return YES;
//}

//- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
//    if (messageID) {
////        receivedMessageView.contentInset = UIEdgeInsetsMake(-7.0,0.0,0,0.0);
//        CGRect frame = receivedMessageView.frame;
//        if (receivedMessageView.contentSize.height < (4*receivedMessageView.font.lineHeight)) {
//            frame.size.height = receivedMessageView.contentSize.height;
//        } else {
//            frame.size.height = receivedMessageView.font.lineHeight * 4;
//        }
//        [receivedMessageView setFrame:frame];
//    }
//    
//    CGRect frame = replyMessageView.frame;
//    frame.size.height = replyMessageView.font.lineHeight*3;
//    frame.origin.y = messageID ? receivedMessageView.frame.origin.y + 10 + receivedMessageView.frame.size.height : 0;
//    [replyMessageView setFrame:frame];
//    
//    return YES;
//}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
{
    
    if ([text isEqualToString:@"\n"] ) {
        [textView resignFirstResponder];
        return NO;
    }

    // create final version of textView after the current text has been inserted
    NSMutableString *updatedText = [[NSMutableString alloc] initWithString:textView.text];
    [updatedText insertString:text atIndex:range.location];
    if ([updatedText length] < 3) {
//        textView.text = updatedText;
        return YES;
    }
    
    NSRange replaceRange = range, endRange = range;
    
    if (text.length > 2) {
        // handle paste
        replaceRange.length = text.length;
    } else {
        // handle normal typing
        replaceRange.length = 3;  // length of "hi" is two characters
        replaceRange.location -= 2; // look back one characters (length of "hi" minus one)
    }
    
    // replace "hi" with "hello" for the inserted range
    NSUInteger replaceCount = [updatedText replaceOccurrencesOfString:@"   " withString:@"\n" options:NSCaseInsensitiveSearch range:replaceRange];
    
    if (replaceCount > 0) {
        // update the textView's text
        textView.text = updatedText;
        
        // leave cursor at end of inserted text
        endRange.location += text.length + replaceCount * 3; // length diff of "hello" and "hi" is 3 characters
        textView.selectedRange = endRange;
        
        // let the textView know that it should ingore the inserted text
        return NO;
    }
    
    // let the textView know that it should handle the inserted text
    return YES;
//    NSUInteger len = [textView.text length];
//    if (len > 2) {
//        if ([[textView.text substringWithRange:NSMakeRange(len - 3, 3)] isEqualToString:@"   "]) {
//            text = @"\n";
//            return YES;
//        }
//    }

    
//    return YES;
}

-(void)keyboardWillShow:(NSNotification*)notification {
    NSDictionary* keyboardInfo = [notification userInfo];
    NSValue* keyboardFrameBegin = [keyboardInfo valueForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardFrameBeginRect = [keyboardFrameBegin CGRectValue];
    [UIView animateWithDuration:0.3f animations:^ {
        if (messageID) {
            float halfScreenSize = (self.view.frame.size.height - keyboardFrameBeginRect.size.height - subjectField.frame.size.height - subjectField.frame.origin.y - 3)/2;
            NSDictionary *fontAttributes = [NSDictionary dictionaryWithObject:[receivedMessageView font] forKey:NSFontAttributeName];
            CGRect textFrame = [receivedMessageView.text boundingRectWithSize:CGSizeMake(receivedMessageView.contentSize.width, halfScreenSize) options:NSStringDrawingUsesLineFragmentOrigin attributes:fontAttributes context:nil];
            
            CGFloat fontLineHeight = [[receivedMessageView font] lineHeight];
            CGRect frame = receivedMessageView.frame;
            if ((textFrame.size.height - receivedMessageView.contentInset.top - receivedMessageView.contentInset.bottom + receivedMessageView.contentOffset.y+fontLineHeight) < halfScreenSize) {
                frame.size.height = (textFrame.size.height - receivedMessageView.contentInset.top - receivedMessageView.contentInset.bottom + receivedMessageView.contentOffset.y + fontLineHeight);
            } else {
                frame.size.height = halfScreenSize;
            }
            frame.origin.y = subjectField.frame.origin.y + subjectField.frame.size.height;
            [receivedMessageView setFrame:frame];
            
            frame = CGRectMake(3, receivedMessageView.frame.origin.y + receivedMessageView.frame.size.height + 3, self.view.bounds.size.width - 6, 44);
            frame.size.height = 2*halfScreenSize - receivedMessageView.frame.size.height - 6;
            frame.origin.y = receivedMessageView.frame.origin.y + 3 + receivedMessageView.frame.size.height;
            [replyMessageView setFrame:frame];
        } else {
            float screenSize = (self.view.frame.size.height - keyboardFrameBeginRect.size.height - subjectField.frame.origin.y - subjectField.frame.size.height - 6);
            CGRect frame = CGRectMake(3, subjectField.frame.origin.y + subjectField.frame.size.height + 3, self.view.bounds.size.width - 6, screenSize);
            [replyMessageView setFrame:frame];
        }
        if (showAds) {
            [bannerView removeFromSuperview];
        }
    }];
}


-(void) keyboardWillHide {
    // Animate the current view back to its original position
    float halfScreenSize = (self.view.frame.size.height - subjectField.frame.size.height - subjectField.frame.origin.y - sendButton.frame.size.height - 9)/2;
    [UIView animateWithDuration:0.3f animations:^ {
        if (messageID) {
            NSDictionary *fontAttributes = [NSDictionary dictionaryWithObject:[receivedMessageView font] forKey:NSFontAttributeName];
            CGRect textFrame = [receivedMessageView.text boundingRectWithSize:CGSizeMake(receivedMessageView.contentSize.width, halfScreenSize) options:NSStringDrawingUsesLineFragmentOrigin attributes:fontAttributes context:nil];
            
            CGFloat fontLineHeight = [[receivedMessageView font] lineHeight];
            CGRect frame = receivedMessageView.frame;
            if ((textFrame.size.height - receivedMessageView.contentInset.top - receivedMessageView.contentInset.bottom + receivedMessageView.contentOffset.y + fontLineHeight) < halfScreenSize) {
                frame.size.height = (textFrame.size.height - receivedMessageView.contentInset.top - receivedMessageView.contentInset.bottom + receivedMessageView.contentOffset.y + fontLineHeight);
            } else {
                frame.size.height = halfScreenSize;
            }
            frame.origin.y = subjectField.frame.origin.y + subjectField.frame.size.height;
            [receivedMessageView setFrame:frame];
            
            [replyMessageView setFrame:CGRectMake(3, receivedMessageView.frame.origin.y + receivedMessageView.frame.size.height + 3, self.view.bounds.size.width - 6, 44)];
            frame = replyMessageView.frame;
            frame.size.height = sendButton.frame.origin.y - receivedMessageView.frame.origin.y - receivedMessageView.frame.size.height - 6;
            frame.origin.y = receivedMessageView.frame.origin.y + 3 + receivedMessageView.frame.size.height;
            [replyMessageView setFrame:frame];
        } else {
            [replyMessageView setFrame:CGRectMake(3, subjectField.frame.origin.y + subjectField.frame.size.height + 3, self.view.bounds.size.width - 6, sendButton.frame.origin.y - subjectField.frame.origin.y - subjectField.frame.size.height - 6)];
        }
        if (showAds) {
            [self.view addSubview:bannerView];
        }
    }];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSString *) replaceWithSmileys: (NSString *) inStr {
    NSString *tmpStrComma = [inStr stringByReplacingOccurrencesOfString:@"\\1" withString: @","];
    NSString *tmpStrSmiley = [tmpStrComma stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/happy.gif\" alt=\"\">" withString: @":)"];
    NSString *tmpStrWink = [tmpStrSmiley stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/wink.gif\" alt=\"\">" withString: @";)"];
    NSString *tmpStrTongue = [tmpStrWink stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/silly.gif\" alt=\"\">" withString: @":p"];
    NSString *tmpStrGrin = [tmpStrTongue stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/grin.gif\" alt=\"\">" withString: @":D"];
    NSString *tmpStrSad = [tmpStrGrin stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/sad.gif\" alt=\"\">" withString: @":("];
    NSString *tmpStrLove = [tmpStrSad stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/love.gif\" alt=\"\">" withString: @"<3"];
    NSString *tmpStrMischief = [tmpStrLove stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/mischief.gif\" alt=\"\">" withString: @";\\"];
    NSString *tmpStrCool = [tmpStrMischief stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/cool.gif\" alt=\"\">" withString: @"B)"];
    NSString *tmpStrDevil = [tmpStrCool stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/devil.gif\" alt=\"\">" withString: @">:)"];
    NSString *tmpStrAngry = [tmpStrDevil stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/angry.gif\" alt=\"\">" withString: @"X("];
    NSString *tmpStrLaugh = [tmpStrAngry stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/laugh.gif\" alt=\"\">" withString: @":^O"];
    NSString *tmpStrBlush = [tmpStrLaugh stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/blush.gif\" alt=\"\">" withString: @":8)"];
    NSString *tmpStrCry = [tmpStrBlush stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/cry.gif\" alt=\"\">" withString: @":'("];
    NSString *tmpStrConfused = [tmpStrCry stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/confused.gif\" alt=\"\">" withString: @"?:|"];
    NSString *tmpStrShocked = [tmpStrConfused stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/shocked.gif\" alt=\"\">" withString: @":O"];
    return [tmpStrShocked stringByReplacingOccurrencesOfString:@"<img border=\"0\" src=\"http://[host]/gameServer/forums/images/emoticons/plain.gif\" alt=\"\">" withString: @":|"];
}

-(NSString *) stripURL: (NSString *) inStr {
    NSString *tmpStr = [inStr stringByReplacingOccurrencesOfString:@"</a>" withString:@""], *tmpTmpStr;
    NSRange urlRange = [tmpStr rangeOfString: @"<a href=\""], tmpRange;
    unsigned long len = [tmpStr length];
    
    while (urlRange.location != NSNotFound) {
        tmpRange = [tmpStr rangeOfString:@"\">" options:0 range:NSMakeRange(urlRange.location, len - urlRange.location)];
        tmpTmpStr = [tmpStr stringByReplacingCharactersInRange:NSMakeRange(urlRange.location, 2 + tmpRange.location - urlRange.location) withString:@""];
        tmpStr = tmpTmpStr;
        len = [tmpStr length];
        urlRange = [tmpStr rangeOfString: @"<a href=\""];
    }
    
    return tmpStr;
}

- (NSString *) URLEncodedString_ch: (NSString *) input{
    NSMutableString * output = [NSMutableString string];
    const unsigned char * source = (const unsigned char *)[input UTF8String];
    unsigned long sourceLen = strlen((const char *)source);
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


- (NSString *)textField:(HTAutocompleteTextField *)htTextField
    completionForPrefix:(NSString *)prefix
             ignoreCase:(BOOL)ignoreCase
{
//    NSLog(@"kittyyyy %@",toHistory);
    NSString *stringToLookFor;
    if (ignoreCase)
    {
        stringToLookFor = [prefix lowercaseString];
    }
    else
    {
        stringToLookFor = prefix;
    }
    
    for (NSString *stringFromReference in self.toHistory)
    {
        
        NSString *stringToCompare;
        if (ignoreCase)
        {
            stringToCompare = [stringFromReference lowercaseString];
        }
        else
        {
            stringToCompare = stringFromReference;
        }
        
        if (stringToLookFor && [stringToCompare hasPrefix:stringToLookFor])
        {
            return [stringFromReference stringByReplacingCharactersInRange:[stringToCompare rangeOfString:stringToLookFor] withString:@""];
        }
        
    }
    
    return @"";
}


//-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
//	self.toField.textAlignment = UITextAlignmentLeft;
//    return YES ;
//}
//
//- (void)textFieldDidBeginEditing:(UITextField *)textField {
//	self.toField.textAlignment = UITextAlignmentLeft;
//}
//
//- (void)textFieldDidEndEditing:(UITextField *)textField {
//	self.toField.textAlignment = UITextAlignmentRight;
//}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	return [textField resignFirstResponder];
    //	return YES;
}


- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange {
//    NSLog(@"kitty %@",URL);
    NSString *urlString = [URL absoluteString];
    if ([urlString rangeOfString:@"mobile&g="].location != NSNotFound) {
        [self performSegueWithIdentifier:@"viewGameTap" sender:self];

        NSString *gameStr = [urlString substringFromIndex:[urlString rangeOfString:@"="].location + 1];
//        NSLog(@"kittyy %@", gameStr);
        Game *game = [[Game alloc] init];
        [game setGameID: gameStr];
//        [game setGameType:@"Connect6"];
        [game setOpponentName:author];
        [game setRemainingTime:@"0 days"];
//        [game setOpponentRating:[splitLine objectAtIndex:3]];
//        [game setMyColor:[splitLine objectAtIndex:4]];
//        [game setRemainingTime:[splitLine objectAtIndex:5]];
//        [game setRatedNot:[splitLine objectAtIndex:6]];
//        [game setNameColor: UIColorFromRGB([[splitLine objectAtIndex:7] intValue])];

        [boardController setShowAds: showAds];
        [boardController setActiveGame:NO];
        [boardController setGame:game];
        [boardController replayGame];
        [[boardController boardTapRecognizer] setEnabled: NO];
        return NO;
        
    } else if ([urlString rangeOfString:@"new.jsp?game="].location != NSNotFound) {
        [self performSegueWithIdentifier:@"challengeSegue" sender:self];

        NSString *gameString = nil;
        if ([urlString rangeOfString:@"new.jsp?game=51&"].location != NSNotFound) {
            gameString = @"Pente";
        }else if ([urlString rangeOfString:@"new.jsp?game=53&"].location != NSNotFound) {
                gameString = @"Keryo-Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=55&"].location != NSNotFound) {
            gameString = @"Gomoku";
        } else if ([urlString rangeOfString:@"new.jsp?game=57&"].location != NSNotFound) {
            gameString = @"D-Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=59&"].location != NSNotFound) {
            gameString = @"G-Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=61&"].location != NSNotFound) {
            gameString = @"Poof-Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=63&"].location != NSNotFound) {
            gameString = @"Connect6";
        } else if ([urlString rangeOfString:@"new.jsp?game=65&"].location != NSNotFound) {
            gameString = @"Boat-Pente";
        }
//        NSLog(@"peep1 %@", gameString);
        [invitationVC setGame:gameString];

        return NO;
    }
    return YES;
}



- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [self viewWillAppear:animated];
}






@end
