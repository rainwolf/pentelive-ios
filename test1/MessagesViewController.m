//
//  MessagesViewController.m
//  penteLive
//
//  Created by rainwolf on 17/03/13.
//  Copyright (c) 2013 Triade. All rights reserved.
//

#import "MessagesViewController.h"
#import "InvitationsViewController.h"
#import "PenteAlert.h"
#import "penteLive-Swift.h"
#import <QuartzCore/QuartzCore.h>

#define IS_IPHONE_5                                                            \
    (fabs((double)[[UIScreen mainScreen] bounds].size.height - (double)568) <  \
     DBL_EPSILON)
#define usernameKey @"username"
#define passwordKey @"password"

@interface MessagesViewController () <UIGestureRecognizerDelegate> {
    UILabel *replyPlaceholder;
    UIView *loadErrorView;
    NSLayoutConstraint *replyHeightConstraint;
    NSArray<NSLayoutConstraint *> *threadModeConstraints;
    NSArray<NSLayoutConstraint *> *newMessageModeConstraints;
}

@property(nonatomic) BOOL senderBlocked;

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
@synthesize player;
@synthesize gamesLimit;
@synthesize boardController;

InvitationsViewController *invitationVC;

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

//- (BOOL)shouldAutorotate {
//    UIInterfaceOrientation interfaceOrientation = [[UIApplication
//    sharedApplication] statusBarOrientation]; return (interfaceOrientation !=
//    UIInterfaceOrientationPortraitUpsideDown);
//}
//-(NSUInteger)supportedInterfaceOrientations {
//        return UIInterfaceOrientationMaskLandscapeLeft |
//        UIInterfaceOrientationMaskLandscapeRight |
//        UIInterfaceOrientationMaskPortrait;
//}

- (void)viewWillAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(keyboardWillChangeFrame:)
               name:UIKeyboardWillChangeFrameNotification
             object:nil];

    [super viewWillAppear:animated];
    if (sendButton.hidden && !self.senderBlocked &&
        ![replyMessageView isFirstResponder] &&
        ![subjectField isFirstResponder] && ![toField isFirstResponder]) {
        sendButton.hidden = NO;
    }
    [self applyLayoutMode];
}

