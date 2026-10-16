import XCTest
@testable import penteLive

/// Spec 4 GET JSON, 7.1 StoreInfo parsing (missing / null / wrong-typed fields).
final class StoreInfoTests: XCTestCase {
    private let token = "6fa459ea-ee8a-3ca4-894e-db77e160355e"

    private func parse(_ json: String, user: String = "IOSTest") -> StoreInfo? {
        StoreInfo.parse(Data(json.utf8), username: user)
    }

    func testFullServerBody() throws {
        let info = try XCTUnwrap(parse(#"{"appAccountToken":"\#(token)","subscribedUntil":1791000000000,"hasActiveAppleSubscription":true,"vacationAllowed":false,"vacationDaysLeft":7,"products":["1YRNOADSORLIMITS","month_pass","vacation_10","vacation_30","vacation_60"]}"#))
        XCTAssertEqual(info.username, "iostest")
        XCTAssertEqual(info.appAccountToken, UUID(uuidString: token))
        XCTAssertEqual(info.subscribedUntil, Date(timeIntervalSince1970: 1_791_000_000))
        XCTAssertTrue(info.hasActiveAppleSubscription)
        XCTAssertEqual(info.vacationDaysLeft, 7)
        XCTAssertEqual(info.products, ["1YRNOADSORLIMITS", "month_pass", "vacation_10", "vacation_30", "vacation_60"])
    }

    func testNullAndMissingFieldsFallBack() throws {
        let info = try XCTUnwrap(parse(#"{"appAccountToken":"\#(token)","subscribedUntil":null,"products":null}"#))
        XCTAssertNil(info.subscribedUntil)
        XCTAssertFalse(info.hasActiveAppleSubscription)
        XCTAssertEqual(info.vacationDaysLeft, 0)
        XCTAssertEqual(info.products, [])
    }

    func testWrongTypedFieldsFallBack() throws {
        let info = try XCTUnwrap(parse(#"{"appAccountToken":"\#(token)","subscribedUntil":"1791000000000","hasActiveAppleSubscription":"true","vacationDaysLeft":"7","products":["month_pass",3,null,{"id":"x"},true]}"#))
        XCTAssertNil(info.subscribedUntil)
        XCTAssertFalse(info.hasActiveAppleSubscription)
        XCTAssertEqual(info.vacationDaysLeft, 0)
        XCTAssertEqual(info.products, ["month_pass"])
    }

    func testBooleansAreNotNumbersAndNumbersAreNotBooleans() throws {
        let info = try XCTUnwrap(parse(#"{"appAccountToken":"\#(token)","subscribedUntil":true,"hasActiveAppleSubscription":1,"vacationDaysLeft":false}"#))
        XCTAssertNil(info.subscribedUntil)
        XCTAssertFalse(info.hasActiveAppleSubscription)
        XCTAssertEqual(info.vacationDaysLeft, 0)
    }

    func testNegativeAndHugeVacationDaysAreClamped() {
        XCTAssertEqual(parse(#"{"appAccountToken":"\#(token)","vacationDaysLeft":-3}"#)?.vacationDaysLeft, 0)
        XCTAssertEqual(parse(#"{"appAccountToken":"\#(token)","vacationDaysLeft":1e300}"#)?.vacationDaysLeft, 100_000)
        XCTAssertEqual(parse(#"{"appAccountToken":"\#(token)","vacationDaysLeft":12.9}"#)?.vacationDaysLeft, 12)
    }

    func testNoUsableTokenIsNoInfo() {
        XCTAssertNil(parse("{}"))
        XCTAssertNil(parse(#"{"appAccountToken":null}"#))
        XCTAssertNil(parse(#"{"appAccountToken":"not-a-uuid"}"#))
        XCTAssertNil(parse(#"{"appAccountToken":42}"#))
        XCTAssertNil(parse("[]"))
        XCTAssertNil(parse("<html><body>Please log in</body></html>"))
        XCTAssertNil(parse(""))
    }

    func testVacationAllowedIsIgnored() {
        XCTAssertEqual(parse(#"{"appAccountToken":"\#(token)","vacationAllowed":false,"vacationDaysLeft":5}"#),
                       parse(#"{"appAccountToken":"\#(token)","vacationAllowed":true,"vacationDaysLeft":5}"#))
    }
}
