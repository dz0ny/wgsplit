import Foundation

/// Polls sing-box's clash_api to see whether any traffic has been routed
/// through the tunnel outbound.
public struct ClashClient: Sendable {
    private let api: ClashAPI
    private let timeout: TimeInterval

    public init(api: ClashAPI, timeout: TimeInterval = 2) {
        self.api = api; self.timeout = timeout
    }

    /// Pure over the response body so it is testable without an HTTP server.
    public static func sawTunnelTraffic(in body: Data) -> Bool {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let connections = root["connections"] as? [[String: Any]]
        else { return false }
        return connections.contains { connection in
            (connection["chains"] as? [String])?.contains("wg-out") ?? false
        }
    }

    public func sawTunnelTraffic() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(api.port)/connections") else { return false }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Bearer \(api.secret)", forHTTPHeaderField: "Authorization")

        var body: Data?
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, _, _ in
            body = data
            done.signal()
        }.resume()
        guard done.wait(timeout: .now() + timeout + 1) == .success, let body else { return false }
        return Self.sawTunnelTraffic(in: body)
    }
}
