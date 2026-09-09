import XCTest
@testable import WGSplitKit

final class ControlProtocolTests: XCTestCase {
    func testEveryRequestCaseRoundTrips() throws {
        let tunnel = Tunnel(name: "n", privateKey: "k", addresses: ["10.0.0.2/32"],
                            dns: [], mtu: nil, peerPublicKey: "p", peerPresharedKey: nil,
                            endpointHost: "h", endpointPort: 1, persistentKeepalive: nil)
        let cases: [ControlRequest] = [
            .status, .importTunnel(tunnel), .setActiveTunnel(tunnel.id),
            .setActiveTunnel(nil), .setRules([Rule(pattern: "*.niteo.co")]), .setEnabled(true),
        ]
        for c in cases {
            let line = try ControlCodec.encode(c)
            XCTAssertFalse(line.dropLast().contains(0x0A), "payload must not contain newlines")
            XCTAssertEqual(try ControlCodec.decode(ControlRequest.self, from: line), c)
        }
    }

    func testStatusNeverCarriesPrivateKeys() throws {
        let tunnel = Tunnel(name: "n", privateKey: "SUPERSECRETKEY", addresses: ["10.0.0.2/32"],
                            dns: [], mtu: nil, peerPublicKey: "p", peerPresharedKey: "PSKSECRET",
                            endpointHost: "h", endpointPort: 1, persistentKeepalive: nil)
        let state = State(tunnels: [tunnel], rules: [], activeTunnelID: tunnel.id, enabled: false)
        let status = Status(state: state, running: false, lastError: nil)
        let json = String(data: try ControlCodec.encode(ControlResponse.status(status)),
                          encoding: .utf8)!
        XCTAssertFalse(json.contains("SUPERSECRETKEY"))
        XCTAssertFalse(json.contains("PSKSECRET"))
        XCTAssertTrue(json.contains("\"name\":\"n\""))
    }
}
