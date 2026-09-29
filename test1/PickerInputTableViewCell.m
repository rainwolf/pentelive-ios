//
//  PickerInputTableViewCell.m
//  ShootStudio
//
//  Created by Tom Fewster on 18/10/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "PickerInputTableViewCell.h"

@interface PickerInputTableViewCell () <UIPopoverPresentationControllerDelegate>
// For iPad: hosts self.picker as the content of a popover presentation.
@property(nonatomic, strong) UIViewController *pickerHost;
@end

@implementation PickerInputTableViewCell
@synthesize picker;
@synthesize resign;
// BOOL resign = NO;

//@synthesize picker;

- (void)initalizeInputView {
    self.picker = [[UIPickerView alloc] initWithFrame:CGRectZero];
    self.picker.autoresizingMask = UIViewAutoresizingFlexibleHeight;

    if ([UIDevice currentDevice].userInterfaceIdiom ==
        UIUserInterfaceIdiomPad) {
        UIViewController *popoverContent = [[UIViewController alloc] init];
        popoverContent.view = self.picker;
        self.pickerHost = popoverContent;
    }
}

- (void)presentPickerPopover {
    UIViewController *host = self.pickerHost;
    if (host == nil || host.presentingViewController != nil) {
        return;
    }
    UIResponder *responder = self.nextResponder;
    while (responder != nil &&
           ![responder isKindOfClass:[UIViewController class]]) {
        responder = responder.nextResponder;
    }
    UIViewController *presenter = (UIViewController *)responder;
    if (presenter == nil) {
        return;
    }
    while (presenter.presentedViewController != nil) {
        presenter = presenter.presentedViewController;
    }
    host.modalPresentationStyle = UIModalPresentationPopover;
    UIPopoverPresentationController *popover =
        host.popoverPresentationController;
    popover.sourceView = self.contentView;
    popover.sourceRect = self.detailTextLabel.frame;
    popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
    popover.delegate = self;
    [presenter presentViewController:host animated:YES completion:nil];
}

- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self initalizeInputView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initalizeInputView];
    }
    return self;
}

- (UIView *)inputView {
    if ([UIDevice currentDevice].userInterfaceIdiom ==
        UIUserInterfaceIdiomPad) {
        return nil;
    } else {
        return self.picker;
    }
}

- (UIView *)inputAccessoryView {
    if ([UIDevice currentDevice].userInterfaceIdiom ==
        UIUserInterfaceIdiomPad) {
        return nil;
    } else {
        if (!inputAccessoryView) {
            inputAccessoryView = [[UIToolbar alloc] init];
            inputAccessoryView.barStyle = UIBarStyleBlack;
            inputAccessoryView.translucent = YES;
            inputAccessoryView.autoresizingMask =
                UIViewAutoresizingFlexibleHeight;
            [inputAccessoryView sizeToFit];
            CGRect frame = inputAccessoryView.frame;
            frame.size.height = 44.0f;
            inputAccessoryView.frame = frame;

            UIBarButtonItem *doneBtn = [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                     target:self
                                     action:@selector(done:)];
            UIBarButtonItem *flexibleSpaceLeft = [[UIBarButtonItem alloc]
                initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                     target:nil
                                     action:nil];

            NSArray *array =
                [NSArray arrayWithObjects:flexibleSpaceLeft, doneBtn, nil];
            [inputAccessoryView setItems:array];
        }
        return inputAccessoryView;
    }
}

- (void)done:(id)sender {
    id tableView = self;
    while (![tableView isKindOfClass:[UITableView class]] &&
           [tableView respondsToSelector:@selector(superview)]) {
        tableView = ((UIView *)tableView).superview;
    }
    CGFloat insetY = -((UITableView *)tableView).contentInset.top;
    [tableView scrollRectToVisible:CGRectMake(0, insetY, 1, 1) animated:YES];
    //    [tableView setScrollEnabled:NO];
    resign = YES;
    [self resignFirstResponder];
}

- (void)doResign {
    resign = YES;
    [self resignFirstResponder];
}

- (BOOL)becomeFirstResponder {
    //	[[NSNotificationCenter defaultCenter] addObserver:self
    // selector:@selector(deviceDidRotate:)
    // name:UIDeviceOrientationDidChangeNotification object:nil];
    if ([UIDevice currentDevice].userInterfaceIdiom ==
        UIUserInterfaceIdiomPad) {
        CGSize pickerSize = [self.picker sizeThatFits:CGSizeZero];
        CGRect frame = self.picker.frame;
        frame.size = pickerSize;
        self.picker.frame = frame;
        self.pickerHost.preferredContentSize = pickerSize;
        [self presentPickerPopover];
        // resign the current first responder
        for (UIView *subview in self.superview.subviews) {
            if ([subview isFirstResponder]) {
                [subview resignFirstResponder];
            }
        }
        return YES;
    } else {
        //		[self.picker setNeedsLayout];
    }
    resign = NO;
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:UIDeviceOrientationDidChangeNotification
                object:nil];
    if (resign)
        return [super resignFirstResponder];
    else
        return YES;
    //    return [super resignFirstResponder];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (selected) {
        [self becomeFirstResponder];
    }
}

- (void)deviceDidRotate:(NSNotification *)notification {
    if ([UIDevice currentDevice].userInterfaceIdiom ==
        UIUserInterfaceIdiomPad) {
        // we should only get this call if the popover is visible
        self.pickerHost.popoverPresentationController.sourceRect =
            self.detailTextLabel.frame;
    } else {
        [self.picker setNeedsLayout];
    }
}

#pragma mark -
#pragma mark Respond to touch and become first responder.

- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark -
#pragma mark UIKeyInput Protocol Methods

- (BOOL)hasText {
    return YES;
}

- (void)insertText:(NSString *)theText {
}

- (void)deleteBackward {
}

#pragma mark -
#pragma mark UIPopoverPresentationControllerDelegate Protocol Methods

- (UIModalPresentationStyle)
    adaptivePresentationStyleForPresentationController:
        (UIPresentationController *)controller
                                       traitCollection:(UITraitCollection *)
                                                           traitCollection {
    return UIModalPresentationNone;
}

- (void)presentationControllerDidDismiss:
    (UIPresentationController *)presentationController {
    id tableView = self;
    while (![tableView isKindOfClass:[UITableView class]] &&
           [tableView respondsToSelector:@selector(superview)]) {
        tableView = ((UIView *)tableView).superview;
    }
    [tableView deselectRowAtIndexPath:[tableView indexPathForCell:self]
                             animated:YES];
    //    [tableView scrollRectToVisible:CGRectMake(0,0, 1, 1) animated:YES];
    [self resignFirstResponder];
}

@end
