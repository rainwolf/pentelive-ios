# Pod replacements: P1 (minus NSHash), P3, P6, P8

Branch `replace-pods`, one commit series and one PR. The spec is the owner's request of 2026-09-29: "do P1 but keep nshash, P3, P6, P8", read against the triage ranking. That ranking is stored in memory as `pod-replacement-triage`. The preference is native code over replacement pods, and every change must work on iPhone and iPad.

## Global Constraints

- **Build:** `xcodebuild -workspace penteLive.xcworkspace -scheme test1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' SWIFT_ENABLE_EXPLICIT_MODULES=NO build`
  - Always pin `-scheme test1` and confirm `penteLive.app` was produced.
  - Also build for `-destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'`.
- **Launch check:** after each task, launch on the iPhone 17 and iPad Pro 13-inch (M5) simulators and confirm liveness.
  - `xcrun simctl bootstatus <udid> -b`, then install, launch `be.submanifold.penteLive`, and check `launchctl list`.
  - Take a screenshot to catch a black screen.
- **Warnings:** app-target warnings must stay at 1, the kept `application:didReceiveRemoteNotification:`. Pods warnings are out of scope.
- **Pod removal procedure:**
  1. Delete the Podfile line and run `pod install`.
  2. Inspect `git diff penteLive.xcodeproj/project.pbxproj`. `pod install` churns the xcconfig `baseConfigurationReference` UUIDs. Revert that churn, keeping only hunks that genuinely belong to the removed pod. If the diff is only churn, run `git checkout -- penteLive.xcodeproj/project.pbxproj`.
  3. Commit the `Podfile`, `Podfile.lock` and `test1/Settings.bundle/Acknowledgements.plist` changes (post_install regenerates that file).
  4. Delete any stray `_Users_*.swiftpm.lock` in the repo root.
  5. `Pods/` is git-ignored.
- **Never accept Xcode's "Update to recommended settings".** Never change the deployment target (iOS 15.0).
- **Keep the NSHash pod** (owner decision) and its import in `BoardViewController.m`. Do not touch TSMessages, UIBarButtonItem-Badge, AFWebViewController, CocoaAsyncSocket or InAppSettingsKit.
- **Match surrounding ObjC style.** New app classes go in `test1/` and are registered in the `penteLive` app target only. Run `xcrun clang-format -i` on new or touched ObjC files only if the repo's `.clang-format` applies. Don't reformat untouched code.
- **Scratch and derived data go outside the repo:** `TMPDIR=/private/tmp/claude-501/pods-replace`.
- **Commits:** no Co-Authored-By or generated-by lines.
- **No behavior beyond what each task states.** No refactors of adjacent code.

### Task 1: Replace ICDMaterialActivityIndicatorView with a native overlay

**Model:** sonnet

Sites: there are 4 identical alloc sites.
- `test1/GamesTableViewController.m` ~171
- `test1/SettingsViewController.m` ~760 and ~968
- `test1/DatabaseViewController.m` ~250

Each creates `initWithFrame:(view bounds) activityIndicatorStyle:Large`, sets a white background with alpha 0.75, calls `startAnimating` and `addSubview`, and later `stopAnimating` and `removeFromSuperview`. The properties or ivars are declared in `GamesTableViewController.h`, `SettingsViewController.h` and `DatabaseViewController.h`.

1. Add `test1/PenteSpinnerOverlay.h/.m`: `@interface PenteSpinnerOverlay : UIView` with `-initWithFrame:`, `-startAnimating` and `-stopAnimating`.
   - The view is a full-size white overlay with alpha 0.75.
   - It centres a `UIActivityIndicatorView` in style `UIActivityIndicatorViewStyleLarge`.
   - Set `autoresizingMask` to flexible width and height so it still covers the screen after rotation.
   - It blocks touches like the old view did.
2. Replace every ICD use with `PenteSpinnerOverlay`, keeping each call site's existing start, stop and remove sequence. Keep any other property settings only if they still make sense. Remove the ICD imports.
3. Remove the pod using the procedure above.

