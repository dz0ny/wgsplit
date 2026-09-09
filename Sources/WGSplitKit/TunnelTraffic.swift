import Foundation

/// Payload bytes observed on tunnel connections, not WireGuard packet overhead.
public struct TunnelTraffic: Codable, Equatable, Sendable {
    public var sent: Int64 = 0
    public var received: Int64 = 0
}

struct TrafficConnection: Decodable {
    let id: String
    let chains: [String]
    let upload: Int64
    let download: Int64
}

/// Retains observed bytes after connections close. Polling can miss short
/// connections and their final bytes, so the result is explicitly an estimate.
struct TunnelTrafficAccumulator {
    private var previous: [String: TrafficConnection] = [:]
    private(set) var total = TunnelTraffic()

    mutating func record(_ connections: [TrafficConnection]) -> TunnelTraffic {
        var current: [String: TrafficConnection] = [:]
        for connection in connections where connection.chains.contains(ClashClient.outboundTag) {
            guard current[connection.id] == nil else { continue }
            let old = previous[connection.id]
            total.sent += max(0, connection.upload - (old?.upload ?? 0))
            total.received += max(0, connection.download - (old?.download ?? 0))
            current[connection.id] = connection
        }
        previous = current
        return total
    }
}
