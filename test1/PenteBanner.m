#import "PenteBanner.h"

PenteBannerDuration const PenteBannerDurationAutomatic = 0;
PenteBannerDuration const PenteBannerDurationEndless = -1;

// TSMessage.m's timing constants, kept numerically identical.
static const NSTimeInterval kPenteBannerDisplayTime = 1.5;
static const NSTimeInterval kPenteBannerExtraDisplayTimePerPoint = 0.04;
static const NSTimeInterval kPenteBannerAnimationDuration = 0.3;

static const CGFloat kPenteBannerEdgeMargin = 12.0; // card inset from the host's sides
static const CGFloat kPenteBannerGap = 8.0;         // below the nav bar / above the bottom edge
static const CGFloat kPenteBannerMaxWidth = 600.0;  // keeps the card a card on iPad
static const CGFloat kPenteBannerCornerRadius = 22.0;
static const CGFloat kPenteBannerPaddingH = 16.0;
static const CGFloat kPenteBannerPaddingV = 12.0;
static const CGFloat kPenteBannerSpacing = 12.0; // icon | text | button
static const CGFloat kPenteBannerOffscreenSlack = 24.0; // clears the shadow when off screen

/// Opacity of the type colour used as the glass tint. High enough that the tint,
/// not whatever sits underneath, sets the card colour, so the glass text colours
/// below keep their contrast; low enough to still read as glass. (1.0 measured
/// barely different from 0.8.)
static const CGFloat kPenteBannerGlassTintAlpha = 0.8;

typedef NS_ENUM(NSInteger, PenteBannerState) {
    PenteBannerStateQueued = 0,
    PenteBannerStateAnimatingIn,
    PenteBannerStateShown,
    PenteBannerStateAnimatingOut
};

static UIColor *PenteBannerRGB(uint32_t rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1.0];
}

/// The TSMessages default design's background colour for each type.
static UIColor *PenteBannerBackgroundColor(PenteBannerType type) {
    switch (type) {
    case PenteBannerTypeWarning:
        return PenteBannerRGB(0xDAC43C);
    case PenteBannerTypeError:
        return PenteBannerRGB(0xDD3B41);
    case PenteBannerTypeSuccess:
        return PenteBannerRGB(0x76CF67);
    case PenteBannerTypeMessage:
    default:
        return PenteBannerRGB(0xD4DDDF);
    }
}

/// The TSMessages default design's text colour for each type.
static UIColor *PenteBannerTextColor(PenteBannerType type) {
    switch (type) {
    case PenteBannerTypeWarning:
        return PenteBannerRGB(0x484638);
    case PenteBannerTypeError:
    case PenteBannerTypeSuccess:
        return PenteBannerRGB(0xFFFFFF);
    case PenteBannerTypeMessage:
    default:
        return PenteBannerRGB(0x727C83);
    }
}

/// Text colour on the tinted glass. At kPenteBannerGlassTintAlpha the tint sets
/// the card colour in light and dark mode alike (measured on the simulator: grey
/// ~#B1B6B8-#DBE1E3, yellow ~#B6A335-#E0CE61, green ~#66AB58-#90D783), so the
/// TSMessages greys and white-on-green drop to 2:1 there. Near-black shades of
/// each hue instead; red is the one tint that stays dark enough in dark mode for
/// white, and light enough in light mode for the dark shade. Dynamic colours
/// also follow the glass if it adapts to dark content underneath. Every pairing
/// measured at least 4.5:1 (WCAG AA) in the verification screenshots.
static UIColor *PenteBannerGlassTextColor(PenteBannerType type) {
    switch (type) {
    case PenteBannerTypeWarning:
        return PenteBannerRGB(0x25230F);
    case PenteBannerTypeError: {
        UIColor *light = PenteBannerRGB(0x2E0709);
        UIColor *dark = PenteBannerRGB(0xFFFFFF);
        return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
            return traits.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light;
        }];
    }
    case PenteBannerTypeSuccess:
        return PenteBannerRGB(0x0A2A06);
    case PenteBannerTypeMessage:
    default:
        return PenteBannerRGB(0x1F2528);
    }
}

