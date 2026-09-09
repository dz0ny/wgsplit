import XCTest
@testable import WGSplitKit

final class HealthConfigTests: XCTestCase {
    private func makeState() -> AppState {
        let t = Tunnel(name: "n", privateKey: "gON0LRZdL1VesfWguWM6O3BQwRyvxw1o/ITJXCMcEUI=",
                       addresses: ["10.212.4.7/32"], dns: ["1.1.1.1"], mtu: nil,
                       peerPublicKey: "l4NqMyz/Qw8lFMJfCqBrT00UUoGYPClKlMKDi4OOaUY=",
                       peerPresharedKey: nil, endpointHost: "193.122.15.126",
                       endpointPort: 443, persistentKeepalive: 25)
        return AppState(tunnels: [t], rules: [Rule(pattern: "*.niteo.co")],
                     activeTunnelID: t.id, enabled: true)
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    func testClashApiOmittedWhenNotConfigured() throws {
        let config = try object(ConfigGenerator.generate(state: makeState()))
        XCTAssertNil(config["experimental"])
    }

    func testClashApiBindsLoopbackWithSecret() throws {
        let api = ClashAPI(port: 19090, secret: "s3cr3t")
        let config = try object(ConfigGenerator.generate(state: makeState(), clashAPI: api))
        let experimental = config["experimental"] as! [String: Any]
        let clash = experimental["clash_api"] as! [String: Any]
        XCTAssertEqual(clash["external_controller"] as? String, "127.0.0.1:19090")
        XCTAssertEqual(clash["secret"] as? String, "s3cr3t")
    }

    func testGeneratedClashAPIKeyIsRandomAndLoopbackOnly() {
        let a = ClashAPI.random(), b = ClashAPI.random()
        XCTAssertNotEqual(a.secret, b.secret)
        XCTAssertGreaterThanOrEqual(a.port, 20000)
        XCTAssertLessThan(a.port, 65535)
        XCTAssertGreaterThanOrEqual(a.secret.count, 32)
    }

    func testConfigWithClashAPIStillPassesSingBoxCheck() throws {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir = dir.deletingLastPathComponent() }
        let binary = dir.appendingPathComponent("Resources/sing-box")
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: binary.path))

        let path = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("clash-\(UUID().uuidString).json")
        try ConfigGenerator.generate(state: makeState(), clashAPI: .random()).write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }

        let p = Process()
        p.executableURL = binary
        p.arguments = ["check", "-c", path.path]
        let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
        try p.run()
        let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "sing-box rejected clash_api config:\n\(msg)")
    }
}
