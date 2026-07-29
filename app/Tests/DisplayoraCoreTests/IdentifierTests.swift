import DisplayoraCore
import Foundation
import XCTest

final class IdentifierTests: XCTestCase {
  func testAcceptsNamespacedIdentifiers() throws {
    let feature = try FeatureID(validating: "night-comfort")
    let control = try ControlID(validating: "night-comfort.temperature.1")

    XCTAssertEqual(feature.rawValue, "night-comfort")
    XCTAssertEqual(control.rawValue, "night-comfort.temperature.1")
  }

  func testRejectsMalformedIdentifiers() {
    for invalid in ["", "Uppercase", "leading..separator", "trailing.", "white space"] {
      XCTAssertNil(FeatureID(rawValue: invalid), "Unexpectedly accepted '\(invalid)'")
    }
  }

  func testIdentifierTypesRemainDistinctAndSortable() throws {
    let first = try CommandID(validating: "fixture.alpha")
    let second = try CommandID(validating: "fixture.beta")

    XCTAssertEqual([second, first].sorted().map(\.rawValue), ["fixture.alpha", "fixture.beta"])
  }

  func testCodableRejectsInvalidRawValue() {
    let data = Data(#""invalid value""#.utf8)
    XCTAssertThrowsError(try JSONDecoder().decode(ControlID.self, from: data))
  }
}
