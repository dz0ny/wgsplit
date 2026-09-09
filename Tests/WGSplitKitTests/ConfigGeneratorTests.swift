import XCTest
@testable import WGSplitKit

final class ConfigGeneratorTests: XCTestCase {
    private func makeState(dns: [String] = ["1.1.1.1"]) -> AppState {
        let t = Tunnel(name: "Niteo DE", privateKey: "cHJpdg==",
                       addresses: ["10.212.4.7/32"], dns: dns, mtu: nil,
                       peerPublicKey: "cHViCg==", peerPresharedKey: "cHNrCg==",
                       endpointHost: "193.122.15.126", endpointPort: 443,
                       persistentKeepalive: 25)
        return AppState(tunnels: [t], rules: [Rule(pattern: "*.niteo.co")],
                     activeTunnelID: t.id, enabled: true)
    }

    private func object(_ state: AppState) throws -> [String: Any] {
        let data = try ConfigGenerator.generate(state: state)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func testDnsDirectHasNoDetour() throws {
        let dns = try object(makeState())["dns"] as! [String: Any]
        let servers = dns["servers"] as! [[String: Any]]
        let direct = servers.first { $0["tag"] as? String == "dns-direct" }!
        XCTAssertNil(direct["detour"])
    }

    func testDefaultDomainResolverPresent() throws {
        let route = try object(makeState())["route"] as! [String: Any]
        XCTAssertNotNil(route["default_domain_resolver"])
    }

    func testRouteRuleOrderIsSniffThenHijackThenDomains() throws {
        let route = try object(makeState())["route"] as! [String: Any]
        let rules = route["rules"] as! [[String: Any]]
        XCTAssertEqual(rules[0]["action"] as? String, "sniff")
        XCTAssertEqual(rules[1]["action"] as? String, "hijack-dns")
        XCTAssertEqual(rules[2]["outbound"] as? String, "wg-out")
        XCTAssertEqual(rules[2]["domain_suffix"] as? [String], [".niteo.co"])
        XCTAssertEqual(route["final"] as? String, "direct")
    }

    func testEndpointAlwaysUsesDefaultRoute() throws {
        let endpoints = try object(makeState())["endpoints"] as! [[String: Any]]
        let peer = (endpoints[0]["peers"] as! [[String: Any]])[0]
        XCTAssertEqual(peer["allowed_ips"] as? [String], ["0.0.0.0/0"])
        XCTAssertEqual(peer["address"] as? String, "193.122.15.126")
        XCTAssertEqual(peer["port"] as? Int, 443)
    }

    func testTunnelDnsServerOmittedWhenConfHasNoDNS() throws {
        let dns = try object(makeState(dns: []))["dns"] as! [String: Any]
        let servers = dns["servers"] as! [[String: Any]]
        XCTAssertNil(servers.first { $0["tag"] as? String == "dns-wg" })
        XCTAssertTrue((dns["rules"] as! [[String: Any]]).isEmpty)
    }

    func testNoActiveTunnelThrows() {
        var s = makeState(); s.activeTunnelID = nil
        XCTAssertThrowsError(try ConfigGenerator.generate(state: s)) {
            XCTAssertEqual($0 as? GeneratorError, .noActiveTunnel)
        }
    }
}
