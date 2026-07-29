import Testing

public func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String = "") {
  #expect(lhs == rhs, "\(message)")
}

public func XCTAssertTrue(_ value: Bool, _ message: String = "") {
  #expect(value, "\(message)")
}

public func XCTAssertFalse(_ value: Bool, _ message: String = "") {
  #expect(!value, "\(message)")
}

public func XCTAssertNil<T>(_ value: T?, _ message: String = "") {
  #expect(value == nil, "\(message)")
}

public func XCTAssertThrowsError<T>(
  _ expression: @autoclosure () throws -> T,
  _ handler: (Error) -> Void = { _ in }
) {
  do {
    _ = try expression()
    Issue.record("Expected an error to be thrown")
  } catch {
    handler(error)
  }
}

public func XCTFail(_ message: String) {
  Issue.record(Comment(rawValue: message))
}

public func XCTUnwrap<T>(_ value: T?, _ message: String = "") throws -> T {
  guard let value else {
    Issue.record(Comment(rawValue: message.isEmpty ? "Expected a non-nil value" : message))
    throw UnwrapError()
  }
  return value
}

private struct UnwrapError: Error {}
