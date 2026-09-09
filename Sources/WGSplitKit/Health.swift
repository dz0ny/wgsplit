import Foundation

/// What the menu can honestly claim. None of these is WireGuard handshake
/// state — sing-box exposes no such query — so `running` means "up, but no
/// traffic has gone through the tunnel yet", which is absence of evidence
/// rather than a diagnosed fault.
public enum Health: String, Codable, Equatable, Sendable {
    case stopped
    case running
    case active
}

/// Credentials for sing-box's clash_api. Bound to loopback with a random
/// port and secret, generated once and persisted 0600 beside state.json so a
/// rollback to last-known-good config keeps working credentials.
public struct ClashAPI: Codable, Equatable, Sendable {
    public var port: Int
    public var secret: String

    public init(port: Int, secret: String) {
        self.port = port; self.secret = secret
    }

    public static func random() -> ClashAPI {
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return ClashAPI(port: Int.random(in: 20000..<65000),
                        secret: Data(bytes).base64EncodedString())
    }
}