- (void)setReplySubject {
    if ([subject length] > 3) {
        [subjectField
            setText:([[subject substringWithRange:NSMakeRange(0, 4)]
                        isEqualToString:@"Re: "])
                        ? subject
                        : [@"Re: " stringByAppendingString:subject]];
    } else {
        [subjectField setText:[@"Re: " stringByAppendingString:subject]];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    PenteNavigationViewController *navController =
        (PenteNavigationViewController *)self.navigationController;
    if (navController.challengeCancelled) {
        [self setMessageID:navController.unchallengedMessageID];
        [self setTitle:author];
        [self setReplySubject];
        [self applyLayoutMode];
        return;
    }
    [self applyLayoutMode];

    [UIView animateWithDuration:0.3f
                     animations:^{
                       [self updateNavigationItems];
                     }];

    if (messageID) {
        [self setTitle:author];
        [self setReplySubject];
        [self loadThread];
        [self checkSenderBlocked];
    } else {
        [self setTitle:@"new message"];
        self.toField.textColor = [UIColor blueColor];

        if ([navController needHelp]) {
            [navController setNeedHelp:NO];
            [toField setText:@"rainwolf"];
            [subjectField
                setText:[NSString
                            stringWithFormat:@"iOS penteLive help for %@",
                                             [[NSUserDefaults
                                                 standardUserDefaults]
                                                 objectForKey:@"username"]]];
        }
    }
}

- (void)updateNavigationItems {
    if (messageID) {
        NSMutableArray<UIBarButtonItem *> *items = [NSMutableArray arrayWithObjects:
            [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                     target:self
                                     action:@selector(deleteMessageTap)],
            [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                     target:self
                                     action:@selector(challengeTap)],
            nil];
        if (!self.senderBlocked) {
            UIBarButtonItem *blockItem = [[UIBarButtonItem alloc]
                initWithImage:[BlockedPlayersService blockIcon]
                        style:UIBarButtonItemStylePlain
                       target:self
                       action:@selector(blockTap)];
            blockItem.accessibilityLabel =
                NSLocalizedString(@"Block player", nil);
            blockItem.accessibilityIdentifier = @"blockPlayerButton";
            [items addObject:blockItem];
        }
        [self.navigationItem setRightBarButtonItems:items];
    } else {
        [self.navigationItem setRightBarButtonItem:nil];
        [self.navigationItem setRightBarButtonItems:nil];
    }
}

- (void)checkSenderBlocked {
    NSString *sender = author;
    if (!sender.length || self.senderBlocked) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [BlockedPlayersService
        isChatBlockedWithName:sender
                   completion:^(BOOL blocked) {
                     __strong typeof(weakSelf) strongSelf = weakSelf;
                     if (!strongSelf || !blocked ||
                         ![strongSelf->author isEqualToString:sender]) {
                         return;
                     }
                     [strongSelf setSenderBlocked:YES];
                     [strongSelf applyLayoutMode];
                     [strongSelf updateNavigationItems];
                   }];
}

- (void)blockTap {
    NSString *sender = author;
    __weak typeof(self) weakSelf = self;
    [BlockedPlayersService
        confirmBlockWithName:sender
              forInvitation:NO
                  onConfirm:^(BOOL blockBoth) {
                    [BlockedPlayersService
                        blockWithName:sender
                               invite:blockBoth
                                 chat:YES
                           completion:^(BOOL success, NSString *message) {
                             __strong typeof(weakSelf) strongSelf = weakSelf;
                             if (success) {
                                 if (!strongSelf) {
                                     return;
                                 }
                                 [strongSelf setSenderBlocked:YES];
                                 [strongSelf.replyMessageView resignFirstResponder];
                                 [strongSelf applyLayoutMode];
                                 [strongSelf updateNavigationItems];
                             } else {
                                 [BlockedPlayersService
                                     showErrorWithBlocking:YES
                                                      name:sender
                                                   message:message];
                             }
                           }];
                  }];
}

// Reply mode (messageID set): subject, thread, reply input, send.
// New message mode: to, subject, reply input (fills the area), send.
- (void)applyLayoutMode {
    if (!threadModeConstraints) {
        return;
    }
    BOOL replying = (messageID != nil);
    if (toField.hidden != replying) {
        toField.hidden = replying;
    }
    receivedMessageView.hidden = !replying;
    if (!replying) {
        loadErrorView.hidden = YES;
    }
    replyPlaceholder.text =
        replying ? NSLocalizedString(@"Enter reply…", nil) : nil;
    if (replying) {
        [NSLayoutConstraint deactivateConstraints:newMessageModeConstraints];
        [NSLayoutConstraint activateConstraints:threadModeConstraints];
    } else {
        [NSLayoutConstraint deactivateConstraints:threadModeConstraints];
        [NSLayoutConstraint activateConstraints:newMessageModeConstraints];
    }
    BOOL hideReply = replying && self.senderBlocked;
    replyMessageView.hidden = hideReply;
    sendButton.hidden = hideReply ? YES : sendButton.hidden;
    [self updateReplyInput];
}

- (void)loadThread {
    loadErrorView.hidden = YES;

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSString *url = [NSString
        stringWithFormat:@"https://www.pente.org/gameServer/messageJson?mid=%@",
                         messageID];
    if (development) {
        url = [NSString
            stringWithFormat:@"https://localhost/gameServer/messageJson?mid=%@",
                             messageID];
    }
    [request setURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:7.0];
    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient
        sendRequest:request
         completion:^(NSData *responseData, NSURLResponse *response,
                      NSError *error) {
           __strong typeof(weakSelf) strongSelf = weakSelf;
           if (!strongSelf)
               return;
           NSInteger status =
               [response isKindOfClass:[NSHTTPURLResponse class]]
                   ? ((NSHTTPURLResponse *)response).statusCode
                   : 0;
           // An expired session answers with the HTML login page (200);
           // parse returns nil for that too.
           MessageThread *thread =
               (error || status != 200) ? nil
                                        : [MessageThread parse:responseData];
           if (!thread) {
               strongSelf->loadErrorView.hidden = NO;
               return;
           }
           strongSelf->loadErrorView.hidden = YES;
           [(MessageThreadView *)strongSelf->receivedMessageView show:thread];
           [strongSelf->receivedMessageView setContentOffset:CGPointZero
                                                    animated:NO];
         }];
}

