import XCTest
@testable import WGSplitKit

final class TunnelImporterTests: XCTestCase {
    private var zipURL: URL {
        Bundle.module.url(forResource: "Fixtures/export", withExtension: "zip")!
    }

    func testImportsTunnelNamedFromFilename() throws {
        let tunnels = try TunnelImporter.importTunnels(fromZip: zipURL)
        XCTAssertEqual(tunnels.count, 1)
        XCTAssertEqual(tunnels[0].name, "Niteo DE")
        XCTAssertEqual(tunnels[0].endpointPort, 443)
    }

    func testMissingFileThrows() {
        let missing = URL(fileURLWithPath: "/nonexistent/nope.zip")
        XCTAssertThrowsError(try TunnelImporter.importTunnels(fromZip: missing))
    }

    func testZipWithoutConfThrows() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let txt = dir.appendingPathComponent("readme.txt")
        try "hi".write(to: txt, atomically: true, encoding: .utf8)
        let zip = dir.appendingPathComponent("empty.zip")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        p.arguments = ["-qj", zip.path, txt.path]
        try p.run(); p.waitUntilExit()

        XCTAssertThrowsError(try TunnelImporter.importTunnels(fromZip: zip)) {
            XCTAssertEqual($0 as? ImportError, .noConfigsFound)
        }
    }
}
