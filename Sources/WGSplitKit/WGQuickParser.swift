import Foundation

public enum WGQuickError: Error, Equatable {
    case missingSection(String)
    case missingKey(String)
    case badEndpoint(String)
}

public enum WGQuickParser {
    public static func parse(_ text: String, name: String) throws -> Tunnel {
        var sections: [String: [String: String]] = [:]
        var current = ""
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                current = String(line.dropFirst().dropLast())
                sections[current] = sections[current] ?? [:]
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            sections[current, default: [:]][key] = value
        }

        guard let iface = sections["Interface"] else { throw WGQuickError.missingSection("Interface") }
        guard let peer = sections["Peer"] else { throw WGQuickError.missingSection("Peer") }

        func need(_ dict: [String: String], _ key: String) throws -> String {
            guard let v = dict[key], !v.isEmpty else { throw WGQuickError.missingKey(key) }
            return v
        }
        func list(_ raw: String?) -> [String] {
            (raw ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        let (host, port) = try splitEndpoint(try need(peer, "Endpoint"))

        return Tunnel(
            name: name,
            privateKey: try need(iface, "PrivateKey"),
            addresses: list(iface["Address"]),
            dns: list(iface["DNS"]),
            mtu: iface["MTU"].flatMap(Int.init),
            peerPublicKey: try need(peer, "PublicKey"),
            peerPresharedKey: peer["PresharedKey"],
            endpointHost: host,
            endpointPort: port,
            persistentKeepalive: peer["PersistentKeepalive"].flatMap(Int.init))
    }

    static func splitEndpoint(_ raw: String) throws -> (String, Int) {
        guard let colon = raw.lastIndex(of: ":"),
              let port = Int(raw[raw.index(after: colon)...])
        else { throw WGQuickError.badEndpoint(raw) }
        var host = String(raw[..<colon])
        if host.hasPrefix("["), host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
        guard !host.isEmpty else { throw WGQuickError.badEndpoint(raw) }
        return (host, port)
    }
}