- (void)retryLoadTap {
    [self loadThread];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidDisappear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    self.view.backgroundColor = [UIColor
        colorWithPatternImage:[UIImage imageNamed:@"preferencesBG.png"]];

    toField = [[HTAutocompleteTextField alloc] initWithFrame:CGRectZero];
    [toField setFont:[UIFont systemFontOfSize:15]];
    [toField setTextAlignment:NSTextAlignmentLeft];
    [toField
        setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    toField.layer.borderWidth = 1.0f;
    toField.layer.borderColor = [[UIColor grayColor] CGColor];
    UIView *paddingView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 20)];
    self.toField.leftView = paddingView;
    self.toField.leftViewMode = UITextFieldViewModeAlways;
    paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    self.toField.rightView = paddingView;
    self.toField.rightViewMode = UITextFieldViewModeAlways;
    UILabel *tmpLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 40, 20)];
    [tmpLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.f]];
    [tmpLabel setText:NSLocalizedString(@"To: ", nil)];
    [self.toField addSubview:tmpLabel];
    [toField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [toField setAutocorrectionType:UITextAutocorrectionTypeNo];
    [toField setReturnKeyType:UIReturnKeyDone];
    [toField setDelegate:self];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.toHistory = [defaults objectForKey:@"invitedHistory"];
    [self.toField setAutocompleteDataSource:self];

    subjectField = [[UITextField alloc] initWithFrame:CGRectZero];
    [subjectField setFont:[UIFont systemFontOfSize:15]];
    [subjectField
        setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
    subjectField.layer.borderWidth = 1.0f;
    subjectField.layer.borderColor = [[UIColor grayColor] CGColor];
    paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 75, 20)];
    tmpLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 75, 20)];
    [tmpLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:15.f]];
    [tmpLabel setText:NSLocalizedString(@"Subject: ", nil)];
    [self.subjectField addSubview:tmpLabel];
    self.subjectField.leftView = paddingView;
    self.subjectField.leftViewMode = UITextFieldViewModeAlways;
    [subjectField setReturnKeyType:UIReturnKeyDone];
    [subjectField setDelegate:self];

    receivedMessageView =
        [[MessageThreadView alloc] initWithFrame:CGRectZero textContainer:nil];
    receivedMessageView.backgroundColor = [UIColor systemBackgroundColor];
    [receivedMessageView setAlpha:0.90];
    receivedMessageView.clipsToBounds = YES;
    receivedMessageView.layer.cornerRadius = 1.0f;
    receivedMessageView.layer.borderWidth = 1.0f;
    receivedMessageView.layer.borderColor = [[UIColor grayColor] CGColor];
    receivedMessageView.keyboardDismissMode =
        UIScrollViewKeyboardDismissModeInteractive;
    receivedMessageView.alwaysBounceVertical = YES;
    [receivedMessageView setDelegate:self];

    replyMessageView = [[UITextView alloc] initWithFrame:CGRectZero];
    [replyMessageView setFont:[[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:18]]];
    replyMessageView.adjustsFontForContentSizeCategory = YES;
    [replyMessageView setAlpha:0.90];
    [replyMessageView setEditable:YES];
    replyMessageView.clipsToBounds = YES;
    replyMessageView.layer.cornerRadius = 4.0f;
    [replyMessageView setTextContainerInset:UIEdgeInsetsMake(11, 5, 11, 5)];
    [replyMessageView
        setAutocapitalizationType:UITextAutocapitalizationTypeSentences];
    [replyMessageView setReturnKeyType:UIReturnKeyDone];
    [replyMessageView setDelegate:self];
    replyMessageView.layer.borderWidth = 1.5f;
    replyMessageView.layer.borderColor = [[UIColor grayColor] CGColor];

    replyPlaceholder = [[UILabel alloc] init];
    replyPlaceholder.translatesAutoresizingMaskIntoConstraints = NO;
    replyPlaceholder.font = replyMessageView.font;
    replyPlaceholder.adjustsFontForContentSizeCategory = YES;
    replyPlaceholder.textColor = [UIColor placeholderTextColor];
    replyPlaceholder.userInteractionEnabled = NO;
    [replyMessageView addSubview:replyPlaceholder];
    CGFloat placeholderInset = replyMessageView.textContainerInset.left +
                               replyMessageView.textContainer.lineFragmentPadding;
    [NSLayoutConstraint activateConstraints:@[
        [replyPlaceholder.leadingAnchor
            constraintEqualToAnchor:replyMessageView.frameLayoutGuide
                                        .leadingAnchor
                           constant:placeholderInset],
        [replyPlaceholder.trailingAnchor
            constraintLessThanOrEqualToAnchor:replyMessageView.frameLayoutGuide
                                                  .trailingAnchor
                                     constant:-placeholderInset],
        [replyPlaceholder.topAnchor
            constraintEqualToAnchor:replyMessageView.frameLayoutGuide.topAnchor
                           constant:replyMessageView.textContainerInset.top],
    ]];

    sendButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    sendButton.backgroundColor = [UIColor whiteColor];
    sendButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold"
                                                 size:17.f];
    [sendButton setTitleColor:[UIColor blueColor]
                     forState:UIControlStateNormal];
    [sendButton addTarget:self
                   action:@selector(sendButtonTap:)
         forControlEvents:UIControlEventTouchUpInside];
    [sendButton setTitle:NSLocalizedString(@"send", nil)
                forState:UIControlStateNormal];
    sendButton.layer.borderWidth = 1.5f;
    sendButton.layer.borderColor = [[UIColor blueColor] CGColor];
    sendButton.layer.cornerRadius = 4.0f;

    spinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    spinner.color = [UIColor blueColor];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [spinner setHidesWhenStopped:YES];
    [spinner setHidden:YES];
    [sendButton addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [spinner.centerYAnchor constraintEqualToAnchor:sendButton.centerYAnchor],
        [NSLayoutConstraint constraintWithItem:spinner
                                     attribute:NSLayoutAttributeCenterX
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:sendButton
                                     attribute:NSLayoutAttributeCenterX
                                    multiplier:0.5
                                      constant:0],
    ]];

    // Inline load-failure message with Retry, over the thread area.
    UILabel *errorLabel = [[UILabel alloc] init];
    errorLabel.text = NSLocalizedString(@"Could not load the message.", nil);
    errorLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    errorLabel.adjustsFontForContentSizeCategory = YES;
    errorLabel.textColor = [UIColor secondaryLabelColor];
    errorLabel.textAlignment = NSTextAlignmentCenter;
    errorLabel.numberOfLines = 0;
    UIButton *retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [retryButton setTitle:NSLocalizedString(@"Retry", nil)
                 forState:UIControlStateNormal];
    retryButton.titleLabel.font =
        [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    [retryButton addTarget:self
                    action:@selector(retryLoadTap)
          forControlEvents:UIControlEventTouchUpInside];
    UIStackView *errorStack =
        [[UIStackView alloc] initWithArrangedSubviews:@[ errorLabel, retryButton ]];
    errorStack.axis = UILayoutConstraintAxisVertical;
    errorStack.alignment = UIStackViewAlignmentCenter;
    errorStack.spacing = 8;
    errorStack.translatesAutoresizingMaskIntoConstraints = NO;
    errorStack.hidden = YES;
    loadErrorView = errorStack;

    // Thread + reply share this area; the reply grows up to half of it.
    UIView *messageArea = [[UIView alloc] init];
    for (UIView *v in @[ receivedMessageView, replyMessageView, errorStack ]) {
        v.translatesAutoresizingMaskIntoConstraints = NO;
        [messageArea addSubview:v];
    }

    UIStackView *stack = [[UIStackView alloc]
        initWithArrangedSubviews:@[ toField, subjectField, messageArea, sendButton ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 3;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    replyHeightConstraint =
        [replyMessageView.heightAnchor constraintEqualToConstant:44];
    replyHeightConstraint.priority = UILayoutPriorityRequired - 1;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:3],
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor
                                            constant:3],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor
                                             constant:-3],
        [stack.bottomAnchor
            constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor
                           constant:-3],
        [toField.heightAnchor constraintEqualToConstant:30],
        [subjectField.heightAnchor constraintEqualToConstant:30],
        [sendButton.heightAnchor constraintEqualToConstant:44],
        [replyMessageView.leadingAnchor
            constraintEqualToAnchor:messageArea.leadingAnchor],
        [replyMessageView.trailingAnchor
            constraintEqualToAnchor:messageArea.trailingAnchor],
        [replyMessageView.bottomAnchor
            constraintEqualToAnchor:messageArea.bottomAnchor],
        replyHeightConstraint,
        [errorStack.centerXAnchor
            constraintEqualToAnchor:receivedMessageView.centerXAnchor],
        [errorStack.centerYAnchor
            constraintEqualToAnchor:receivedMessageView.centerYAnchor],
        [errorStack.leadingAnchor
            constraintGreaterThanOrEqualToAnchor:receivedMessageView
                                                     .leadingAnchor
                                        constant:16],
    ]];
    threadModeConstraints = @[
        [receivedMessageView.topAnchor
            constraintEqualToAnchor:messageArea.topAnchor],
        [receivedMessageView.leadingAnchor
            constraintEqualToAnchor:messageArea.leadingAnchor],
        [receivedMessageView.trailingAnchor
            constraintEqualToAnchor:messageArea.trailingAnchor],
        [receivedMessageView.bottomAnchor
            constraintEqualToAnchor:replyMessageView.topAnchor
                           constant:-3],
        [replyMessageView.heightAnchor
            constraintLessThanOrEqualToAnchor:messageArea.heightAnchor
                                   multiplier:0.5],
    ];
    newMessageModeConstraints = @[
        [replyMessageView.topAnchor
            constraintEqualToAnchor:messageArea.topAnchor],
    ];

    // Tap outside the inputs dismisses the keyboard (links still work).
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(dismissKeyboardTap)];
    dismissTap.cancelsTouchesInView = NO;
    dismissTap.delegate = self;
    [self.view addGestureRecognizer:dismissTap];

    [self applyLayoutMode];
}

