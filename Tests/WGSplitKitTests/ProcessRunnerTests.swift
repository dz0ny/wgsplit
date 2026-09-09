import XCTest
@testable import WGSplitKit

final class ProcessRunnerTests: XCTestCase {
    func testCheckThrowsWhenBinaryExitsNonZero() throws {
        let runner = ProcessRunner(binary: URL(fileURLWithPath: "/usr/bin/false"))
        XCTAssertThrowsError(try runner.check(configPath: URL(fileURLWithPath: "/tmp/x.json")))
    }

    func testCheckSucceedsWhenBinaryExitsZero() throws {
        let runner = ProcessRunner(binary: URL(fileURLWithPath: "/usr/bin/true"))
        XCTAssertNoThrow(try runner.check(configPath: URL(fileURLWithPath: "/tmp/x.json")))
    }

    func testStartReturnsRunningHandleAndTerminates() throws {
        let runner = ProcessRunner(binary: URL(fileURLWithPath: "/bin/sleep"),
                                   startArguments: { _ in ["30"] })
        let handle = try runner.start(configPath: URL(fileURLWithPath: "/tmp/x.json"))
        XCTAssertTrue(handle.isRunning)
        handle.terminate()
        XCTAssertFalse(handle.isRunning)
    }
}
