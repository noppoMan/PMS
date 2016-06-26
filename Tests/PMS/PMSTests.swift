import XCTest
@testable import PMS

class PMSTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(PMS().text, "Hello, World!")
    }


    static var allTests : [(String, (PMSTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}