- (void)dismissKeyboardTap {
    [self.view endEditing:YES];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch {
    for (UIView *input in @[ replyMessageView, subjectField, toField ]) {
        if ([touch.view isDescendantOfView:input]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
        (UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateReplyInput];
}

// Reply input: 1 line when empty, grows with its content; the <= half
// constraint caps it (reply mode), after which it scrolls internally.
- (void)updateReplyInput {
    replyPlaceholder.hidden =
        (replyMessageView.text.length > 0) || self.senderBlocked;
    CGFloat width = replyMessageView.bounds.size.width;
    if (width <= 0) {
        return;
    }
    CGFloat height =
        MAX(44, ceil([replyMessageView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)]
                         .height));
    if (fabs(replyHeightConstraint.constant - height) > 0.5) {
        replyHeightConstraint.constant = height;
    }
}

- (void)textViewDidChange:(UITextView *)textView {
    if (textView == replyMessageView) {
        [self updateReplyInput];
    }
}

- (void)sendButtonTap:(UIButton *)sender {
    if (!messageID && ([toField.text length] == 0)) {
        [PenteAlert
                showWithTitle:NSLocalizedString(@"No recipient entered.", nil)
                      message:nil
            cancelButtonTitle:@"OK"];
        return;
    }
    if ([subjectField.text length] == 0) {
        [PenteAlert showWithTitle:NSLocalizedString(@"No subject entered.", nil)
                          message:nil
                cancelButtonTitle:@"OK"];
        return;
    }
    if ([replyMessageView.text length] == 0) {
        [PenteAlert showWithTitle:NSLocalizedString(@"No message found.", nil)
                          message:nil
                cancelButtonTitle:@"OK"];
        return;
    }

    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(sendMessage:)
                             toTarget:self
                           withObject:replyMessageView.text];
}

- (void)sendMessage:(NSString *)replyMessage {
    if (!messageID) {
        author = toField.text;
        subject = subjectField.text;
    }
    NSString *post = [NSString
        stringWithFormat:@"command=create&to=%@&subject=%@&body=%@&mobile=",
                         author, [self URLEncodedString_ch:subject],
                         [self URLEncodedString_ch:replyMessage]];
    if (messageID) {
        post = [post stringByAppendingFormat:@"&replyTo=%@", messageID];
    }
    //    NSLog(@"kitty %@", post);
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                          allowLossyConversion:YES];
    NSString *postLength =
        [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSURL *url =
        [NSURL URLWithString:@"https://www.pente.org/gameServer/mymessages"];
    if (development) {
        url = [NSURL URLWithString:@"https://localhost/gameServer/mymessages"];
    }
    [request setURL:url];
    //    [request setURL:[NSURL
    //    URLWithString:@"https://localhost/gameServer/mymessages"]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];
    //    [PenteHTTPClient sendSynchronousRequest:request
    //    returningResponse:&response error:&error];

    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSString *dashboardString =
            [[NSString alloc] initWithData:responseData
                                  encoding:NSUTF8StringEncoding];
        //    NSLog(@"kitty %@", dashboardString);

        if (error) {
            [PenteAlert showWithTitle:NSLocalizedString(@"Error", nil)
                              message:[NSString stringWithFormat:
                                                    NSLocalizedString(
                                                        @"Reason: %@", nil),
                                                    error.localizedDescription]
                    cancelButtonTitle:@"OK"];
        } else if ([dashboardString
                       rangeOfString:[NSString stringWithFormat:
                                                   @"Error: Player %@ not found.",
                                                   strongSelf->toField.text]]
                       .length != 0) {
            [PenteAlert
                    showWithTitle:NSLocalizedString(@"Error", nil)
                          message:[NSString
                                      stringWithFormat:NSLocalizedString(
                                                           @"The username %@ "
                                                           @"does not exist.",
                                                           nil),
                                                       strongSelf->toField.text]
                cancelButtonTitle:@"OK"];
        } else {
            if ([strongSelf->toField.text length] > 0) {
                NSString *opponent = [strongSelf->toField.text lowercaseString];
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                strongSelf->toHistory = [[defaults objectForKey:@"invitedHistory"] mutableCopy];
                if (strongSelf->toHistory) {
                    int i = 0;
                    for (i = 0; i < [strongSelf->toHistory count]; ++i) {
                        if ([[strongSelf->toHistory objectAtIndex:i]
                                localizedCaseInsensitiveCompare:strongSelf->toField.text] ==
                            NSOrderedDescending)
                            break;
                    }
                    if (![strongSelf->toHistory containsObject:opponent]) {
                        [strongSelf->toHistory insertObject:opponent atIndex:i];
                    }
                } else {
                    strongSelf->toHistory = [NSMutableArray arrayWithObject:opponent];
                }
                [defaults setObject:strongSelf->toHistory forKey:@"invitedHistory"];
            }
            [strongSelf->spinner stopAnimating];
            [strongSelf.navigationController popToRootViewControllerAnimated:YES];
        }
        [strongSelf->spinner stopAnimating];
    }];
}

