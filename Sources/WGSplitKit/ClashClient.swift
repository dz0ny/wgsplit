import Foundation

/// Talks to sing-box's clash_api.
///
/// Health is an *active* probe: clash's /connections only lists currently open
/// connections, so a short request finishes long before any poll sees it. Asking
/// the API to time a request through the `wg-out` outbound instead is
/// deterministic, and it distinguishes a tunnel that is up from one that is
/// merely running — a wrong key fails the probe rather than looking connected.
public struct ClashClient: Sendable {
    public static let outboundTag = "wg-out"

    private let api: ClashAPI
    private let timeout: TimeInterval

    public init(api: ClashAPI, timeout: TimeInterval = 3) {
        self.api = api; self.timeout = timeout
    }

    public static func parseDelay(_ body: Data, statusCode: Int) -> Int? {
        guard statusCode == 200,
              let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let delay = root["delay"] as? Int
        else { return nil }
        return delay
    }

    static func parseConnections(_ body: Data, statusCode: Int) -> [TrafficConnection]? {
        struct Snapshot: Decodable { let connections: [TrafficConnection]? }
        guard statusCode == 200,
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: body),
              let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              root.keys.contains("connections") else { return nil }
        let connections = snapshot.connections ?? []
        guard connections.allSatisfy({ $0.upload >= 0 && $0.download >= 0 }) else { return nil }
        return connections
    }

    func tunnelConnections() -> [TrafficConnection]? {
        let url = URL(string: "http://127.0.0.1:\(api.port)/connections")!
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Bearer \(api.secret)", forHTTPHeaderField: "Authorization")
        let result = ConnectionResult()
        let done = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            result.lock.lock()
            result.value = data.flatMap { Self.parseConnections($0, statusCode: code) }
            result.lock.unlock()
            done.signal()
        }
        task.resume()
        if done.wait(timeout: .now() + timeout + 1) == .timedOut { task.cancel(); return nil }
        result.lock.lock(); defer { result.lock.unlock() }
        return result.value
    }

    /// Milliseconds through the tunnel, or nil when it is not carrying traffic.
    public func tunnelDelay() -> Int? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = api.port
        components.path = "/proxies/\(Self.outboundTag)/delay"
        components.queryItems = [
            URLQueryItem(name: "url", value: "http://www.gstatic.com/generate_204"),
            URLQueryItem(name: "timeout", value: "2000"),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Bearer \(api.secret)", forHTTPHeaderField: "Authorization")

        var result: Int?
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            result = data.flatMap { Self.parseDelay($0, statusCode: code) }
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + timeout + 1)
        return result
    }
}

private final class ConnectionResult: @unchecked Sendable {
    let lock = NSLock()
    var value: [TrafficConnection]?
}
