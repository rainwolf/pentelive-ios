//
//  DBSetupViewKeyTests.m
//  PenteEngineTests
//
//  The Type row of the database setup list must read the NSUserDefaults key
//  that DatabaseViewController writes ("DBLiveOrTB").
//

#import <XCTest/XCTest.h>

// DBSetupView.h pulls in penteLive-Swift.h, which is not on this target's
// header search path. The test is hosted in the app, so the class links at
// runtime; declare just what the test uses.
@interface DBSetupView : UITableView <UITableViewDataSource>
@end

@interface DBSetupViewKeyTests : XCTestCase
@end

@implementation DBSetupViewKeyTests

- (void)tearDown {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DBLiveOrTB"];
    [super tearDown];
}

- (void)testTypeCellReadsSavedLiveOrTB {
    [[NSUserDefaults standardUserDefaults] setObject:@"live only"
                                              forKey:@"DBLiveOrTB"];
    DBSetupView *view =
        [[DBSetupView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
    UITableViewCell *cell =
        [view tableView:view
            cellForRowAtIndexPath:[NSIndexPath indexPathForRow:11
                                                     inSection:0]];
    XCTAssertEqualObjects(cell.textLabel.text, @"Type");
    XCTAssertEqualObjects(cell.detailTextLabel.text, @"live only");
}

@end
