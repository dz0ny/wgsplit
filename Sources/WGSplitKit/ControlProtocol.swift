import Foundation

public enum ControlRequest: Codable, Equatable, Sendable {
    case status
    case importTunnel(Tunnel)
    case setActiveTunnel(UUID?)
    case setRules([Rule])
    case setEnabled(Bool)
}

/// Deliberately excludes private keys: the app never needs them, and the
/// socket is the trust boundary.
public struct TunnelSummary: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var addresses: [String]
    public init(id: UUID, name: String, addresses: [String]) {
        self.id = id; self.name = name; self.addresses = addresses
    }
}

public struct Status: Codable, Equatable, Sendable {
    public var running: Bool
    public var health: Health
    public var latencyMs: Int?
    public var activeTunnelID: UUID?
    public var tunnels: [TunnelSummary]
    public var rules: [Rule]
    public var lastError: String?

    public init(state: AppState, running: Bool, health: Health = .stopped,
                latencyMs: Int? = nil, lastError: String?) {
        self.running = running
        self.health = health
        self.latencyMs = latencyMs
        self.activeTunnelID = state.activeTunnelID
        self.tunnels = state.tunnels.map {
            TunnelSummary(id: $0.id, name: $0.name, addresses: $0.addresses)
        }
        self.rules = state.rules
        self.lastError = lastError
    }
}

public enum ControlResponse: Codable, Equatable, Sendable {
    case status(Status)
    case failure(String)
}

/// Newline-delimited JSON. JSONEncoder never emits a raw newline inside a
/// payload, so a single 0x0A is an unambiguous frame terminator.
public enum ControlCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        var data = try JSONEncoder().encode(value)
        data.append(0x0A)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from line: Data) throws -> T {
        let payload = line.last == 0x0A ? line.dropLast() : line[...]
        return try JSONDecoder().decode(type, from: Data(payload))
    }
}
