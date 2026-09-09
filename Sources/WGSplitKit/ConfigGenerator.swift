import Foundation

public enum GeneratorError: Error, Equatable {
    case noActiveTunnel
}

/// Emits the sing-box 1.14.0 config schema. Two constraints are load-bearing:
/// dns-direct must carry no `detour`, and `route.default_domain_resolver` is
/// mandatory. Violating either makes sing-box refuse to start.
public enum ConfigGenerator {
    public static func generate(state: State, clashAPI: ClashAPI? = nil) throws -> Data {
        guard let tunnel = state.activeTunnel else { throw GeneratorError.noActiveTunnel }
        let compiled = try RuleCompiler.compile(state.rules)

        var dnsServers: [[String: Any]] = [
            ["tag": "dns-direct", "type": "udp", "server": "1.1.1.1"],
        ]
        var dnsRules: [[String: Any]] = []
        if let tunnelDNS = tunnel.dns.first {
            dnsServers.append(["tag": "dns-wg", "type": "udp",
                               "server": tunnelDNS, "detour": "wg-out"])
            var rule: [String: Any] = ["server": "dns-wg"]
            if !compiled.domainSuffixes.isEmpty { rule["domain_suffix"] = compiled.domainSuffixes }
            if !compiled.domains.isEmpty { rule["domain"] = compiled.domains }
            dnsRules.append(rule)
        }

        var peer: [String: Any] = [
            "address": tunnel.endpointHost,
            "port": tunnel.endpointPort,
            "public_key": tunnel.peerPublicKey,
            "allowed_ips": ["0.0.0.0/0"],
        ]
        if let psk = tunnel.peerPresharedKey, !psk.isEmpty { peer["pre_shared_key"] = psk }
        if let ka = tunnel.persistentKeepalive { peer["persistent_keepalive_interval"] = ka }

        var endpoint: [String: Any] = [
            "type": "wireguard", "tag": "wg-out",
            "address": tunnel.addresses,
            "private_key": tunnel.privateKey,
            "peers": [peer],
        ]
        if let mtu = tunnel.mtu { endpoint["mtu"] = mtu }

        var domainRule: [String: Any] = ["outbound": "wg-out"]
        if !compiled.domainSuffixes.isEmpty { domainRule["domain_suffix"] = compiled.domainSuffixes }
        if !compiled.domains.isEmpty { domainRule["domain"] = compiled.domains }

        var config: [String: Any] = [
            "log": ["level": "info", "timestamp": true],
            "dns": ["servers": dnsServers, "rules": dnsRules,
                    "final": "dns-direct", "strategy": "ipv4_only"],
            "inbounds": [["type": "tun", "tag": "tun-in",
                          "address": ["172.19.0.1/30"],
                          "auto_route": true, "strict_route": true, "stack": "gvisor"]],
            "endpoints": [endpoint],
            "outbounds": [["type": "direct", "tag": "direct"]],
            "route": [
                "rules": [["action": "sniff"],
                          ["protocol": "dns", "action": "hijack-dns"],
                          domainRule],
                "final": "direct",
                "auto_detect_interface": true,
                "default_domain_resolver": ["server": "dns-direct"],
            ],
        ]

        if let clashAPI {
            config["experimental"] = [
                "clash_api": ["external_controller": "127.0.0.1:\(clashAPI.port)",
                              "secret": clashAPI.secret],
            ]
        }

        return try JSONSerialization.data(withJSONObject: config,
                                          options: [.prettyPrinted, .sortedKeys])
    }
}
