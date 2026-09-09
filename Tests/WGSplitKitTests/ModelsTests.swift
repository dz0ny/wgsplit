import XCTest
@testable import WGSplitKit

final class ModelsTests: XCTestCase {
    func testStateRoundTripsThroughJSON() throws {
        let tunnel = Tunnel(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Niteo DE", privateKey: "cHJpdg==", addresses: ["10.212.4.7/32"],
            dns: ["1.1.1.1"], mtu: nil, peerPublicKey: "cHViCg==",
            peerPresharedKey: "cHNrCg==", endpointHost: "193.122.15.126",
            endpointPort: 443, persistentKeepalive: 25)
        let state = AppState(tunnels: [tunnel], rules: [Rule(pattern: "*.niteo.co")],
                          activeTunnelID: tunnel.id, enabled: true)
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(AppState.self, from: data), state)
    }

    func testEmptyStateHasNoActiveTunnel() {
        XCTAssertNil(AppState.empty.activeTunnelID)
        XCTAssertFalse(AppState.empty.enabled)
    }
}
