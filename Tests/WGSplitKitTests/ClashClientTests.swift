import XCTest
@testable import WGSplitKit

final class ClashClientTests: XCTestCase {
    func testParsesDelayOnSuccess() {
        let body = Data(#"{"delay":142}"#.utf8)
        XCTAssertEqual(ClashClient.parseDelay(body, statusCode: 200), 142)
    }

    func testTimeoutReportsNoDelay() {
        // 504 is what sing-box returns when the probe cannot reach the target
        // through the outbound — i.e. the tunnel is not carrying traffic.
        let body = Data(#"{"message":"An error occurred in the delay test"}"#.utf8)
        XCTAssertNil(ClashClient.parseDelay(body, statusCode: 504))
    }

    func testGarbageBodyReportsNoDelay() {
        XCTAssertNil(ClashClient.parseDelay(Data("nonsense".utf8), statusCode: 200))
    }

    func testMissingDelayFieldReportsNoDelay() {
        XCTAssertNil(ClashClient.parseDelay(Data(#"{"ok":true}"#.utf8), statusCode: 200))
    }
}