static NSString *PenteBannerSymbolName(PenteBannerType type) {
    switch (type) {
    case PenteBannerTypeWarning:
        return @"exclamationmark.triangle";
    case PenteBannerTypeError:
        return @"xmark.octagon";
    case PenteBannerTypeSuccess:
        return @"checkmark.circle";
    case PenteBannerTypeMessage:
    default:
        return @"info.circle";
    }
}

@class PenteBannerView;

@interface PenteBanner ()
+ (void)fadeOutBanner:(PenteBannerView *)banner;
@end

#pragma mark - PenteBannerWindowTracker

/// Invisible, zero-size marker placed in the presenting view controller's own
/// view when the banner itself lives in the navigation controller's view. It
/// reports that view leaving the window (the view controller was popped,
/// covered or dismissed), which the banner's own -didMoveToWindow cannot see
/// there, so an Endless banner still goes away with its screen as in TSMessage.
@interface PenteBannerWindowTracker : UIView
@property (nonatomic, weak, nullable) PenteBannerView *banner;
@property (nonatomic) BOOL wasInWindow;
@end

#pragma mark - PenteBannerView

@interface PenteBannerView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, weak, nullable) UIViewController *viewController;
@property (nonatomic) PenteBannerType type;
@property (nonatomic) PenteBannerPosition position;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) BOOL dismissingEnabled;
@property (nonatomic, copy, nullable) void (^callback)(void);
@property (nonatomic, copy, nullable) NSString *buttonTitle;
@property (nonatomic, copy, nullable) void (^buttonCallback)(void);
@property (nonatomic) PenteBannerState state;
/// Translation that puts the card just off the host's top or bottom edge.
@property (nonatomic) CGAffineTransform offscreenTransform;
@property (nonatomic, strong, nullable) PenteBannerWindowTracker *windowTracker;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) NSArray<UILabel *> *labels;
@property (nonatomic, strong, nullable) UIButton *button;
@end

@implementation PenteBannerView

