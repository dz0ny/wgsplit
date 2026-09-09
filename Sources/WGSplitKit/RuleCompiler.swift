import Foundation

public struct CompiledRules: Equatable, Sendable {
    public var domains: [String]
    public var domainSuffixes: [String]
}

public enum RuleError: Error, Equatable {
    case empty
    case tooBroad(String)
}

public enum RuleCompiler {
    /// `*.x.com` deliberately matches the apex as well as subdomains: a rule
    /// that silently missed `x.com` would read as a bug to the user.
    public static func compile(_ rules: [Rule]) throws -> CompiledRules {
        guard !rules.isEmpty else { throw RuleError.empty }

        var domains: [String] = []
        var suffixes: [String] = []

        for rule in rules {
            let raw = rule.pattern.trimmingCharacters(in: .whitespaces).lowercased()
            let wildcard = raw.hasPrefix("*.")
            let base = wildcard ? String(raw.dropFirst(2)) : raw
            try validate(base, original: rule.pattern)

            if !domains.contains(base) { domains.append(base) }
            if wildcard, !suffixes.contains("." + base) { suffixes.append("." + base) }
        }
        return CompiledRules(domains: domains, domainSuffixes: suffixes)
    }

    /// Rejects anything broad enough to swallow most of the internet.
    static func validate(_ base: String, original: String) throws {
        let labels = base.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({ !$0.isEmpty }),
              base.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" })
        else { throw RuleError.tooBroad(original) }
    }
}
