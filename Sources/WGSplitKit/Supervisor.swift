import Foundation

public enum ApplyError: Error, Equatable {
    case checkFailed(String)
    case diedOnStart(String)

    var message: String {
        switch self {
        case .checkFailed(let m), .diedOnStart(let m): return m
        }
    }
}

public protocol SingBoxRunning: AnyObject, Sendable {
    var isRunning: Bool { get }
    func terminate()
}

public protocol SingBoxRunner: Sendable {
    func check(configPath: URL) throws
    func start(configPath: URL) throws -> SingBoxRunning
}

/// Owns the sing-box child process. `sing-box check` passing is necessary but
/// not sufficient — a config can pass validation and still die at startup — so
/// "started and stayed up" is the acceptance test, with rollback if unmet.
public final class Supervisor: @unchecked Sendable {
    private let store: StateStore
    private let runner: SingBoxRunner
    private let settleSeconds: TimeInterval
    private var handle: SingBoxRunning?

    public private(set) var lastError: String?

    public init(store: StateStore, runner: SingBoxRunner, settleSeconds: TimeInterval = 5) {
        self.store = store; self.runner = runner; self.settleSeconds = settleSeconds
    }

    public var isRunning: Bool { handle?.isRunning ?? false }

    public func apply(_ state: State) throws {
        try store.save(state)

        guard state.enabled, state.activeTunnel != nil else { stop(); return }

        let config = try ConfigGenerator.generate(state: state)
        try store.write(config, to: store.configURL)

        do {
            try runner.check(configPath: store.configURL)
        } catch {
            // Leave the running process alone; nothing changed for the user.
            let message = describe(error)
            lastError = message
            throw ApplyError.checkFailed(message)
        }

        stop()
        do {
            try startAndSettle(store.configURL)
            try store.write(config, to: store.lastGoodURL)
            lastError = nil
        } catch {
            let message = describe(error)
            lastError = message
            rollback()
            throw ApplyError.diedOnStart(message)
        }
    }

    public func stop() {
        handle?.terminate()
        handle = nil
    }

    private func startAndSettle(_ configPath: URL) throws {
        let h = try runner.start(configPath: configPath)
        handle = h
        if settleSeconds > 0 { Thread.sleep(forTimeInterval: settleSeconds) }
        guard h.isRunning else {
            handle = nil
            throw ApplyError.diedOnStart("sing-box exited within \(settleSeconds)s of start")
        }
    }

    private func rollback() {
        guard let good = try? Data(contentsOf: store.lastGoodURL) else { return }
        try? store.write(good, to: store.configURL)
        try? startAndSettle(store.configURL)
    }

    private func describe(_ error: Error) -> String {
        (error as? ApplyError)?.message ?? "\(error)"
    }
}