**Done when:** a grep for `ICDMaterialActivityIndicatorView` outside `Pods/` is empty, both simulator builds succeed with 1 app warning, and the app launches on both.

### Task 2: Replace Color-Picker-for-iOS and UIColor+Hex with UIColorPickerViewController

**Model:** sonnet

Current state:
- `test1/SettingsViewController.m` ~559-568 pushes `ChangeColorViewController`. This is subscriber-gated.
- `test1/ChangeColorViewController.m` ~37-57 embeds `HRColorPickerView`.
- In `viewWillDisappear` (~61-93), it reads the colour and computes `[color cssString]` with the leading `#` dropped.
- It then POSTs `changeNameColor=<hex>` to `/gameServer/changeColor` and sets `player.myColor` on success, showing an alert on failure.
- UIColor+Hex is used only for `-cssString`, at ChangeColorViewController.m:64.

1. Replace the push with a modal `UIColorPickerViewController`.
   - `supportsAlpha = NO`.
   - `selectedColor` is the current `player.myColor`, or the same default the old screen used.
   - On iPad it must present sanely: use the default modal style, or a popover anchored to the Settings row with adaptive style none.
   - It must dismiss correctly.
2. Save once, in `colorPickerViewControllerDidFinish:`, and only if the selected colour differs from the initial one. Never POST from `didSelectColor:continuously:`. Keep the request, success and failure handling byte-identical: same URL, same body key, `player.myColor` set only on success, and the failure alert via `PenteAlert`.
3. Hex conversion:
   - Add a small static helper that converts the colour to sRGB, dropping alpha. Use `CGColorCreateCopyByMatchingToColorSpace` with `kCGColorSpaceSRGB`, and clamp components to 0...1.
   - Format it exactly as the old `cssString`-minus-`#` did: same letter case, same rounding, 6 digits.
   - Read `Pods/UIColor+Hex/UIColor/*.m` `-cssString` (~line 138) **before** removing the pod, and mirror its format and rounding.
4. Delete `ChangeColorViewController` if nothing else uses it: remove it from the project and target. Otherwise shrink it to the delegate/coordinator. Choose whichever is the smaller, clearer diff and say which one in the report.
5. Remove both pods, `Color-Picker-for-iOS` and `UIColor+Hex`, using the procedure above.

**Done when:** greps for `HRColor`, `cssString` and `UIColor+Hex` outside `Pods/` are empty, both builds succeed with 1 app warning, and the app launches on both simulators.
- Include in the report a table of 5 colours and their hex: black, white, mid-grey, pure red, and one P3-ish colour. Each row shows old `cssString` output against the new helper's output, from a throwaway check run in scratch before the pod was removed. Old and new must match for sRGB colours.

### Task 3: Replace RMStore with a native StoreKit 2 wrapper

**Model:** opus

Current state:
- **One product:** `1YRNOADSORLIMITS`, a yearly auto-renewable subscription. Entitlement is owned by the server; the app only uploads the receipt.
- **Product request** (`test1/AppDelegate.m` ~162-178): `[[RMStore defaultStore] requestProducts:...]`. The result is stored in `PenteNavigationViewController.subscription`, typed `SKProduct` at `PenteNavigationViewController.h:24/34`.
- **Retry at launch** (`AppDelegate.m` ~180-260): re-POSTs the receipt while NSUserDefaults `shouldSendReceipt` is YES.
- **Price display** (`test1/SettingsViewController.m` ~629-640): formats `price` with `priceLocale`.
- **Purchase** (`SettingsViewController.m` ~798): `addPayment:`. Success sets `shouldSendReceipt=YES`, base64-encodes `appStoreReceiptURL` data and POSTs it to `https://www.pente.org/gameServer/iOSReceiptValidation`. Failure shows a TSMessage with `localizedFailureReason`.
- **Restore** (`SettingsViewController.m` ~980): `restoreTransactionsOnSuccess:` does the same receipt POST, even when there were no transactions.
- **Transaction observer:** RMStore registers as the observer on first use and finishes every transaction immediately, including silent renewals at launch.
- **Where RMStore is referenced:** there are imports or references in `AppDelegate.m:14`, `SettingsViewController.m:15` and `test1/penteLive-Bridging-Header.h`.

