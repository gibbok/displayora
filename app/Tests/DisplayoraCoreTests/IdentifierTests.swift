import DisplayoraCore
import DisplayoraTestSupport
import Foundation
import Testing

struct IdentifierTests {
  @Test
  func testAcceptsNamespacedIdentifiers() throws {
    let feature = try FeatureID(validating: "night-comfort")
    let control = try ControlID(validating: "night-comfort.temperature.1")

    XCTAssertEqual(feature.rawValue, "night-comfort")
    XCTAssertEqual(control.rawValue, "night-comfort.temperature.1")
  }

  @Test func testRejectsMalformedIdentifiers() {
    for invalid in ["", "Uppercase", "leading..separator", "trailing.", "white space"] {
      XCTAssertNil(FeatureID(rawValue: invalid), "Unexpectedly accepted '\(invalid)'")
    }
  }

  @Test func testIdentifierTypesRemainDistinctAndSortable() throws {
    let first = try CommandID(validating: "fixture.alpha")
    let second = try CommandID(validating: "fixture.beta")

    XCTAssertEqual([second, first].sorted().map(\.rawValue), ["fixture.alpha", "fixture.beta"])
  }

  @Test func testCodableRejectsInvalidRawValue() {
    let data = Data(#""invalid value""#.utf8)
    XCTAssertThrowsError(try JSONDecoder().decode(ControlID.self, from: data))
  }
}
