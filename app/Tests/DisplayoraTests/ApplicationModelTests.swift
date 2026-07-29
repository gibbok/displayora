import DisplayoraCore
import DisplayoraTestSupport
import DisplayoraUI
import Testing

@testable import Displayora

@MainActor
struct ApplicationModelTests {
  @Test func testStartsRegisteringAndBecomesReadyEmpty() {
    let model = ApplicationModel(installedFeatures: [])

    guard case .registering = model.state else {
      return XCTFail("Expected registering state")
    }

    model.load()

    guard case .ready(let snapshot) = model.state else {
      return XCTFail("Expected ready state")
    }
    XCTAssertTrue(snapshot.features.isEmpty)
  }

  @Test func testFailurePublishesSafeErrorAndClearsPartialRegistry() {
    let model = ApplicationModel(
      installedFeatures: [SuccessfulAppFixture(), AlwaysFailingAppFixture()]
    )

    model.load()

    guard case .failed(let error) = model.state else {
      return XCTFail("Expected failed state")
    }
    XCTAssertEqual(error, .featureConstruction(failingFeatureID))
    XCTAssertTrue(model.registry.snapshot.features.isEmpty)
  }

  @Test func testRetryCreatesANewRegistryAndReplaysInstalledFeatures() {
    let fixture = RecoveringAppFixture()
    let model = ApplicationModel(installedFeatures: [fixture])
    let initialRegistry = model.registry

    model.load()
    guard case .failed = model.state else {
      return XCTFail("Expected first load to fail")
    }
    let failedRegistry = model.registry
    XCTAssertFalse(initialRegistry === failedRegistry)

    model.retry()
    guard case .ready(let snapshot) = model.state else {
      return XCTFail("Expected retry to succeed")
    }
    XCTAssertFalse(failedRegistry === model.registry)
    XCTAssertEqual(snapshot.features.map(\.rawValue), ["recovering"])
  }
}

private let successfulFeatureID = appFeatureID("successful")
private let failingFeatureID = appFeatureID("failing")
private let recoveringFeatureID = appFeatureID("recovering")

@MainActor
private struct SuccessfulAppFixture: DisplayoraFeature {
  static let id = successfulFeatureID

  func makeContributions() throws -> FeatureContributions {
    try FeatureContributions(featureID: Self.id)
  }
}

@MainActor
private struct AlwaysFailingAppFixture: DisplayoraFeature {
  static let id = failingFeatureID

  func makeContributions() throws -> FeatureContributions {
    throw AppFixtureError.expected
  }
}

@MainActor
private final class RecoveringAppFixture: DisplayoraFeature {
  static let id = recoveringFeatureID
  private var attempt = 0

  func makeContributions() throws -> FeatureContributions {
    attempt += 1
    guard attempt > 1 else {
      throw AppFixtureError.expected
    }
    return try FeatureContributions(featureID: Self.id)
  }
}

private enum AppFixtureError: Error {
  case expected
}

private func appFeatureID(_ value: String) -> FeatureID {
  guard let identifier = FeatureID(rawValue: value) else {
    preconditionFailure("Invalid app fixture identifier '\(value)'.")
  }
  return identifier
}