- (void)deleteMessageTap {
    PenteNavigationViewController *navControllor =
        (PenteNavigationViewController *)self.navigationController;
    [navControllor setMessageDeleted:YES];
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(deleteMessage)
                             toTarget:self
                           withObject:nil];
}

- (void)deleteMessage {
    //    self.view.layer.borderWidth = 1.5;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *username = [defaults objectForKey:usernameKey];
    NSString *password = [defaults objectForKey:passwordKey];

    NSString *post = [NSString
        stringWithFormat:@"command=delete&mid=%@&name2=%@&password2=%@&mobile=",
                         messageID, username, password];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding
                          allowLossyConversion:YES];
    NSString *postLength =
        [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

    NSURL *url =
        [NSURL URLWithString:@"https://www.pente.org/gameServer/mymessages"];
    if (development) {
        url = [NSURL URLWithString:@"https://localhost/gameServer/mymessages"];
    }
    [request setURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/x-www-form-urlencoded"
        forHTTPHeaderField:@"Content-Type"];

    [request setHTTPBody:postData];
    [request setTimeoutInterval:7.0];

    [request setHTTPShouldUsePipelining:YES];

    __weak typeof(self) weakSelf = self;
    [PenteHTTPClient sendRequest:request completion:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        //        NSData *responseData = [NSURLConnection
        //        sendSynchronousRequest:request returningResponse:&response
        //        error:&error]; NSString *dashboardString = [[NSString alloc]
        //        initWithData:responseData encoding:NSUTF8StringEncoding];
        //        //        [self login];
        //        NSLog(@"kitty %@", dashboardString);

        [strongSelf->spinner stopAnimating];
        [strongSelf.navigationController popToRootViewControllerAnimated:YES];
    }];
}

