import XCTest
@testable import WGSplitKit

final class OrphanReaperTests: XCTestCase {
    private let binary = "/Library/PrivilegedHelperTools/wgsplit/sing-box"

    private let ps = """
      34216 /Library/PrivilegedHelperTools/wgsplit/sing-box run -c /Library/Application Support/WGSplit/config.json
      43225 /Library/PrivilegedHelperTools/wgsplit/sing-box run -c /Library/Application Support/WGSplit/config.json
      43261 /Library/PrivilegedHelperTools/wgsplit/wgsplitd
      50001 /opt/homebrew/bin/sing-box run -c /Users/dz0ny/wg-split.json
      50002 grep sing-box
    """

    func testFindsOnlyOurOwnSingBoxProcesses() {
        let pids = OrphanReaper.orphanPIDs(psOutput: ps, binaryPath: binary)
        XCTAssertEqual(pids, [34216, 43225])
    }

    func testDoesNotReapTheDaemonItself() {
        XCTAssertFalse(OrphanReaper.orphanPIDs(psOutput: ps, binaryPath: binary).contains(43261))
    }

    func testLeavesUnrelatedSingBoxAlone() {
        // A sing-box the user runs by hand is none of our business.
        XCTAssertFalse(OrphanReaper.orphanPIDs(psOutput: ps, binaryPath: binary).contains(50001))
    }

    func testExcludesLiveChild() {
        let pids = OrphanReaper.orphanPIDs(psOutput: ps, binaryPath: binary, excluding: [43225])
        XCTAssertEqual(pids, [34216])
    }

    func testEmptyOutputYieldsNothing() {
        XCTAssertTrue(OrphanReaper.orphanPIDs(psOutput: "", binaryPath: binary).isEmpty)
    }
}
