import XCTest
@testable import Displayora

final class GreetingTests: XCTestCase {
    func testMessageIsHelloWorld() {
        XCTAssertEqual(Greeting.message, "Hello World")
    }
}
