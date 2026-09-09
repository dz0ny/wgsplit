import XCTest
@testable import WGSplitKit

final class ClashClientTests: XCTestCase {
    private func json(_ chains: [[String]]) -> Data {
        let conns = chains.map { ["id": UUID().uuidString, "chains": $0] as [String: Any] }
        return try! JSONSerialization.data(withJSONObject:
            ["downloadTotal": 0, "uploadTotal": 0, "connections": conns])
    }

    func testTrafficThroughTunnelIsActive() throws {
        XCTAssertTrue(ClashClient.sawTunnelTraffic(in: json([["wg-out"]])))
    }

    func testTunnelAnywhereInChainCounts() throws {
        XCTAssertTrue(ClashClient.sawTunnelTraffic(in: json([["tun-in", "wg-out"]])))
    }

    func testOnlyDirectTrafficIsNotActive() throws {
        XCTAssertFalse(ClashClient.sawTunnelTraffic(in: json([["direct"], ["tun-in", "direct"]])))
    }

    func testNoConnectionsIsNotActive() throws {
        XCTAssertFalse(ClashClient.sawTunnelTraffic(in: json([])))
    }

    func testGarbageIsNotActive() throws {
        XCTAssertFalse(ClashClient.sawTunnelTraffic(in: Data("nonsense".utf8)))
    }
}