- (void)challengeTap {
    PenteNavigationViewController *navControllor =
        (PenteNavigationViewController *)self.navigationController;
    [navControllor setDidMove:YES];
    [spinner setHidden:NO];
    [spinner startAnimating];
    [NSThread detachNewThreadSelector:@selector(challenge)
                             toTarget:self
                           withObject:nil];
}

- (void)challenge {
    //    self.view.layer.borderWidth = 1.5;
    [spinner performSelectorOnMainThread:@selector(stopAnimating)
                              withObject:nil
                           waitUntilDone:NO];
    [self performSelectorOnMainThread:@selector(performChallengeSegue)
                           withObject:nil
                        waitUntilDone:NO];

    //    [self.navigationController
    //    performSelectorOnMainThread:@selector(popToRootViewControllerAnimated:)
    //    withObject:nil waitUntilDone:YES];
}

- (void)performChallengeSegue {
    [self performSegueWithIdentifier:@"challengeSegue" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    PenteNavigationViewController *navController =
        (PenteNavigationViewController *)self.navigationController;
    if ([segue.identifier isEqualToString:@"viewGameTap"]) {
        [navController setUnchallengedMessageID:messageID];
        boardController =
            (BoardViewController *)segue.destinationViewController;
        return;
    } else if ([segue.identifier isEqualToString:@"challengeSegue"]) {
        invitationVC =
            (InvitationsViewController *)segue.destinationViewController;
        [navController setUnchallengedMessageID:messageID];
        [navController setChallengedUser:author];
    }
    //    NSLog(@"kitten");
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier
                                  sender:(id)sender {
    //        NSLog(@"kitty 1");
    return YES;
}

//- (BOOL)textViewShouldBeginEditing:(UITextView *)textView {
//	// Do any additional setup after loading the view.
//    if (messageID) {
//        CGRect frame = receivedMessageView.frame;
//        if (receivedMessageView.contentSize.height <
//        (2*receivedMessageView.font.lineHeight)) {
//            frame.size.height = receivedMessageView.contentSize.height;
//        } else {
//            frame.size.height = receivedMessageView.font.lineHeight * 2;
//        }
//        [receivedMessageView setFrame:frame];
//    }
//
//    CGRect frame = replyMessageView.frame;
//    frame.size.height = replyMessageView.font.lineHeight*3;
//    frame.origin.y = messageID ? receivedMessageView.frame.origin.y + 10 +
//    receivedMessageView.frame.size.height : 0; [replyMessageView
//    setFrame:frame];
//
//    return YES;
//}

//- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
//    if (messageID) {
////        receivedMessageView.contentInset = UIEdgeInsetsMake(-7.0,0.0,0,0.0);
//        CGRect frame = receivedMessageView.frame;
//        if (receivedMessageView.contentSize.height <
//        (4*receivedMessageView.font.lineHeight)) {
//            frame.size.height = receivedMessageView.contentSize.height;
//        } else {
//            frame.size.height = receivedMessageView.font.lineHeight * 4;
//        }
//        [receivedMessageView setFrame:frame];
//    }
//
//    CGRect frame = replyMessageView.frame;
//    frame.size.height = replyMessageView.font.lineHeight*3;
//    frame.origin.y = messageID ? receivedMessageView.frame.origin.y + 10 +
//    receivedMessageView.frame.size.height : 0; [replyMessageView
//    setFrame:frame];
//
//    return YES;
//}

- (BOOL)textView:(UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString *)text;
{

    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        return NO;
    }

    // leave a range UIKit would reject for UIKit to deal with
    if (NSMaxRange(range) > textView.text.length) {
        return YES;
    }

    // never rewrite while composing (IME marked text) or on a deletion
    if (textView.markedTextRange != nil || text.length == 0) {
        return YES;
    }

    // create final version of textView after the current text has been inserted
    NSMutableString *updatedText =
        [[NSMutableString alloc] initWithString:textView.text];
    [updatedText replaceCharactersInRange:range withString:text];
    if ([updatedText length] < 3) {
        //        textView.text = updatedText;
        return YES;
    }

    NSRange endRange = range;
    // look back two characters (length of "   " minus one), clamped to the text
    NSUInteger searchStart = range.location >= 2 ? range.location - 2 : 0;
    NSUInteger searchEnd;

    if (text.length > 2) {
        // handle paste: the inserted text plus two characters before it
        searchEnd = MIN(updatedText.length, range.location + text.length);
    } else {
        // handle normal typing
        searchEnd =
            MIN(updatedText.length, range.location + MAX(text.length, 1));
    }
    NSRange replaceRange = NSMakeRange(searchStart, searchEnd - searchStart);

    @try {
        NSUInteger replaceCount =
            [updatedText replaceOccurrencesOfString:@"   "
                                         withString:@"\n"
                                            options:NSCaseInsensitiveSearch
                                              range:replaceRange];
        // replace "   " with "\n" for the inserted range

        if (replaceCount > 0) {
            // update the textView's text
            textView.text = updatedText;
            if (textView == replyMessageView) {
                [self updateReplyInput];
            }

            // leave cursor at end of inserted text
            // each "   " -> "\n" is 2 characters shorter
            endRange.length = 0;
            endRange.location = MIN(updatedText.length,
                                    range.location + text.length -
                                        replaceCount * 2);
            textView.selectedRange = endRange;

            // let the textView know that it should ingore the inserted text
            return NO;
        }

        // let the textView know that it should handle the inserted text
        return YES;
        //    NSUInteger len = [textView.text length];
        //    if (len > 2) {
        //        if ([[textView.text substringWithRange:NSMakeRange(len - 3,
        //        3)] isEqualToString:@"   "]) {
        //            text = @"\n";
        //            return YES;
        //        }
        //    }

        //    return YES;
    } @catch (NSException *exception) {
        return NO;
    } @finally {
    }
}

// Hide the send button while a software keyboard covers the bottom of the
// screen so the thread/reply area gets the space; show it again once the
// keyboard is gone. A hardware keyboard (only the small shortcut bar shows)
// or a floating/undocked keyboard leaves the button visible.
- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect endFrame =
        [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // The end frame is in screen coordinates; on iPad (Stage Manager, Split
    // View, Slide Over) the window is not the screen, so convert from it.
    UIScreen *screen = self.view.window.screen;
    if (!screen) {
        return;
    }
    CGRect local = [self.view convertRect:endFrame
                       fromCoordinateSpace:screen.coordinateSpace];
    CGRect bounds = self.view.bounds;
    BOOL softwareKeyboardShown = NO;
    if (!CGRectIsEmpty(local) && CGRectIntersectsRect(bounds, local) &&
        CGRectGetMaxY(local) >= CGRectGetMaxY(bounds) - 1) {
        CGFloat overlap = CGRectGetMaxY(bounds) -
                          self.view.safeAreaInsets.bottom - CGRectGetMinY(local);
        softwareKeyboardShown = (overlap > 100);
    }
    if (self.senderBlocked || sendButton.hidden == softwareKeyboardShown) {
        return;
    }
    double duration =
        [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve curve =
        [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration
                          delay:0
                        options:(UIViewAnimationOptions)curve << 16
                     animations:^{
                       self->sendButton.hidden = softwareKeyboardShown;
                       [self.view layoutIfNeeded];
                     }
                     completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSString *)URLEncodedString_ch:(NSString *)input {
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[input UTF8String];
    unsigned long sourceLen = strlen((const char *)source);
    for (int i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' ') {
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' ||
                   thisChar == '~' || (thisChar >= 'a' && thisChar <= 'z') ||
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
             ignoreCase:(BOOL)ignoreCase {
    //    NSLog(@"kittyyyy %@",toHistory);
    NSString *stringToLookFor;
    if (ignoreCase) {
        stringToLookFor = [prefix lowercaseString];
    } else {
        stringToLookFor = prefix;
    }

    for (NSString *stringFromReference in self.toHistory) {

        NSString *stringToCompare;
        if (ignoreCase) {
            stringToCompare = [stringFromReference lowercaseString];
        } else {
            stringToCompare = stringFromReference;
        }

        if (stringToLookFor && [stringToCompare hasPrefix:stringToLookFor]) {
            return [stringFromReference
                stringByReplacingCharactersInRange:
                    [stringToCompare rangeOfString:stringToLookFor]
                                        withString:@""];
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

- (BOOL)textView:(UITextView *)textView
    shouldInteractWithURL:(NSURL *)URL
                  inRange:(NSRange)characterRange
              interaction:(UITextItemInteraction)interaction {
    //    NSLog(@"kitty %@",URL);
    NSString *urlString = [URL absoluteString];
    if ([urlString rangeOfString:@"mobile&g="].location != NSNotFound) {
        [self performSegueWithIdentifier:@"viewGameTap" sender:self];

        NSString *gameStr = [urlString
            substringFromIndex:[urlString rangeOfString:@"="].location + 1];
        //        NSLog(@"kittyy %@", gameStr);
        Game *game = [[Game alloc] init];
        [game setGameID:gameStr];
        //        [game setGameType:@"Connect6"];
        [game setOpponentName:author];
        [game setRemainingTime:@"0 days"];
        //        [game setOpponentRating:[splitLine objectAtIndex:3]];
        //        [game setMyColor:[splitLine objectAtIndex:4]];
        //        [game setRemainingTime:[splitLine objectAtIndex:5]];
        //        [game setRatedNot:[splitLine objectAtIndex:6]];
        //        [game setNameColor: UIColorFromRGB([[splitLine
        //        objectAtIndex:7] intValue])];

        [boardController setActiveGame:NO];
        [boardController setGame:game];
        [boardController replayGame];
        [[boardController boardTapRecognizer] setEnabled:NO];
        return NO;

    } else if ([urlString rangeOfString:@"new.jsp?game="].location !=
               NSNotFound) {
        [self performSegueWithIdentifier:@"challengeSegue" sender:self];

        NSString *gameString = nil;
        if ([urlString rangeOfString:@"new.jsp?game=51&"].location !=
            NSNotFound) {
            gameString = @"Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=53&"].location !=
                   NSNotFound) {
            gameString = @"Keryo-Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=55&"].location !=
                   NSNotFound) {
            gameString = @"Gomoku";
        } else if ([urlString rangeOfString:@"new.jsp?game=57&"].location !=
                   NSNotFound) {
            gameString = @"D-Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=59&"].location !=
                   NSNotFound) {
            gameString = @"G-Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=61&"].location !=
                   NSNotFound) {
            gameString = @"Poof-Pente";
        } else if ([urlString rangeOfString:@"new.jsp?game=63&"].location !=
                   NSNotFound) {
            gameString = @"Connect6";
        } else if ([urlString rangeOfString:@"new.jsp?game=65&"].location !=
                   NSNotFound) {
            gameString = @"Boat-Pente";
        }
        //        NSLog(@"peep1 %@", gameString);
        [invitationVC setGame:gameString];

        return NO;
    } else {
        PenteWebViewController *webViewController =
            [[PenteWebViewController alloc] initWithAddress:urlString];
        [self.navigationController pushViewController:webViewController
                                             animated:YES];
        return NO;
    }
    //    return YES;
}

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
    [self viewWillAppear:animated];
}

@end
