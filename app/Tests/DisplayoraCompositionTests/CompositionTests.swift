import DisplayoraComposition
import DisplayoraCore
import DisplayoraTestSupport
import DisplayoraUI
import Testing

@MainActor
struct CompositionTests {
  @Test func testFoundationCompositionIsEmpty() {
    XCTAssertTrue(makeInstalledFeatures().isEmpty)
  }

  @Test func testLocalFixtureUsesTheProductionRegistryWithoutEnteringComposition() throws {
    let registry = FeatureRegistry()
    try registry.register(LocalFixtureFeature())

    XCTAssertEqual(registry.snapshot.features.map(\.rawValue), ["fixture"])
    XCTAssertTrue(makeInstalledFeatures().isEmpty)
  }
}

@MainActor
private struct LocalFixtureFeature: DisplayoraFeature {
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