- (void)buildContent {
    UIColor *textColor = PenteBannerTextColor(self.type);

    // Card background: tinted Liquid Glass on iOS 26+, solid colour before.
    UIView *background;
    UIView *contentHost;
    if (@available(iOS 26.0, *)) {
        UIGlassEffect *glass = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        glass.tintColor = [PenteBannerBackgroundColor(self.type)
            colorWithAlphaComponent:kPenteBannerGlassTintAlpha];
        glass.interactive = YES;
        UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:glass];
        effectView.cornerConfiguration = [UICornerConfiguration
            configurationWithUniformRadius:[UICornerRadius fixedRadius:kPenteBannerCornerRadius]];
        background = effectView;
        contentHost = effectView.contentView;
        textColor = PenteBannerGlassTextColor(self.type);
    }
    if (background == nil) {
        background = [[UIView alloc] init];
        background.backgroundColor = PenteBannerBackgroundColor(self.type);
        background.layer.cornerRadius = kPenteBannerCornerRadius;
        background.layer.cornerCurve = kCACornerCurveContinuous;
        contentHost = background;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.2;
        self.layer.shadowRadius = 10.0;
        self.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    }
    background.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:background];

    UIImageSymbolConfiguration *symbolConfig =
        [UIImageSymbolConfiguration configurationWithPointSize:22.0
                                                        weight:UIImageSymbolWeightSemibold];
    UIImageView *icon = [[UIImageView alloc]
        initWithImage:[UIImage systemImageNamed:PenteBannerSymbolName(self.type)
                              withConfiguration:symbolConfig]];
    icon.tintColor = textColor;
    icon.contentMode = UIViewContentModeCenter;
    [icon setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [icon setContentCompressionResistancePriority:UILayoutPriorityRequired
                                          forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = self.title;
    titleLabel.textColor = textColor;
    titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
        scaledFontForFont:[UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold]];
    titleLabel.numberOfLines = 0;

    UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[ titleLabel ]];
    textStack.axis = UILayoutConstraintAxisVertical;
    textStack.spacing = 2.0;
    if (self.subtitle.length) {
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.text = self.subtitle;
        subtitleLabel.textColor = textColor;
        subtitleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
            scaledFontForFont:[UIFont systemFontOfSize:13.0]];
        subtitleLabel.numberOfLines = 0;
        [textStack addArrangedSubview:subtitleLabel];
    }
    self.iconView = icon;
    self.labels = textStack.arrangedSubviews;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[ icon, textStack ]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = kPenteBannerSpacing;
    row.translatesAutoresizingMaskIntoConstraints = NO;

    if (self.buttonTitle.length) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.title = self.buttonTitle;
        config.baseForegroundColor = textColor;
        config.background.backgroundColor = [textColor colorWithAlphaComponent:0.18];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.contentInsets = NSDirectionalEdgeInsetsMake(6.0, 12.0, 6.0, 12.0);
        config.titleTextAttributesTransformer =
            ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *in) {
                NSMutableDictionary *out = [in mutableCopy];
                out[NSFontAttributeName] = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
                return out;
            };
        UIButton *button = [UIButton buttonWithConfiguration:config primaryAction:nil];
        [button addTarget:self
                      action:@selector(buttonTapped:)
            forControlEvents:UIControlEventTouchUpInside];
        [button setContentHuggingPriority:UILayoutPriorityRequired
                                  forAxis:UILayoutConstraintAxisHorizontal];
        [button setContentCompressionResistancePriority:UILayoutPriorityRequired
                                                forAxis:UILayoutConstraintAxisHorizontal];
        [row addArrangedSubview:button];
        self.button = button;
    }
    [contentHost addSubview:row];

    // Lets the card grow taller than its content (NavBarOverlay covering the
    // bar) while the row stays vertically centred.
    // Anchored to background, not contentHost: a glass contentView is sized by
    // autoresizing, which would hide the row's height from -heightForWidth:.
    NSLayoutConstraint *rowTop = [row.topAnchor
        constraintGreaterThanOrEqualToAnchor:background.topAnchor
                                    constant:kPenteBannerPaddingV];
    [NSLayoutConstraint activateConstraints:@[
        [background.topAnchor constraintEqualToAnchor:self.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [background.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        rowTop,
        [row.centerYAnchor constraintEqualToAnchor:background.centerYAnchor],
        [row.leadingAnchor constraintEqualToAnchor:background.leadingAnchor
                                          constant:kPenteBannerPaddingH],
        [row.trailingAnchor constraintEqualToAnchor:background.trailingAnchor
                                           constant:-kPenteBannerPaddingH],
    ]];

    // One tap recognizer: a tap runs callback then dismisses (the fork's
    // patch); without a callback it dismisses only when the user may dismiss.
    if (self.callback || self.dismissingEnabled) {
        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        tap.delegate = self;
        [self addGestureRecognizer:tap];
    }
    if (self.dismissingEnabled) {
        UISwipeGestureRecognizer *swipe =
            [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
        swipe.direction = self.position == PenteBannerPositionBottom
                              ? UISwipeGestureRecognizerDirectionDown
                              : UISwipeGestureRecognizerDirectionUp;
        swipe.delegate = self;
        [self addGestureRecognizer:swipe];
    }

    // VoiceOver reads the card as one element; the button and dismissal are
    // custom actions so they stay reachable.
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = [self announcement];
    self.accessibilityTraits = self.callback ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
    NSMutableArray<UIAccessibilityCustomAction *> *actions = [NSMutableArray array];
    if (self.buttonTitle.length) {
        __weak PenteBannerView *weakSelf = self;
        [actions addObject:[[UIAccessibilityCustomAction alloc]
                               initWithName:self.buttonTitle
                              actionHandler:^BOOL(UIAccessibilityCustomAction *action) {
                                  [weakSelf buttonTapped:nil];
                                  return YES;
                              }]];
    }
    if (self.dismissingEnabled) {
        __weak PenteBannerView *weakSelf = self;
        [actions addObject:[[UIAccessibilityCustomAction alloc]
                               initWithName:NSLocalizedString(@"dismiss", nil)
                              actionHandler:^BOOL(UIAccessibilityCustomAction *action) {
                                  [PenteBanner fadeOutBanner:weakSelf];
                                  return YES;
                              }]];
    }
    self.accessibilityCustomActions = actions;
}

- (NSString *)announcement {
    NSString *title = self.title ?: @"";
    return self.subtitle.length ? [NSString stringWithFormat:@"%@, %@", title, self.subtitle] : title;
}

- (CGFloat)heightForWidth:(CGFloat)width {
    // Multi-line labels inside stack views only wrap in a fitting pass when
    // they know their width up front.
    CGFloat textWidth = width - 2.0 * kPenteBannerPaddingH - self.iconView.intrinsicContentSize.width -
                        kPenteBannerSpacing;
    if (self.button != nil) {
        textWidth -= self.button.intrinsicContentSize.width + kPenteBannerSpacing;
    }
    for (UILabel *label in self.labels) {
        label.preferredMaxLayoutWidth = MAX(textWidth, 1.0);
    }
    CGSize size = [self systemLayoutSizeFittingSize:CGSizeMake(width, 0.0)
                      withHorizontalFittingPriority:UILayoutPriorityRequired
                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return ceil(size.height);
}

#pragma mark Actions

- (void)handleTap:(UITapGestureRecognizer *)tap {
    if (tap.state != UIGestureRecognizerStateRecognized) {
        return;
    }
    if (self.callback) {
        self.callback();
    }
    [PenteBanner fadeOutBanner:self];
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)swipe {
    [PenteBanner fadeOutBanner:self];
}

- (void)buttonTapped:(id)sender {
    if (self.buttonCallback) {
        self.buttonCallback();
    }
    [PenteBanner fadeOutBanner:self];
}

- (BOOL)accessibilityActivate {
    if (!self.callback && !self.dismissingEnabled) {
        return NO;
    }
    if (self.callback) {
        self.callback();
    }
    [PenteBanner fadeOutBanner:self];
    return YES;
}

- (BOOL)accessibilityPerformEscape {
    if (!self.dismissingEnabled) {
        return NO;
    }
    [PenteBanner fadeOutBanner:self];
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return ![touch.view isKindOfClass:[UIControl class]];
}

- (void)durationElapsed {
    [PenteBanner fadeOutBanner:self];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    // As TSMessage: an Endless banner whose host view left the window (its view
    // controller was popped or dismissed) fades out rather than blocking the queue.
    if (self.duration == PenteBannerDurationEndless && self.superview != nil && self.window == nil) {
        [PenteBanner fadeOutBanner:self];
    }
}

@end

@implementation PenteBannerWindowTracker

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window == nil && self.wasInWindow && self.superview != nil) {
        [PenteBanner fadeOutBanner:self.banner];
    }
    self.wasInWindow = self.window != nil;
}

@end

#pragma mark - PenteBanner

static NSMutableArray<PenteBannerView *> *sQueue; // [0] is on screen unless still Queued

@implementation PenteBanner

+ (void)showNotificationInViewController:(UIViewController *)viewController
                                   title:(NSString *)title
                                subtitle:(NSString *)subtitle
                                    type:(PenteBannerType)type
                                duration:(NSTimeInterval)duration
                    canBeDismissedByUser:(BOOL)dismissingEnabled {
    [self showNotificationInViewController:viewController
                                     title:title
                                  subtitle:subtitle
                                     image:nil
                                      type:type
                                  duration:duration
                                  callback:nil
                               buttonTitle:nil
                            buttonCallback:nil
                                atPosition:PenteBannerPositionTop
                      canBeDismissedByUser:dismissingEnabled];
}

+ (void)showNotificationInViewController:(UIViewController *)viewController
                                   title:(NSString *)title
                                subtitle:(NSString *)subtitle
                                   image:(UIImage *)image
                                    type:(PenteBannerType)type
                                duration:(NSTimeInterval)duration
                                callback:(void (^)(void))callback
                             buttonTitle:(NSString *)buttonTitle
                          buttonCallback:(void (^)(void))buttonCallback
                              atPosition:(PenteBannerPosition)position
                    canBeDismissedByUser:(BOOL)dismissingEnabled {
    if (![NSThread isMainThread]) { // UIKit objects may only be built on main
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showNotificationInViewController:viewController
                                             title:title
                                          subtitle:subtitle
                                             image:image
                                              type:type
                                          duration:duration
                                          callback:callback
                                       buttonTitle:buttonTitle
                                    buttonCallback:buttonCallback
                                        atPosition:position
                              canBeDismissedByUser:dismissingEnabled];
        });
        return;
    }
    if (viewController == nil) {
        return;
    }
    if (sQueue == nil) {
        sQueue = [NSMutableArray array];
    }
    // As TSMessage: drop a banner whose title and subtitle match one already
    // queued or showing (nil matches nil).
    for (PenteBannerView *queued in sQueue) {
        BOOL sameTitle = queued.title == title || [queued.title isEqualToString:title];
        BOOL sameSubtitle = queued.subtitle == subtitle || [queued.subtitle isEqualToString:subtitle];
        if (sameTitle && sameSubtitle) {
            return;
        }
    }

    PenteBannerView *banner = [[PenteBannerView alloc] initWithFrame:CGRectZero];
    banner.title = title;
    banner.subtitle = subtitle;
    banner.viewController = viewController;
    banner.type = type;
    banner.position = position;
    banner.duration = duration;
    banner.dismissingEnabled = dismissingEnabled;
    banner.callback = callback;
    banner.buttonTitle = buttonTitle;
    banner.buttonCallback = buttonCallback;
    [banner buildContent];

    [sQueue addObject:banner];
    [self showNextIfIdle];
}

