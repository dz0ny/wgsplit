import XCTest
@testable import WGSplitKit

final class FakeHandle: SingBoxRunning, @unchecked Sendable {
    var alive = true
    var terminated = false
    var isRunning: Bool { alive }
    var processIdentifier: Int32 { 4242 }
    func terminate() { terminated = true; alive = false }
}

final class FakeRunner: SingBoxRunner, @unchecked Sendable {
    var checkFailsWith: String?
    /// Config contents that should die on start, simulating a runtime-only failure.
    var diesOnStartContaining: String?
    private(set) var startedConfigs: [String] = []
    var handles: [FakeHandle] = []

    func check(configPath: URL) throws {
        if let msg = checkFailsWith { throw ApplyError.checkFailed(msg) }
    }

    func start(configPath: URL) throws -> SingBoxRunning {
        let body = (try? String(contentsOf: configPath, encoding: .utf8)) ?? ""
        startedConfigs.append(body)
        let h = FakeHandle()
        if let needle = diesOnStartContaining, body.contains(needle) { h.alive = false }
        handles.append(h)
        return h
    }
}

final class SupervisorTests: XCTestCase {
    private func makeStore() throws -> StateStore {
        let d = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return StateStore(directory: d)
    }

    private func state(rule: String, enabled: Bool = true) -> AppState {
        let t = Tunnel(name: "n", privateKey: "cHJpdg==", addresses: ["10.0.0.2/32"],
                       dns: ["1.1.1.1"], mtu: nil, peerPublicKey: "cHViCg==",
                       peerPresharedKey: nil, endpointHost: "1.2.3.4",
                       endpointPort: 443, persistentKeepalive: 25)
        return AppState(tunnels: [t], rules: [Rule(pattern: rule)],
                     activeTunnelID: t.id, enabled: enabled)
    }

    func testSuccessfulApplyStartsAndPromotesLastGood() throws {
        let store = try makeStore(), runner = FakeRunner()
        let sup = Supervisor(store: store, runner: runner, settleSeconds: 0)
        try sup.apply(state(rule: "*.niteo.co"))
        XCTAssertTrue(sup.isRunning)
        XCTAssertEqual(runner.startedConfigs.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.lastGoodURL.path))
    }

    func testCheckFailureLeavesRunningProcessUntouched() throws {
        let store = try makeStore(), runner = FakeRunner()
        let sup = Supervisor(store: store, runner: runner, settleSeconds: 0)
        try sup.apply(state(rule: "*.niteo.co"))
        let firstHandle = runner.handles[0]

        runner.checkFailsWith = "bad config"
        XCTAssertThrowsError(try sup.apply(state(rule: "*.herokuapp.com")))
        XCTAssertFalse(firstHandle.terminated, "running process must survive a failed check")
        XCTAssertEqual(runner.startedConfigs.count, 1)
        XCTAssertTrue(sup.isRunning)
    }

    func testProcessDyingOnStartRollsBackToLastGood() throws {
        let store = try makeStore(), runner = FakeRunner()
        let sup = Supervisor(store: store, runner: runner, settleSeconds: 0)
        try sup.apply(state(rule: "*.niteo.co"))

        // check() passes but the process exits immediately — the failure mode
        // seen during design, where sing-box check exited 0 and start died.
        runner.diesOnStartContaining = "herokuapp"
        XCTAssertThrowsError(try sup.apply(state(rule: "*.herokuapp.com"))) {
            guard case ApplyError.diedOnStart = $0 else {
                return XCTFail("expected diedOnStart, got \($0)")
            }
        }
        XCTAssertEqual(runner.startedConfigs.count, 3, "new config, then rollback restart")
        XCTAssertTrue(runner.startedConfigs.last!.contains("niteo.co"))
        XCTAssertFalse(runner.startedConfigs.last!.contains("herokuapp"))
        XCTAssertTrue(sup.isRunning)
        XCTAssertNotNil(sup.lastError)
    }

    func testDisabledStateStopsWithoutStarting() throws {
        let store = try makeStore(), runner = FakeRunner()
        let sup = Supervisor(store: store, runner: runner, settleSeconds: 0)
        try sup.apply(state(rule: "*.niteo.co"))
        try sup.apply(state(rule: "*.niteo.co", enabled: false))
        XCTAssertFalse(sup.isRunning)
        XCTAssertTrue(runner.handles[0].terminated)
    }
}

