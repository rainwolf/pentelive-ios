# Replace TSMessages (and HexColors) with a native PenteBanner

Branch `replace-tsmessages`, one PR. The spec is the owner's request of 2026-09-29: do P5, replacing it with a native banner, and "I would like a glass look". That feeds into the triage entry for P5, stored in memory as `pod-replacement-triage`. TSMessages is the owner's fork (`rainwolf/TSMessages@c638015`). HexColors is its only dependent pod, and it's the one Xcode's module verifier fails on.

## Global Constraints

- **Build:** `xcodebuild -workspace penteLive.xcworkspace -scheme test1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO build`, then the same with `name=iPad Pro 13-inch (M5)`. Always pin `-scheme test1` and confirm `penteLive.app` was produced.
- **Launch check:** after each task, launch on both simulators.
  - Run `xcrun simctl bootstatus <udid> -b`, then install, launch `be.submanifold.penteLive` and check `launchctl list`.
  - Take a screenshot and look at it.
- **Warnings:** app warnings are counted from app source files only. The count stays at exactly 1, the kept deprecated `application:didReceiveRemoteNotification:` in AppDelegate.m.
- **Pod removal procedure:**
  1. Delete the Podfile line and run `pod install`.
  2. Revert the xcconfig `baseConfigurationReference` UUID churn in `penteLive.xcodeproj/project.pbxproj`, keeping only the hunks that belong to the removed pods.
  3. Commit the Podfile, Podfile.lock and `test1/Settings.bundle/Acknowledgements.plist`.
  4. Delete any stray `_Users_*.swiftpm.lock` and `TemporaryDirectory.*` in the repo root.
- **Don'ts:**
  - Never accept Xcode's "Update to recommended settings".
  - Never change the deployment target (iOS 15.0) or build settings.
  - Don't touch other pods.
- **Style:** match the surrounding ObjC style. New app classes go in `test1/` and are registered in the `penteLive` app target only.
- **Scratch:** keep it in `/private/tmp/claude-501/pods-replace/`. Temporary debug hooks must be reverted before committing.
- **Commits:** no Co-Authored-By or generated-by lines.

### Task 1: PenteBanner

**Model:** opus

Add `test1/PenteBanner.h/.m`. It's an ObjC class usable from Swift through the bridging header, which gets `#import "PenteBanner.h"`.

**Public API.** Mirror only what the app uses, so that Task 2 is a rename.
- `typedef NS_ENUM(NSInteger, PenteBannerType) { PenteBannerTypeMessage, PenteBannerTypeWarning, PenteBannerTypeError, PenteBannerTypeSuccess };`
- `typedef NS_ENUM(NSInteger, PenteBannerPosition) { PenteBannerPositionTop, PenteBannerPositionNavBarOverlay, PenteBannerPositionBottom };`
- Duration is an `NSTimeInterval`. Define the constants `PenteBannerDurationAutomatic = 0` and `PenteBannerDurationEndless = -1`, with the same meaning as TSMessage's values. Check TSMessage.h for its exact numeric values and match them, because Swift call sites pass `TSMessageNotificationDuration.*`.
- `+ (void)showNotificationInViewController:(UIViewController *)viewController title:(NSString *)title subtitle:(nullable NSString *)subtitle image:(nullable UIImage *)image type:(PenteBannerType)type duration:(NSTimeInterval)duration callback:(nullable void (^)(void))callback buttonTitle:(nullable NSString *)buttonTitle buttonCallback:(nullable void (^)(void))buttonCallback atPosition:(PenteBannerPosition)position canBeDismissedByUser:(BOOL)dismissingEnabled;`
  - `image` is accepted and ignored. It is always nil today.
- `+ (void)showNotificationInViewController:(UIViewController *)viewController title:(NSString *)title subtitle:(nullable NSString *)subtitle type:(PenteBannerType)type duration:(NSTimeInterval)duration canBeDismissedByUser:(BOOL)dismissingEnabled;`
  - This is the short form used from Swift, with position Top, no callback and no button.
- `+ (BOOL)dismissActiveNotification;`

**Behaviour.** Reproduce it from `Pods/TSMessages/Pod/Classes/TSMessage.m` and `TSMessageView.m`; read them first.
- **Hosting:** add the banner to the presenting navigation controller's view, below its navigation bar, as TSMessage does. Don't use an overlay window.
  - **Top:** the banner sits below the navigation bar.
  - **NavBarOverlay:** it covers the navigation bar. It must render over the iOS 26+ glass nav bar and stay tappable.
  - **Bottom:** it sits above the safe area and above any visible toolbar.
