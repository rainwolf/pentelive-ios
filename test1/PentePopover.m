#import "PentePopover.h"

// Spacing and title style carried over from the runway20 popover pod this
// replaces (its kBoxPadding, kTitleFont and kTitleColor).
static const CGFloat kPentePopoverPadding = 10.0;
static const CGFloat kPentePopoverMargin = 10.0;

typedef NS_ENUM(NSInteger, PentePopoverState) {
    PentePopoverStatePresented,
    PentePopoverStateDismissing,
    PentePopoverStateDismissed,
};

@interface PentePopover () <UIPopoverPresentationControllerDelegate>
@property(nonatomic, copy, nullable) void (^onDismiss)(void);
@property(nonatomic, strong) NSMutableArray<void (^)(void)> *pendingCompletions;
@property(nonatomic, assign) PentePopoverState state;
- (void)finishDismissal;
@end

/// Hosts the stacked content inside the popover.
@interface PentePopoverContentController : UIViewController
@property(nonatomic, strong) UIView *container;
/// Keeps the PentePopover alive while it is presented; cleared on dismissal.
@property(nonatomic, strong, nullable) PentePopover *owner;
@end

@implementation PentePopoverContentController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.container];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // The safe area excludes the popover arrow.
    UIEdgeInsets insets = self.view.safeAreaInsets;
    CGRect frame = self.container.frame;
    frame.origin = CGPointMake(insets.left + kPentePopoverPadding,
                               insets.top + kPentePopoverPadding);
    self.container.frame = frame;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // Safety net for a dismissal that bypasses both -dismissWithCompletion:
    // and presentationControllerDidDismiss: (e.g. the presenter itself being
    // dismissed). Deferred so those paths run first; finishDismissal is
    // idempotent.
    PentePopover *owner = self.owner;
    if (owner == nil) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (weakSelf.presentingViewController == nil) {
            [owner finishDismissal];
        }
    });
}

@end

@implementation PentePopover {
    PentePopoverContentController *controller;
}

+ (instancetype)showContentView:(UIView *)content
                          title:(NSString *)title
                        atPoint:(CGPoint)point
                         inView:(UIView *)view
                      onDismiss:(void (^)(void))onDismiss {
    return [self showViews:@[ content ]
                     title:title
                   atPoint:point
                    inView:view
                 onDismiss:onDismiss];
}

+ (instancetype)showViews:(NSArray<UIView *> *)views
                    title:(NSString *)title
                  atPoint:(CGPoint)point
                   inView:(UIView *)view
                onDismiss:(void (^)(void))onDismiss {
    UIResponder *responder = view;
    while (responder != nil &&
           ![responder isKindOfClass:[UIViewController class]]) {
        responder = responder.nextResponder;
    }
    UIViewController *presenter = (UIViewController *)responder;
    if (presenter == nil || view.window == nil) {
        NSLog(@"PentePopover: no presenting view controller for %@ (window: "
              @"%@); not showing",
              view, view.window);
        return nil;
    }
    while (presenter.presentedViewController != nil) {
        presenter = presenter.presentedViewController;
    }

    // Keep the popover inside the window with a 10 pt margin each side (the
    // old pod's kHorizontalMargin); wider content is narrowed to fit.
    UIWindow *window = view.window;
    UIEdgeInsets safeArea = window.safeAreaInsets;
    CGFloat maxContentWidth = window.bounds.size.width - safeArea.left -
                              safeArea.right - 2 * kPentePopoverMargin -
                              2 * kPentePopoverPadding;
    UIView *container = [self containerWithViews:views
                                           title:title
                                        maxWidth:maxContentWidth];

    PentePopover *popover = [[self alloc] init];
    popover.onDismiss = onDismiss;
    popover.pendingCompletions = [[NSMutableArray alloc] init];
    popover.state = PentePopoverStatePresented;

    PentePopoverContentController *host =
        [[PentePopoverContentController alloc] init];
    host.container = container;
    host.owner = popover;
    host.modalPresentationStyle = UIModalPresentationPopover;
    host.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    host.preferredContentSize =
        CGSizeMake(container.bounds.size.width + 2 * kPentePopoverPadding,
                   container.bounds.size.height + 2 * kPentePopoverPadding);
    popover->controller = host;

    UIPopoverPresentationController *presentation =
        host.popoverPresentationController;
    presentation.sourceView = view;
    presentation.sourceRect = CGRectMake(point.x, point.y, 1, 1);
    // Up or down only, as the old pod: a sideways arrow eats into the width.
    presentation.permittedArrowDirections =
        UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
    presentation.backgroundColor = [UIColor whiteColor];
    presentation.delegate = popover;

    [presenter presentViewController:host animated:YES completion:nil];
    return popover;
}

