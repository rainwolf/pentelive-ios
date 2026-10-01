#import "PenteBadge.h"
#import <objc/runtime.h>

// Geometry from the badge pod this replaces: badgePadding, badgeMinSize and
// badgeOriginY.
static const CGFloat kPenteBadgePadding = 6.0;
static const CGFloat kPenteBadgeMinTextHeight = 8.0;
static const CGFloat kPenteBadgeOffsetY = -4.0;
static const CGFloat kPenteBadgeFontSize = 12.0;

static char kPenteBadgeLabelKey;

static BOOL PenteBadgeValueIsHidden(NSString *value) {
    return value == nil || value.length == 0 || [value isEqualToString:@"0"];
}

@implementation UIView (PenteBadge)

- (UILabel *)pente_setBadgeValue:(NSString *)value color:(UIColor *)color {
    UILabel *badge = objc_getAssociatedObject(self, &kPenteBadgeLabelKey);
    if (PenteBadgeValueIsHidden(value)) {
        [badge removeFromSuperview];
        objc_setAssociatedObject(self, &kPenteBadgeLabelKey, nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return nil;
    }
    if (badge == nil) {
        badge = [[UILabel alloc] initWithFrame:CGRectZero];
        badge.textAlignment = NSTextAlignmentCenter;
        badge.textColor = [UIColor whiteColor];
        badge.font = [UIFont boldSystemFontOfSize:kPenteBadgeFontSize];
        badge.layer.masksToBounds = YES;
        // Above subviews the host adds later (a button's title and image).
        badge.layer.zPosition = 1;
        badge.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                 UIViewAutoresizingFlexibleBottomMargin;
        objc_setAssociatedObject(self, &kPenteBadgeLabelKey, badge,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // The badge sits partly above the view's top edge.
        self.clipsToBounds = NO;
        [self addSubview:badge];
    }
    badge.backgroundColor = color;
    badge.text = value;

    CGSize textSize = [badge sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    CGFloat textHeight = MAX(ceil(textSize.height), kPenteBadgeMinTextHeight);
    CGFloat textWidth = MAX(ceil(textSize.width), textHeight);
    CGFloat height = textHeight + kPenteBadgePadding;
    CGFloat width = textWidth + kPenteBadgePadding;
    badge.frame = CGRectMake(self.bounds.size.width - width, kPenteBadgeOffsetY,
                             width, height);
    badge.layer.cornerRadius = height / 2;
    return badge;
}

@end

static char kPenteBadgeRequestKey;

@implementation UIBarButtonItem (PenteBadge)

- (void)pente_setBadgeValue:(NSString *)value color:(UIColor *)color {
    // Remembered so a deferred retry applies the latest value, not a stale one.
    NSArray *request = @[ value ?: [NSNull null], color ];
    objc_setAssociatedObject(self, &kPenteBadgeRequestKey, request,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self pente_setBadgeValue:value color:color retryWhenUnlaidOut:YES];
}

- (void)pente_setBadgeValue:(NSString *)value
                      color:(UIColor *)color
         retryWhenUnlaidOut:(BOOL)retry {
    UIView *host = self.customView;
    if (host == nil && [self respondsToSelector:NSSelectorFromString(@"view")]) {
        id view = [self valueForKey:@"view"];
        if ([view isKindOfClass:[UIView class]]) {
            host = view;
        }
    }
    if (host != nil) {
        [host pente_setBadgeValue:value color:color];
        return;
    }
    if (!retry) {
        return;
    }
    // The bar has not created the item's view yet; it will have after the
    // current layout pass.
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSArray *latest =
            objc_getAssociatedObject(strongSelf, &kPenteBadgeRequestKey);
        if (latest == nil) {
            return;
        }
        id latestValue = latest[0];
        [strongSelf pente_setBadgeValue:(latestValue == [NSNull null]
                                             ? nil
                                             : latestValue)
                                  color:latest[1]
                     retryWhenUnlaidOut:NO];
    });
}

@end
