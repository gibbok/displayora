import DisplayoraCore
import DisplayoraTestSupport
import DisplayoraUI
import Foundation
import Testing

@testable import DisplayoraFeatureTestHost

@MainActor
struct HostSnapshotTests {
  @Test func testHostSnapshotUsesRequiredArraysAndDeterministicJSON() throws {
    let registry = FeatureRegistry()
    try registry.register(HostFixtureFeature())

    let data = try encodeHostSnapshot(makeHostSnapshot(from: registry.snapshot))
    let json = try XCTUnwrap(String(data: data, encoding: .utf8))

    XCTAssertEqual(
      json,
      #"{"capabilities":[],"commands":[],"controls":[],"features":["fixture"],"settings":[]}"#
    )
  }

  @Test func testEmptySnapshotContainsAllArrays() throws {
    let data = try encodeHostSnapshot(makeHostSnapshot(from: .empty))
    let decoded = try JSONDecoder().decode(HostSnapshot.self, from: data)

    XCTAssertEqual(
      decoded,
      HostSnapshot(features: [], controls: [], settings: [], capabilities: [], commands: [])
    )
  }

  @Test func testUsageAndUnknownSlugExitCodes() {
    XCTAssertEqual(
      runFeatureHost(arguments: [], features: []),
      HostExecution(
        exitCode: 64,
        standardOutput: "",
        standardError: "usage: DisplayoraFeatureTestHost --expect-feature <canonical-slug>"
      )
    )
    XCTAssertEqual(
      runFeatureHost(arguments: ["--expect-feature", "unknown"], features: []),
      HostExecution(
        exitCode: 65,
        standardOutput: "",
        standardError: "unknown feature slug 'unknown'"
      )
    )
  }

  @Test func testCountMismatchAndRegistrationFailureExitCodes() {
    let empty = runFeatureHost(
      arguments: ["--expect-feature", "brightness"],
      features: []
    )
    XCTAssertEqual(empty.exitCode, 67)
    XCTAssertEqual(empty.standardError, "expected exactly one installed feature; found 0")

    let multiple = runFeatureHost(
      arguments: ["--expect-feature", "brightness"],
      features: [BrightnessHostFixture(), ContrastHostFixture()]
    )
    XCTAssertEqual(multiple.exitCode, 67)
    XCTAssertEqual(multiple.standardError, "expected exactly one installed feature; found 2")

    let failed = runFeatureHost(
      arguments: ["--expect-feature", "brightness"],
      features: [FailingHostFixture()]
    )
    XCTAssertEqual(failed.exitCode, 66)
    XCTAssertTrue(failed.standardError.contains("brightness"))
    XCTAssertFalse(failed.standardError.contains("private failure detail"))
  }

  @Test func testExpectedFeatureMismatchAndSuccessfulJSON() {
    let mismatch = runFeatureHost(
      arguments: ["--expect-feature", "brightness"],
      features: [ContrastHostFixture()]
    )
    XCTAssertEqual(mismatch.exitCode, 68)
    XCTAssertTrue(mismatch.standardError.contains("registered as 'contrast'"))

    let success = runFeatureHost(
      arguments: ["--expect-feature", "brightness"],
      features: [BrightnessHostFixture()]
    )
    XCTAssertEqual(success.exitCode, 0)
    XCTAssertEqual(
      success.standardOutput,
      #"{"capabilities":[],"commands":[],"controls":[],"features":["brightness"],"settings":[]}"#
    )
    XCTAssertTrue(success.standardError.isEmpty)
  }
}

@MainActor
private struct HostFixtureFeature: DisplayoraFeature {
  static let id: FeatureID = {
    guard let identifier = FeatureID(rawValue: "fixture") else {
      preconditionFailure("The fixture identifier must remain valid.")
    }
    return identifier
  }()

  func makeContributions() throws -> FeatureContributions {
    try FeatureContributions(featureID: Self.id)
  }
}

@MainActor
private struct BrightnessHostFixture: DisplayoraFeature {
  static let id = hostFeatureID("brightness")

  func makeContributions() throws -> FeatureContributions {
    try FeatureContributions(featureID: Self.id)
  }
}

@MainActor
private struct ContrastHostFixture: DisplayoraFeature {
  static let id = hostFeatureID("contrast")

  func makeContributions() throws -> FeatureContributions {
    try FeatureContributions(featureID: Self.id)
  }
}

@MainActor
private struct FailingHostFixture: DisplayoraFeature {
  static let id = hostFeatureID("brightness")

  func makeContributions() throws -> FeatureContributions {
    throw HostFixtureFailure.privateDetail
  }
}

private enum HostFixtureFailure: Error {
  case privateDetail
}

private func hostFeatureID(_ value: String) -> FeatureID {
  guard let identifier = FeatureID(rawValue: value) else {
    preconditionFailure("Invalid host fixture identifier '\(value)'.")
  }
  return identifier
}
