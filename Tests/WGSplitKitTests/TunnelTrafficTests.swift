import XCTest
@testable import WGSplitKit

final class TunnelTrafficTests: XCTestCase {
    private func connection(_ id: String, _ sent: Int64, _ received: Int64,
                            chain: [String] = ["wg-out"]) -> TrafficConnection {
        TrafficConnection(id: id, chains: chain, upload: sent, download: received)
    }

    func testCountsOnlyTunnelAndRetainsClosedConnections() {
        var counter = TunnelTrafficAccumulator()
        XCTAssertEqual(counter.record([
            connection("tunnel", 100, 500),
            connection("direct", 9000, 8000, chain: ["direct"]),
        ]), TunnelTraffic(sent: 100, received: 500))
        XCTAssertEqual(counter.record([connection("tunnel", 150, 700)]),
                       TunnelTraffic(sent: 150, received: 700))
        XCTAssertEqual(counter.record([]), TunnelTraffic(sent: 150, received: 700))
        XCTAssertEqual(counter.record([connection("new", 20, 30)]),
                       TunnelTraffic(sent: 170, received: 730))
    }

    func testRepeatedSnapshotDoesNotCountTwice() {
        var counter = TunnelTrafficAccumulator()
        let snapshot = [connection("a", 10, 20, chain: ["wg-out", "selector"])]
        _ = counter.record(snapshot)
        XCTAssertEqual(counter.record(snapshot), TunnelTraffic(sent: 10, received: 20))
    }

    func testParsesEmptyAndRejectsInvalidSnapshots() {
        XCTAssertEqual(ClashClient.parseConnections(Data(#"{"connections":null}"#.utf8), statusCode: 200)?.count, 0)
        XCTAssertEqual(ClashClient.parseConnections(Data(#"{"connections":[]}"#.utf8), statusCode: 200)?.count, 0)
        XCTAssertNil(ClashClient.parseConnections(Data(#"{}"#.utf8), statusCode: 200))
        XCTAssertNil(ClashClient.parseConnections(Data(#"{"connections":[]}"#.utf8), statusCode: 401))
        XCTAssertNil(ClashClient.parseConnections(Data(#"{"connections":[{"id":"a","chains":["wg-out"],"upload":-1,"download":2}]}"#.utf8), statusCode: 200))
    }

    func testParsesTunnelCounters() {
        let snapshot = ClashClient.parseConnections(Data(#"{"connections":[{"id":"a","chains":["wg-out"],"upload":123,"download":456}]}"#.utf8), statusCode: 200)
        var counter = TunnelTrafficAccumulator()
        XCTAssertEqual(counter.record(snapshot ?? []), TunnelTraffic(sent: 123, received: 456))
    }

    func testOlderStatusWithoutTrafficStillDecodes() throws {
        let status = Status(state: .empty, running: true, lastError: nil)
        let data = try JSONEncoder().encode(status)
        XCTAssertNil(try JSONDecoder().decode(Status.self, from: data).traffic)
    }
}
