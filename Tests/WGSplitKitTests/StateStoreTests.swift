import XCTest
@testable import WGSplitKit

final class StateStoreTests: XCTestCase {
    private func tempDir() throws -> URL {
        let d = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testLoadReturnsEmptyStateWhenAbsent() throws {
        XCTAssertEqual(StateStore(directory: try tempDir()).load(), .empty)
    }

    func testSaveThenLoadRoundTrips() throws {
        let store = StateStore(directory: try tempDir())
        let state = State(tunnels: [], rules: [Rule(pattern: "*.niteo.co")],
                          activeTunnelID: nil, enabled: true)
        try store.save(state)
        XCTAssertEqual(store.load(), state)
    }

    func testSavedFileIsOwnerReadOnly() throws {
        let store = StateStore(directory: try tempDir())
        try store.save(.empty)
        let attrs = try FileManager.default.attributesOfItem(atPath: store.stateURL.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.int16Value, 0o600)
    }

    func testCorruptStateFallsBackToEmpty() throws {
        let store = StateStore(directory: try tempDir())
        try "not json".write(to: store.stateURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(store.load(), .empty)
    }
}