+ (BOOL)dismissActiveNotification {
    if (sQueue.count == 0) {
        return NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        PenteBannerView *current = sQueue.firstObject;
        // Ignored while animating in (TSMessage's messageIsFullyDisplayed check),
        // and while already animating out, so it is idempotent.
        if (current.state == PenteBannerStateShown) {
            [self fadeOutBanner:current];
        }
    });
    return YES;
}

#pragma mark Queue

+ (void)showNextIfIdle {
    while (sQueue.count > 0) {
        PenteBannerView *banner = sQueue.firstObject;
        if (banner.state != PenteBannerStateQueued) {
            return; // one on screen already
        }
        UIViewController *viewController = banner.viewController;
        if (viewController != nil) {
            [self fadeInBanner:banner inViewController:viewController];
            return;
        }
        [sQueue removeObjectAtIndex:0]; // its view controller is gone
    }
}

/// Hosts the banner as TSMessage does: in the navigation controller's view,
/// below its bar (Top, Bottom) or above it (NavBarOverlay), else in the view
/// controller's own view.
+ (void)fadeInBanner:(PenteBannerView *)banner inViewController:(UIViewController *)viewController {
    UINavigationController *nav = nil;
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        nav = (UINavigationController *)viewController;
    } else if ([viewController.parentViewController isKindOfClass:[UINavigationController class]]) {
        nav = (UINavigationController *)viewController.parentViewController;
    }
    UINavigationBar *bar = nav.navigationBar;
    BOOL barShown = nav != nil && !nav.navigationBarHidden && !bar.hidden;

    // Set before it joins the hierarchy so -didMoveToWindow sees a live banner.
    banner.state = PenteBannerStateAnimatingIn;
    UIView *host;
    CGRect barFrame = CGRectNull;
    if (barShown) {
        host = nav.view;
        barFrame = [bar convertRect:bar.bounds toView:host];
        if (banner.position == PenteBannerPositionNavBarOverlay) {
            [host insertSubview:banner aboveSubview:bar]; // over the (glass) bar, and tappable
        } else {
            [host insertSubview:banner belowSubview:bar]; // slides out from under the bar
        }
    } else {
        host = viewController.view;
        [host addSubview:banner];
    }

    // Floating card: inset from the sides and safe area, capped in width on iPad.
    CGRect bounds = host.bounds; // origin is the content offset when host is a scroll view
    UIEdgeInsets safe = host.safeAreaInsets;
    CGFloat usable = CGRectGetWidth(bounds) - safe.left - safe.right;
    CGFloat width = MIN(usable - 2.0 * kPenteBannerEdgeMargin, kPenteBannerMaxWidth);
    CGFloat x = CGRectGetMinX(bounds) + safe.left + round((usable - width) / 2.0);
    CGFloat height = [banner heightForWidth:width];
    CGFloat y;
    switch (banner.position) {
    case PenteBannerPositionNavBarOverlay:
        if (barShown) {
            height = MAX(height, CGRectGetHeight(barFrame));
            y = CGRectGetMinY(barFrame);
        } else {
            y = CGRectGetMinY(bounds) + safe.top + kPenteBannerGap;
        }
        break;
    case PenteBannerPositionBottom: {
        CGFloat bottom = CGRectGetMaxY(bounds) - safe.bottom - kPenteBannerGap;
        if (nav != nil && !nav.toolbarHidden && !nav.toolbar.hidden) {
            UIToolbar *toolbar = nav.toolbar;
            CGFloat toolbarTop = CGRectGetMinY([toolbar convertRect:toolbar.bounds toView:host]);
            bottom = MIN(bottom, toolbarTop - kPenteBannerGap);
        }
        y = bottom - height;
        break;
    }
    case PenteBannerPositionTop:
    default:
        y = (barShown ? CGRectGetMaxY(barFrame) : CGRectGetMinY(bounds) + safe.top) + kPenteBannerGap;
        break;
    }
    if (host != viewController.view && banner.duration == PenteBannerDurationEndless) {
        PenteBannerWindowTracker *tracker = [[PenteBannerWindowTracker alloc] initWithFrame:CGRectZero];
        tracker.hidden = YES;
        tracker.userInteractionEnabled = NO;
        tracker.banner = banner;
        tracker.wasInWindow = viewController.view.window != nil;
        banner.windowTracker = tracker;
        [viewController.view addSubview:tracker];
    }

    banner.frame = CGRectMake(x, y, width, height);
    banner.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                              (banner.position == PenteBannerPositionBottom
                                   ? UIViewAutoresizingFlexibleTopMargin
                                   : UIViewAutoresizingFlexibleBottomMargin);
    [banner layoutIfNeeded];

    banner.offscreenTransform =
        banner.position == PenteBannerPositionBottom
            ? CGAffineTransformMakeTranslation(0.0, CGRectGetMaxY(bounds) - y + kPenteBannerOffscreenSlack)
            : CGAffineTransformMakeTranslation(0.0, -(y + height - CGRectGetMinY(bounds) + kPenteBannerOffscreenSlack));
    banner.transform = banner.offscreenTransform;

    // TSMessage's iOS 7 style animation: 0.3 + 0.1 s spring, damping 0.8.
    [UIView animateWithDuration:kPenteBannerAnimationDuration + 0.1
        delay:0.0
        usingSpringWithDamping:0.8
        initialSpringVelocity:0.0
        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
            banner.transform = CGAffineTransformIdentity;
        }
        completion:^(BOOL finished) {
            if (banner.state == PenteBannerStateAnimatingIn) { // not already on its way out
                banner.state = PenteBannerStateShown;
            }
        }];

    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, [banner announcement]);

    if (banner.duration == PenteBannerDurationAutomatic) {
        banner.duration = kPenteBannerAnimationDuration + kPenteBannerDisplayTime +
                          height * kPenteBannerExtraDisplayTimePerPoint;
    }
    if (banner.duration != PenteBannerDurationEndless) {
        [banner performSelector:@selector(durationElapsed) withObject:nil afterDelay:banner.duration];
    }
}

/// The single exit path. Idempotent: a banner that is queued, already fading or
/// no longer at the head of the queue is left alone, so a callback that calls
/// +dismissActiveNotification before the built-in dismissal cannot fade the
/// banner twice or pop the next queued one.
+ (void)fadeOutBanner:(PenteBannerView *)banner {
    if (banner == nil || sQueue.firstObject != banner ||
        (banner.state != PenteBannerStateAnimatingIn && banner.state != PenteBannerStateShown)) {
        return;
    }
    banner.state = PenteBannerStateAnimatingOut;
    [NSObject cancelPreviousPerformRequestsWithTarget:banner
                                             selector:@selector(durationElapsed)
                                               object:nil];
    [UIView animateWithDuration:kPenteBannerAnimationDuration
        delay:0.0
        options:UIViewAnimationOptionBeginFromCurrentState
        animations:^{
            banner.transform = banner.offscreenTransform;
        }
        completion:^(BOOL finished) {
            [banner removeFromSuperview];
            [banner.windowTracker removeFromSuperview];
            banner.windowTracker = nil;
            [sQueue removeObjectIdenticalTo:banner];
            [self showNextIfIdle];
        }];
}

@end