final class SupervisorHealthTests: XCTestCase {
    private func makeStore() throws -> StateStore {
        let d = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return StateStore(directory: d)
    }

    private func state(enabled: Bool = true) -> AppState {
        let t = Tunnel(name: "n", privateKey: "cHJpdg==", addresses: ["10.0.0.2/32"],
                       dns: ["1.1.1.1"], mtu: nil, peerPublicKey: "cHViCg==",
                       peerPresharedKey: nil, endpointHost: "1.2.3.4",
                       endpointPort: 443, persistentKeepalive: 25)
        return AppState(tunnels: [t], rules: [Rule(pattern: "*.niteo.co")],
                     activeTunnelID: t.id, enabled: enabled)
    }

    /// The probe runs off-thread, so settle before asserting on its result.
    private func healthAfterProbe(_ sup: Supervisor) -> Health {
        _ = sup.health
        let deadline = Date().addingTimeInterval(2)
        while sup.latencyMs == nil && Date() < deadline { usleep(20_000) }
        return sup.health
    }

    func testStoppedWhenNotRunning() throws {
        let sup = Supervisor(store: try makeStore(), runner: FakeRunner(),
                             settleSeconds: 0, trafficProbe: { 42 })
        XCTAssertEqual(sup.health, .stopped)
    }

    func testRunningWhenProbeFails() throws {
        let sup = Supervisor(store: try makeStore(), runner: FakeRunner(),
                             settleSeconds: 0, trafficProbe: { nil })
        try sup.apply(state())
        _ = sup.health
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(sup.health, .running)
        XCTAssertNil(sup.latencyMs)
    }

    func testActiveWhenProbeSucceeds() throws {
        let sup = Supervisor(store: try makeStore(), runner: FakeRunner(),
                             settleSeconds: 0, trafficProbe: { 42 })
        try sup.apply(state())
        XCTAssertEqual(healthAfterProbe(sup), .active)
        XCTAssertEqual(sup.latencyMs, 42)
    }

    func testProbeIsCachedRatherThanRunPerQuery() throws {
        let calls = Counter()
        let sup = Supervisor(store: try makeStore(), runner: FakeRunner(),
                             settleSeconds: 0, probeInterval: 60,
                             trafficProbe: { calls.bump(); return 7 })
        try sup.apply(state())
        _ = healthAfterProbe(sup)
        for _ in 0..<20 { _ = sup.health }
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertEqual(calls.value, 1, "probe should be cached, not run per status query")
    }

    func testProbeResultClearedOnStop() throws {
        let sup = Supervisor(store: try makeStore(), runner: FakeRunner(),
                             settleSeconds: 0, trafficProbe: { 42 })
        try sup.apply(state())
        XCTAssertEqual(healthAfterProbe(sup), .active)
        try sup.apply(state(enabled: false))
        XCTAssertNil(sup.latencyMs)
        XCTAssertEqual(sup.health, .stopped)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func bump() { lock.lock(); count += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
}

final class ClashAPIPersistenceTests: XCTestCase {
    func testCredentialsAreStableAcrossCalls() throws {
        let d = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        let store = StateStore(directory: d)
        let first = try store.loadOrCreateClashAPI()
        XCTAssertEqual(try store.loadOrCreateClashAPI(), first)
        let attrs = try FileManager.default.attributesOfItem(atPath: store.clashAPIURL.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.int16Value, 0o600)
    }
}
