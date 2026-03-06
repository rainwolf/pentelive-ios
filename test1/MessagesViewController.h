//
//  MessagesViewController.h
//  penteLive
//
//  Created by rainwolf on 17/03/13.
//  Copyright (c) 2013 Triade. All rights reserved.
//

#import "BoardViewController.h"
#import "HTAutocompleteTextField.h"
#import "PenteNavigationViewController.h"
#import "PentePlayer.h"
#import <UIKit/UIKit.h>

@interface MessagesViewController
    : UIViewController <UITextViewDelegate, UITextFieldDelegate,
                        HTAutocompleteDataSource,
                        UINavigationControllerDelegate> {
    NSString *messageID, *subject, *author;
    UITextField *subjectField;
    HTAutocompleteTextField *toField;
    UITextView *receivedMessageView, *replyMessageView;
    UIButton *sendButton;
    UIActivityIndicatorView *spinner;
    NSMutableArray *toHistory;
    PentePlayer *player;
    int gamesLimit;

    BoardViewController *boardController;
}

@property(nonatomic, retain) PentePlayer *player;
@property(nonatomic, retain) NSString *messageID, *subject, *author;
@property(nonatomic, retain) UITextView *receivedMessageView, *replyMessageView;
@property(nonatomic, retain) UIButton *sendButton;
@property(nonatomic, retain) UITextField *subjectField;
@property(nonatomic, retain) HTAutocompleteTextField *toField;
@property(nonatomic, retain) UIActivityIndicatorView *spinner;
@property(nonatomic, retain) NSMutableArray *toHistory;
@property(atomic) int gamesLimit;
@property(nonatomic, retain) BoardViewController *boardController;

@end
