import Foundation

public struct StateStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    public var stateURL: URL { directory.appendingPathComponent("state.json") }
    public var configURL: URL { directory.appendingPathComponent("config.json") }
    public var lastGoodURL: URL { directory.appendingPathComponent("config.last-good.json") }
    public var clashAPIURL: URL { directory.appendingPathComponent("clash-api.json") }

    /// Generated once and reused, so a rollback to last-known-good config
    /// keeps credentials that still work.
    public func loadOrCreateClashAPI() throws -> ClashAPI {
        if let data = try? Data(contentsOf: clashAPIURL),
           let api = try? JSONDecoder().decode(ClashAPI.self, from: data) {
            return api
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let api = ClashAPI.random()
        try write(try JSONEncoder().encode(api), to: clashAPIURL)
        return api
    }

    /// Never throws: a corrupt or absent file yields an empty state so the
    /// daemon always starts.
    public func load() -> State {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(State.self, from: data)
        else { return .empty }
        return state
    }

    public func save(_ state: State) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try write(try JSONEncoder().encode(state), to: stateURL)
    }

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
