import XCTest
@testable import WGSplitKit

private let sample = """
[Interface]
PrivateKey = aGVsbG8gcHJpdmF0ZSBrZXkgaGVyZSEhISEhISE=
Address = 10.212.4.7/32
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = aGVsbG8gcHVibGljIGtleSBoZXJlISEhISEhISE=
PresharedKey = aGVsbG8gcHNrIGtleSBoZXJlISEhISEhISEhIQ==
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 193.122.15.126:443
PersistentKeepalive = 25
"""

final class WGQuickParserTests: XCTestCase {
    func testParsesAllFields() throws {
        let t = try WGQuickParser.parse(sample, name: "Niteo DE")
        XCTAssertEqual(t.name, "Niteo DE")
        XCTAssertEqual(t.addresses, ["10.212.4.7/32"])
        XCTAssertEqual(t.dns, ["1.1.1.1"])
        XCTAssertEqual(t.mtu, 1420)
        XCTAssertEqual(t.endpointHost, "193.122.15.126")
        XCTAssertEqual(t.endpointPort, 443)
        XCTAssertEqual(t.persistentKeepalive, 25)
        XCTAssertNotNil(t.peerPresharedKey)
    }

    func testParsesIPv6Endpoint() throws {
        let text = sample.replacingOccurrences(
            of: "Endpoint = 193.122.15.126:443", with: "Endpoint = [2a01:4f8::1]:51820")
        let t = try WGQuickParser.parse(text, name: "x")
        XCTAssertEqual(t.endpointHost, "2a01:4f8::1")
        XCTAssertEqual(t.endpointPort, 51820)
    }

    func testCommentsAndBlankLinesIgnored() throws {
        let text = "# lead\n\n" + sample + "\n# trail\n"
        XCTAssertEqual(try WGQuickParser.parse(text, name: "x").endpointPort, 443)
    }

    func testMissingPrivateKeyThrows() {
        let text = sample.replacingOccurrences(
            of: "PrivateKey = aGVsbG8gcHJpdmF0ZSBrZXkgaGVyZSEhISEhISE=\n", with: "")
        XCTAssertThrowsError(try WGQuickParser.parse(text, name: "x")) {
            XCTAssertEqual($0 as? WGQuickError, .missingKey("PrivateKey"))
        }
    }

    func testMissingPeerSectionThrows() {
        let interfaceOnly = """
        [Interface]
        PrivateKey = aGVsbG8gcHJpdmF0ZSBrZXkgaGVyZSEhISEhISE=
        Address = 10.212.4.7/32
        """
        XCTAssertThrowsError(try WGQuickParser.parse(interfaceOnly, name: "x")) {
            XCTAssertEqual($0 as? WGQuickError, .missingSection("Peer"))
        }
    }
}