- **Queue:** one banner at a time, first in, first out. A banner whose title and subtitle match one already queued or showing is dropped.
- **Durations:**
  - Automatic is `0.3 + 1.5 + 0.04 × banner height in points` seconds, which is TSMessage's formula. Confirm it from the source.
  - Endless stays until dismissed. An Endless banner also fades out when its host view leaves the window.
- **Interaction:**
  - Swipe to dismiss when `canBeDismissedByUser`.
  - A tap runs `callback`, then dismisses. This is the fork's patch, now built in.
  - The optional right-side button runs `buttonCallback`, then dismisses.
- **`dismissActiveNotification`:**
  - It is idempotent: no double fade, and no swallowing the next queued banner.
  - Keep TSMessage's behaviour of ignoring a dismiss while the banner is still animating in. Row taps on the Games screen rely on it.
  - Return value: match TSMessage.
- **Accessibility:** post a `UIAccessibilityAnnouncementNotification` with title and subtitle, and make the banner an accessibility element.

**Look (the owner's requirement):**
- **iOS 26+:** use a Liquid Glass banner. `UIVisualEffectView` with `UIGlassEffect`, whose `tintColor` is the type's colour. Make it a floating rounded card inset from the screen edges, not an edge-to-edge bar. Use an SF Symbol icon per type, e.g. `info.circle`, `exclamationmark.triangle`, `xmark.octagon`, `checkmark.circle`.
- **iOS 15–25:** use the same card shape filled solidly with the current colours.
  - Backgrounds: Success `#76CF67`, Message `#D4DDDF`, Warning `#DAC43C`, Error `#DD3B41`.
  - Text: Success `#FFFFFF`, Message `#727C83`, Warning `#484638`, Error `#FFFFFF`.
  - Use the same SF Symbols.
- **Legibility:** title and subtitle must be readable on the glass in both light and dark mode. Choose the text colour or glass tint strength to ensure it, and show it in screenshots.
- `+ (void)showNotificationInViewController:...` must not touch HexColors or any TSMessages resource.

**Verification.** Use a temporary debug hook, reverted before committing, that presents banners from the root view controller.
1. Take screenshots of all 4 types at Bottom, of one Top, and of one NavBarOverlay with a button.
2. Take them on the iPhone 18 Pro and iPad Pro 13-inch (M5) simulators, in light and dark mode.
3. Force the iOS 15–25 path temporarily, because only an iOS 27 runtime is installed, and screenshot the solid style too.
4. Look at every screenshot and describe what you saw.
5. Show that the queue works (two banners in sequence), that de-dup works, and that `dismissActiveNotification` is ignored while a banner animates in.

**Done when:** the class builds on both simulators with 1 app warning and the app launches on both. The report includes the screenshot paths and observations. TSMessages is still installed and still used; Task 2 migrates.

### Task 2: Migrate every call site and remove TSMessages and HexColors

**Model:** sonnet

1. Replace every TSMessage use with PenteBanner, keeping arguments and behaviour 1:1:
   - `TSMessage showNotificationInViewController:...` becomes `PenteBanner`, with `TSMessageNotificationType*`, `TSMessageNotificationPosition*` and `TSMessageNotificationDuration*` mapped to the PenteBanner equivalents. There are 28 show sites across AppDelegate.m, SettingsViewController.m, BoardViewController.m, MMAIViewController.m, KOTHTableViewController.m, TableViewController.swift and RoomViewController.swift.
   - `dismissActiveNotification` has 32 calls, including those in GamesTableViewController.m.
2. Remove every TSMessages import: `@import TSMessages;` in GamesTableViewController.m, SettingsViewController.m, KOTHTableViewController.m, AppDelegate.m and penteLive-Bridging-Header.h; `#import "TSMessage.h"` and `"TSMessageView.h"` in MMAIViewController.m, BoardViewController.m and DatabaseViewController.m; and the commented TSMessageView line in the bridging header. Add `#import "PenteBanner.h"` wherever it's needed.
3. Update comments that mention TSMessage behaviour to name PenteBanner, e.g. the AppDelegate nil-nav guard comment about the keyWindow fallback. Keep the guard itself.
4. Remove `pod 'TSMessages', :git => ...` from the Podfile using the procedure above. HexColors must disappear from Podfile.lock.

**Done when:**
- Case-sensitive greps for `TSMessage` and `HexColors` outside `Pods/` and `docs/` are empty; `.idea/` IDE state is exempt.
- Both builds succeed with 1 app warning, and the app launches on both.
- The report lists every call site as file:line, old to new.
