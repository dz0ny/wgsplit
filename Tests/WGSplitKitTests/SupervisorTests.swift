import XCTest
@testable import WGSplitKit

private final class FakeHandle: SingBoxRunning, @unchecked Sendable {
    var alive = true
    var terminated = false
    var isRunning: Bool { alive }
    func terminate() { terminated = true; alive = false }
}

private final class FakeRunner: SingBoxRunner, @unchecked Sendable {
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

    private func state(rule: String, enabled: Bool = true) -> State {
        let t = Tunnel(name: "n", privateKey: "cHJpdg==", addresses: ["10.0.0.2/32"],
                       dns: ["1.1.1.1"], mtu: nil, peerPublicKey: "cHViCg==",
                       peerPresharedKey: nil, endpointHost: "1.2.3.4",
                       endpointPort: 443, persistentKeepalive: 25)
        return State(tunnels: [t], rules: [Rule(pattern: rule)],
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
