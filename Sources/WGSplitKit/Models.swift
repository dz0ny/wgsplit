import Foundation

public struct Tunnel: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var privateKey: String
    public var addresses: [String]
    public var dns: [String]
    public var mtu: Int?
    public var peerPublicKey: String
    public var peerPresharedKey: String?
    public var endpointHost: String
    public var endpointPort: Int
    public var persistentKeepalive: Int?

    public init(id: UUID = UUID(), name: String, privateKey: String, addresses: [String],
                dns: [String], mtu: Int?, peerPublicKey: String, peerPresharedKey: String?,
                endpointHost: String, endpointPort: Int, persistentKeepalive: Int?) {
        self.id = id; self.name = name; self.privateKey = privateKey
        self.addresses = addresses; self.dns = dns; self.mtu = mtu
        self.peerPublicKey = peerPublicKey; self.peerPresharedKey = peerPresharedKey
        self.endpointHost = endpointHost; self.endpointPort = endpointPort
        self.persistentKeepalive = persistentKeepalive
    }
}

public struct Rule: Codable, Equatable, Sendable {
    public var pattern: String
    public init(pattern: String) { self.pattern = pattern }
}

public struct AppState: Codable, Equatable, Sendable {
    public var tunnels: [Tunnel]
    public var rules: [Rule]
    public var activeTunnelID: UUID?
    public var enabled: Bool

    public init(tunnels: [Tunnel], rules: [Rule], activeTunnelID: UUID?, enabled: Bool) {
        self.tunnels = tunnels; self.rules = rules
        self.activeTunnelID = activeTunnelID; self.enabled = enabled
    }

    public static let empty = AppState(tunnels: [], rules: [], activeTunnelID: nil, enabled: false)

    public var activeTunnel: Tunnel? {
        guard let id = activeTunnelID else { return nil }
        return tunnels.first { $0.id == id }
    }
}
