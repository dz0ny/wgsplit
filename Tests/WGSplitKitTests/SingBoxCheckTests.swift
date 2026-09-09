import XCTest
@testable import WGSplitKit

/// Pipes generated config through the real pinned sing-box binary.
/// This is the test that catches a version bump breaking the config schema.
final class SingBoxCheckTests: XCTestCase {
    private var binary: URL? {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir = dir.deletingLastPathComponent() }
        let url = dir.appendingPathComponent("Resources/sing-box")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    func testGeneratedConfigPassesSingBoxCheck() throws {
        guard let binary else {
            throw XCTSkip("Resources/sing-box missing — run Scripts/vendor-singbox.sh")
        }
        let t = Tunnel(name: "Niteo DE", privateKey: "gON0LRZdL1VesfWguWM6O3BQwRyvxw1o/ITJXCMcEUI=",
                       addresses: ["10.212.4.7/32"], dns: ["1.1.1.1"], mtu: nil,
                       peerPublicKey: "l4NqMyz/Qw8lFMJfCqBrT00UUoGYPClKlMKDi4OOaUY=",
                       peerPresharedKey: nil, endpointHost: "193.122.15.126",
                       endpointPort: 443, persistentKeepalive: 25)
        let state = State(tunnels: [t],
                          rules: [Rule(pattern: "*.niteo.co"), Rule(pattern: "*.herokuapp.com")],
                          activeTunnelID: t.id, enabled: true)

        let path = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wgsplit-\(UUID().uuidString).json")
        try ConfigGenerator.generate(state: state).write(to: path)
        defer { try? FileManager.default.removeItem(at: path) }

        let p = Process()
        p.executableURL = binary
        p.arguments = ["check", "-c", path.path]
        let err = Pipe(); p.standardError = err; p.standardOutput = Pipe()
        try p.run()
        let message = String(data: err.fileHandleForReading.readDataToEndOfFile(),
                             encoding: .utf8) ?? ""
        p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0, "sing-box check rejected config:\n\(message)")
    }
}