1. Add `test1/SubscriptionStore.swift`: `@objc final class SubscriptionStore: NSObject` with `@objc static let shared`. It exposes to ObjC:
   - `@objc func start()`: called once from `application:didFinishLaunchingWithOptions:`. It starts a detached `Transaction.updates` listener that calls `finish()` on every transaction, verified or not, matching RMStore finishing everything. It logs unverified ones.
   - `@objc func loadProduct(completion: @escaping (SubscriptionProduct?, NSError?) -> Void)`. `SubscriptionProduct` is an `@objc final class` exposing `productID` and `displayPrice` (String). `Product.products(for:)` is keyed on `1YRNOADSORLIMITS`.
   - `@objc func purchase(completion: @escaping (SubscriptionPurchaseResult, NSError?) -> Void)`. `@objc enum SubscriptionPurchaseResult: Int` has the cases `purchased`, `cancelled`, `pending` and `failed`.
     - `.success(.verified)` → finish, then return `purchased`.
     - `.success(.unverified)` → finish, then return `failed` with an error.
     - `.userCancelled` → `cancelled`.
     - `.pending` → `pending`.
     - A thrown error → `failed`.
   - `@objc func restore(completion: @escaping (NSError?) -> Void)`: `try await AppStore.sync()`.
   - Every completion is delivered on the main queue.
2. `PenteNavigationViewController.subscription` becomes `SubscriptionProduct *`. Update the declaration, and include the generated Swift header where needed, the way other ObjC files already import `penteLive-Swift.h`. The price label uses `displayPrice` and keeps the existing surrounding copy.
3. Rewire the ObjC call sites.
   - **Launch:** product load plus `start()`.
   - **Purchase:**
     - `purchased` → the existing success block.
     - `cancelled` → remove the spinner and the subscribing state quietly, with no error banner.
     - `pending` → remove the spinner and show an informational TSMessage saying the purchase is pending approval. Use the same TSMessage call shape already used nearby.
     - `failed` → the existing failure banner, using `error.localizedDescription` when `localizedFailureReason` is nil.
   - **Restore:** sync, then the existing receipt POST, with ordering and messages unchanged.
   - The receipt POST code itself does not change. That includes the `shouldSendReceipt` flag, the URL and the body.
4. Remove RMStore from the Podfile and the bridging header (procedure above). Add `StoreKit.framework` linkage only if the build requires it.
5. Leave these alone:
   - the `subscribing` ivar semantics, apart from resetting it on cancel/pending/failed where the old failure block did
   - the triplicated receipt-POST code
   - the server contract

**Done when:** a grep for `RMStore` outside `Pods/` is empty, both builds succeed with 1 app warning, the app launches on both simulators, and the report includes:
- A simulator smoke check that `loadProduct` runs without crashing at launch. It will return nil or an error without a StoreKit config, which is fine; say what you saw.
- A device checklist for the owner covering sandbox purchase, cancel, restore with and without a purchase, and Ask-to-Buy pending.

### Task 4: PentePopover helper and migration of the ObjC PopoverView sites

**Model:** opus

PopoverView (runway20) is a full-window overlay. It calls `popoverViewDidDismiss:` on both tap-outside and programmatic dismiss, and its dismiss is a plain view animation, so callers push or present immediately afterwards.

