import XCTest
@testable import WGSplitKit

final class ControlClientTests: XCTestCase {
    func testRoundTripsAgainstARealSocketServer() throws {
        let path = "/tmp/wgsplit-test-\(UUID().uuidString).sock"
        var received: ControlRequest?

        let server = SocketServer(path: path) { line in
            received = try? ControlCodec.decode(ControlRequest.self, from: line)
            let status = Status(state: .empty, running: true, lastError: nil)
            return (try? ControlCodec.encode(ControlResponse.status(status))) ?? Data()
        }
        let fd = try server.bindAndListen()
        defer { close(fd); unlink(path) }

        let thread = Thread { server.serveOnce(fd) }
        thread.start()

        let response = try ControlClient(path: path).send(.setEnabled(true))
        guard case .status(let status) = response else { return XCTFail("expected status") }
        XCTAssertTrue(status.running)
        XCTAssertEqual(received, .setEnabled(true))
    }

    func testMissingDaemonReportsUnavailable() {
        let client = ControlClient(path: "/tmp/wgsplit-absent-\(UUID().uuidString).sock")
        XCTAssertThrowsError(try client.send(.status)) {
            XCTAssertEqual($0 as? ControlClientError, .daemonUnavailable)
        }
    }
}