/// Lays `views` out the way the old pod's withTitle:withViewArray: did: the
/// title on top, then the views stacked with kPentePopoverPadding between
/// them, each centred (or stretched when exactly flexible-width) to the
/// widest. Views wider than `maxWidth` are narrowed to it (their
/// flexible-width subviews follow through autoresizing; multi-line labels get
/// the height their text now needs).
+ (UIView *)containerWithViews:(NSArray<UIView *> *)views
                         title:(NSString *)title
                      maxWidth:(CGFloat)maxWidth {
    UIView *container = [[UIView alloc] initWithFrame:CGRectZero];
    CGFloat totalWidth = 0;
    CGFloat totalHeight = 0;
    maxWidth = MAX(floor(maxWidth), 1);

    for (UIView *subview in views) {
        CGRect frame = subview.frame;
        if (frame.size.width <= maxWidth) {
            continue;
        }
        frame.size.width = maxWidth;
        if ([subview isKindOfClass:[UILabel class]] &&
            ((UILabel *)subview).numberOfLines != 1) {
            frame.size.height =
                ceil([subview sizeThatFits:CGSizeMake(maxWidth, CGFLOAT_MAX)]
                         .height);
        }
        subview.frame = frame;
    }

    UILabel *titleLabel = nil;
    if (title.length > 0) {
        titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:16];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.textColor = [UIColor colorWithRed:0.329
                                               green:0.341
                                                blue:0.353
                                               alpha:1];
        titleLabel.text = title;
        [titleLabel sizeToFit];
        if (titleLabel.bounds.size.width > maxWidth) {
            CGRect titleFrame = titleLabel.bounds;
            titleFrame.size.width = maxWidth;
            titleLabel.frame = titleFrame;
        }
        totalWidth = titleLabel.bounds.size.width;
        totalHeight = titleLabel.bounds.size.height + 2 * kPentePopoverPadding;
        [container addSubview:titleLabel];
    }

    for (NSUInteger i = 0; i < views.count; i++) {
        UIView *subview = views[i];
        CGSize size = subview.frame.size;
        subview.frame = CGRectMake(0, totalHeight, size.width, size.height);
        totalHeight += size.height;
        if (i + 1 < views.count) {
            totalHeight += kPentePopoverPadding;
        }
        totalWidth = MAX(totalWidth, size.width);
        [container addSubview:subview];
    }

    for (UIView *subview in views) {
        CGRect frame = subview.frame;
        if (subview.autoresizingMask == UIViewAutoresizingFlexibleWidth) {
            frame.origin.x = 0;
            frame.size.width = totalWidth;
        } else {
            frame.origin.x = floor((totalWidth - frame.size.width) / 2);
        }
        subview.frame = frame;
    }

    if (titleLabel != nil) {
        CGSize titleSize = titleLabel.bounds.size;
        titleLabel.frame = CGRectMake(floor((totalWidth - titleSize.width) / 2),
                                      0, titleSize.width, titleSize.height);
    }

    container.frame = CGRectMake(0, 0, totalWidth, totalHeight);
    return container;
}

- (BOOL)isPresented {
    return self.state == PentePopoverStatePresented;
}

- (void)dismiss {
    [self dismissWithCompletion:nil];
}

- (void)dismissWithCompletion:(void (^)(void))completion {
    if (self.state == PentePopoverStateDismissed) {
        if (completion != nil) {
            completion();
        }
        return;
    }
    if (completion != nil) {
        [self.pendingCompletions addObject:[completion copy]];
    }
    if (self.state == PentePopoverStateDismissing) {
        return;
    }
    self.state = PentePopoverStateDismissing;
    UIViewController *presenting = controller.presentingViewController;
    if (presenting == nil) {
        [self finishDismissal];
        return;
    }
    // Dismiss from the presenting controller so anything presented on top of
    // the popover (e.g. PickerInputTableViewCell's iPad picker) goes too.
    [presenting dismissViewControllerAnimated:YES
                                   completion:^{
                                       [self finishDismissal];
                                   }];
}

- (void)finishDismissal {
    if (self.state == PentePopoverStateDismissed) {
        return;
    }
    self.state = PentePopoverStateDismissed;
    void (^onDismiss)(void) = self.onDismiss;
    self.onDismiss = nil;
    NSArray<void (^)(void)> *completions = [self.pendingCompletions copy];
    [self.pendingCompletions removeAllObjects];
    if (onDismiss != nil) {
        onDismiss();
    }
    for (void (^completion)(void) in completions) {
        completion();
    }
    // The content stays alive for as long as the caller holds this popover,
    // as it did with the old pod: some content (the picker cells) refuses to
    // resign first responder and must not be freed while UIKit still points
    // at it. Last: clearing owner may release the final strong reference to
    // self, so nothing on self is touched afterwards (the local keeps the
    // controller alive through the call).
    PentePopoverContentController *host = controller;
    host.owner = nil;
}

#pragma mark UIPopoverPresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:
    (UIPresentationController *)presentationController {
    return UIModalPresentationNone;
}

- (UIModalPresentationStyle)
    adaptivePresentationStyleForPresentationController:
        (UIPresentationController *)presentationController
                                       traitCollection:(UITraitCollection *)
                                                           traitCollection {
    return UIModalPresentationNone;
}

- (void)presentationControllerWillDismiss:
    (UIPresentationController *)presentationController {
    if (self.state == PentePopoverStatePresented) {
        self.state = PentePopoverStateDismissing;
    }
}

- (void)presentationControllerDidDismiss:
    (UIPresentationController *)presentationController {
    [self finishDismissal];
}

@end
