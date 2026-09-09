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
    var processIdentifier: Int32 { get }
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
    private let clashAPI: ClashAPI?
    /// Returns latency through the tunnel in ms, or nil when it is not
    /// carrying traffic. Injected so tests need no network.
    private let trafficProbe: () -> Int?
    private let probeInterval: TimeInterval
    private let probeLock = NSLock()
    private var lastProbe: (at: Date, delayMs: Int?)?
    private var probing = false
    private var handle: SingBoxRunning?

    public private(set) var lastError: String?

    public init(store: StateStore, runner: SingBoxRunner, settleSeconds: TimeInterval = 5,
                clashAPI: ClashAPI? = nil, probeInterval: TimeInterval = 20,
                trafficProbe: (() -> Int?)? = nil) {
        self.store = store; self.runner = runner; self.settleSeconds = settleSeconds
        self.clashAPI = clashAPI
        self.probeInterval = probeInterval
        self.trafficProbe = trafficProbe
            ?? { clashAPI.flatMap { ClashClient(api: $0).tunnelDelay() } }
    }

    public var isRunning: Bool { handle?.isRunning ?? false }

    /// Exposed so the daemon's signal handler can kill the child directly:
    /// only async-signal-safe calls are allowed in that context.
    public var currentPID: Int32? { handle.map(\.processIdentifier) }

    /// Latency through the tunnel from the most recent probe, if it succeeded.
    public var latencyMs: Int? {
        probeLock.lock(); defer { probeLock.unlock() }
        return lastProbe?.delayMs
    }

    public var health: Health {
        guard isRunning else { return .stopped }
        refreshProbeIfStale()
        probeLock.lock(); defer { probeLock.unlock() }
        guard let last = lastProbe else { return .running }
        return last.delayMs == nil ? .running : .active
    }

    /// Probes off the caller's thread so a status request never blocks on the
    /// network; callers see the previous result until the new one lands.
    private func refreshProbeIfStale() {
        probeLock.lock()
        let fresh = lastProbe.map { Date().timeIntervalSince($0.at) < probeInterval } ?? false
        if fresh || probing { probeLock.unlock(); return }
        probing = true
        probeLock.unlock()

        let probe = trafficProbe
        Thread {
            let delay = probe()
            self.probeLock.lock()
            self.lastProbe = (Date(), delay)
            self.probing = false
            self.probeLock.unlock()
        }.start()
    }

    public func apply(_ state: AppState) throws {
        try store.save(state)

        guard state.enabled, state.activeTunnel != nil else { stop(); return }

        let config = try ConfigGenerator.generate(state: state, clashAPI: clashAPI)
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
        probeLock.lock()
        lastProbe = nil
        probeLock.unlock()
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