1. Add `test1/PentePopover.h/.m`, an ObjC `NSObject` that also works from Swift through the bridging header, wrapping `UIPopoverPresentationController`.
   - `+ (instancetype)showContentView:(UIView *)content title:(nullable NSString *)title atPoint:(CGPoint)point inView:(UIView *)view onDismiss:(nullable void (^)(void))onDismiss;`
   - `+ (instancetype)showViews:(NSArray<UIView *> *)views title:(nullable NSString *)title atPoint:(CGPoint)point inView:(UIView *)view onDismiss:(nullable void (^)(void))onDismiss;` stacks views vertically, as PopoverView's `withViewArray` did.
   - `- (void)dismiss;` and `- (void)dismissWithCompletion:(nullable void (^)(void))completion;` animate, then run `onDismiss` exactly once, then `completion`. Callers that navigate after dismiss must put the navigation in `completion`.
   - Tap-outside dismissal also runs `onDismiss` exactly once, via `presentationControllerDidDismiss:`.
   - `@property (readonly) BOOL isPresented;`
   - **Presenter:** the nearest view controller of `view` via the responder chain, then walk up to its topmost `presentedViewController`.
   - **Anchor:** `sourceView = view`, `sourceRect = {point, 1x1}`.
   - **Style:** `adaptivePresentationStyleForPresentationController:` returns `UIModalPresentationNone` on iPhone and iPad. Use its own delegate, not a shared one, because `TableViewController` returns NO from `popoverPresentationControllerShouldDismissPopover`. Set `overrideUserInterfaceStyle = UIUserInterfaceStyleLight` on the content VC, since the content uses hardcoded black text.
   - **Size:** `preferredContentSize` comes from the content frame, plus the title label height if there is a title. Don't rescale content.
   - Keep the instance alive while presented.
   - **Anchoring on `self.view`:** callers pass their `self.view`. If a caller passes a view whose VC is not in a window, the helper logs and returns nil, and callers must tolerate nil.
2. Migrate every ObjC presentation and dismiss site to `PentePopover`, carrying each `popoverViewDidDismiss:` body into that site's `onDismiss` block:
   - `GamesTableViewController.m`: showStats, showOnlinePlayers, and the two nav-bar `withViewArray` menus with their `UIButton+Badge` items. Keep the badges; they come from the UIBarButtonItem-Badge pod, which stays.
   - `BoardViewController.m`: messageTap, 4 branches. The reply text view becomes first responder after presentation.
   - `DatabaseViewController.m`: showSetup and askAI.
   - `MMAIViewController.m`: showSetup.
   - `KOTHTableViewController.m`: challenge, open challenge, and the dismiss in `viewWillDisappear`.
   - `KOTHChallengeView.m`, `SettingsViewController.m` (the subscribe sheet `withTitle:withViewArray:` built from 5 labels and a button), `RatingStatsView.m` and `WhosOnlineView.m`.
   - The `PickerInputTableViewCell` iPad popover must still stack on top.
3. Wherever the old code dismissed and then pushed, segued or presented, move that navigation into the `dismissWithCompletion:` block. Examples: GamesTVC menu items including `toDatabase` and its subscribers-only alert, row taps in RatingStatsView and WhosOnlineView, the KOTH challenge send, and DB start-AI. Delete the `[popover layoutSubviews]` workaround calls.
4. Don't remove the pod in this task. Swift sites are Task 5.

**Done when:** no ObjC `.h` or `.m` file outside `Pods/` references `PopoverView`. That includes `PopoverViewDelegate` conformances and imports in ObjC headers; the bridging header is left for Task 5. Both builds succeed with 1 app warning, and the app launches on both simulators.
- The report lists every site with its old and new dismissal side effect.
- The report includes a simulator smoke run that opens at least the Games stats popover and dismisses it by tap-outside. Use lldb injection or a UI test in scratch if a login is needed; say what was possible.

### Task 5: Migrate the Swift PopoverView sites and remove the pod

**Model:** sonnet

1. `test1/TableViewController.swift` ~445, ~541 and ~1393 (showSettings, showTablePlayers, and the dismiss), `test1/RoomViewController.swift` ~513 (createArenaTable) and `test1/ArenaTableSetupView.swift` ~306 (dismiss then update): switch to `PentePopover`. Navigation after dismiss goes in the completion.
2. Remove the `PopoverViewDelegate` conformances and the unused `popoverView` property in `ArenaJoinRequestList.swift`. Remove the dead imports in `InvitationsViewController.h/.m`.
3. Update the comment in `test1/PenteAlert.m` that mentions PopoverView's keyWindow resolution (~186) if it no longer holds.
4. Remove the PopoverView pod and the `@import`/`#import` in the bridging header, using the procedure above.

**Done when:** a case-sensitive grep for `PopoverView` outside `Pods/` and `docs/` is empty, both builds succeed with 1 app warning, and the app launches on both simulators.
