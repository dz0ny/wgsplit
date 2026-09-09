import XCTest
@testable import WGSplitKit

final class RuleCompilerTests: XCTestCase {
    func testWildcardMatchesApexAndSubdomains() throws {
        let c = try RuleCompiler.compile([Rule(pattern: "*.niteo.co")])
        XCTAssertEqual(c.domainSuffixes, [".niteo.co"])
        XCTAssertEqual(c.domains, ["niteo.co"])
    }

    func testBareDomainIsExactOnly() throws {
        let c = try RuleCompiler.compile([Rule(pattern: "niteo.co")])
        XCTAssertEqual(c.domains, ["niteo.co"])
        XCTAssertTrue(c.domainSuffixes.isEmpty)
    }

    func testMultipleRulesMerge() throws {
        let c = try RuleCompiler.compile([
            Rule(pattern: "*.niteo.co"), Rule(pattern: "*.herokuapp.com")])
        XCTAssertEqual(c.domainSuffixes, [".niteo.co", ".herokuapp.com"])
        XCTAssertEqual(c.domains, ["niteo.co", "herokuapp.com"])
    }

    func testDuplicatesCollapse() throws {
        let c = try RuleCompiler.compile([
            Rule(pattern: "*.niteo.co"), Rule(pattern: "*.niteo.co")])
        XCTAssertEqual(c.domainSuffixes, [".niteo.co"])
    }

    func testCaseIsNormalised() throws {
        let c = try RuleCompiler.compile([Rule(pattern: "*.NITEO.co")])
        XCTAssertEqual(c.domainSuffixes, [".niteo.co"])
    }

    func testTooBroadPatternsRejected() {
        for bad in ["*", "*.com", "com", "*.co.", " "] {
            XCTAssertThrowsError(try RuleCompiler.compile([Rule(pattern: bad)]),
                                 "expected \(bad) to be rejected")
        }
    }

    func testEmptyRuleListRejected() {
        XCTAssertThrowsError(try RuleCompiler.compile([])) {
            XCTAssertEqual($0 as? RuleError, .empty)
        }
    }
}
