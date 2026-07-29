import DisplayoraCore
import SwiftUI
import XCTest

@testable import DisplayoraUI

@MainActor
final class FeatureRegistryTests: XCTestCase {
  func testRegistersAndSortsEveryContributionCategory() throws {
    let registry = FeatureRegistry()
    try registry.register(SortedFixtureFeature())

    let snapshot = registry.snapshot
    XCTAssertEqual(snapshot.features.map(\.rawValue), ["fixture"])
    XCTAssertEqual(
      snapshot.controls.map(\.id.rawValue), ["fixture.control-a", "fixture.control-b"])
    XCTAssertEqual(
      snapshot.settings.map(\.id.rawValue), ["fixture.setting-a", "fixture.setting-b"])
    XCTAssertEqual(
      snapshot.capabilities.map(\.id.rawValue),
      ["fixture.capability-a", "fixture.capability-b"]
    )
    XCTAssertEqual(
      snapshot.commands.map(\.id.rawValue), ["fixture.command-a", "fixture.command-b"])
  }

  func testRejectsDuplicateFeature() throws {
    let registry = FeatureRegistry()
    try registry.register(EmptyFixtureFeature())

    XCTAssertThrowsError(try registry.register(EmptyFixtureFeature())) { error in
      XCTAssertEqual(error as? FeatureRegistrationError, .duplicateFeature(fixtureFeatureID))
    }
  }

  func testRejectsEveryDuplicateContributionCategoryAtomically() throws {
    try assertDuplicate(
      kind: .control,
      expected: .duplicateControl(controlID("fixture.duplicate"))
    )
    try assertDuplicate(
      kind: .setting,
      expected: .duplicateSetting(settingID("fixture.duplicate"))
    )
    try assertDuplicate(
      kind: .capability,
      expected: .duplicateCapability(capabilityID("fixture.duplicate"))
    )
    try assertDuplicate(
      kind: .command,
      expected: .duplicateCommand(commandID("fixture.duplicate"))
    )
  }

  func testRejectsOwnerMismatchAndEmptyLabels() {
    XCTAssertThrowsError(
      try ControlContribution(
        id: controlID("other.control"),
        ownerID: fixtureFeatureID,
        label: "Control",
        accessibilityLabel: "Control",
        sortOrder: 0,
        viewFactory: { AnyView(EmptyView()) }
      )
    ) { error in
      guard case .ownerMismatch = error as? FeatureRegistrationError else {
        return XCTFail("Expected owner mismatch, received \(error)")
      }
    }

    XCTAssertThrowsError(
      try SettingContribution(
        id: settingID("fixture.setting"),
        ownerID: fixtureFeatureID,
        label: " ",
        accessibilityLabel: "Setting",
        sortOrder: 0,
        viewFactory: { AnyView(EmptyView()) }
      )
    ) { error in
      XCTAssertEqual(
        error as? FeatureRegistrationError,
        .emptyLabel(kind: .setting, id: "fixture.setting")
      )
    }
  }

  func testSanitizesUnknownConstructionFailure() {
    let registry = FeatureRegistry()

    XCTAssertThrowsError(try registry.register(ThrowingFixtureFeature())) { error in
      XCTAssertEqual(
        error as? FeatureRegistrationError,
        .featureConstruction(fixtureFeatureID)
      )
      XCTAssertFalse(error.localizedDescription.contains("secret"))
    }
    XCTAssertTrue(registry.snapshot.features.isEmpty)
  }

  func testRejectsFeatureIdentityMismatchAtomically() {
    let registry = FeatureRegistry()
    let before = fingerprint(registry.snapshot)

    XCTAssertThrowsError(try registry.register(MismatchedIdentityFeature())) { error in
      XCTAssertEqual(
        error as? FeatureRegistrationError,
        .featureIdentityMismatch(expected: fixtureFeatureID, actual: otherFeatureID)
      )
    }
    XCTAssertEqual(fingerprint(registry.snapshot), before)
  }

  func testSettingsFallbackReportsWhetherAppKitAcceptedAction() {
    var receivedSelector: Selector?
    let accepted = AppKitSettingsOpener { selector in
      receivedSelector = selector
      return true
    }
    let rejected = AppKitSettingsOpener { _ in false }

    XCTAssertTrue(accepted.openSettings())
    XCTAssertEqual(receivedSelector.map(NSStringFromSelector), "showSettingsWindow:")
    XCTAssertFalse(rejected.openSettings())
  }

  private func assertDuplicate(
    kind: ContributionKind,
    expected: FeatureRegistrationError
  ) throws {
    let registry = FeatureRegistry()
    let before = fingerprint(registry.snapshot)

    XCTAssertThrowsError(try registry.register(DuplicateFixtureFeature(kind: kind))) { error in
      XCTAssertEqual(error as? FeatureRegistrationError, expected)
    }
    XCTAssertEqual(fingerprint(registry.snapshot), before)
  }
}

private let fixtureFeatureID = featureID("fixture")
private let otherFeatureID = featureID("other")

@MainActor
private struct EmptyFixtureFeature: DisplayoraFeature {
  static let id = fixtureFeatureID

  func makeContributions() throws -> FeatureContributions {
    try FeatureContributions(featureID: Self.id)
  }
}

@MainActor
private struct ThrowingFixtureFeature: DisplayoraFeature {
  static let id = fixtureFeatureID

  func makeContributions() throws -> FeatureContributions {
    throw FixtureFailure.secret("secret underlying debug value")
  }
}

@MainActor
private struct MismatchedIdentityFeature: DisplayoraFeature {
  static let id = fixtureFeatureID

  func makeContributions() throws -> FeatureContributions {
    try FeatureContributions(featureID: otherFeatureID)
  }
}

private enum FixtureFailure: Error {
  case secret(String)
}

@MainActor
private struct SortedFixtureFeature: DisplayoraFeature {
  static let id = fixtureFeatureID

  func makeContributions() throws -> FeatureContributions {
    try FeatureContributions(
      featureID: Self.id,
      controls: [
        try control("fixture.control-b", order: 2),
        try control("fixture.control-a", order: 2),
      ],
      settings: [
        try setting("fixture.setting-b", order: 3),
        try setting("fixture.setting-a", order: 1),
      ],
      capabilities: [
        try capability("fixture.capability-b", order: 8),
        try capability("fixture.capability-a", order: 8),
      ],
      commands: [
        try command("fixture.command-b", order: 5),
        try command("fixture.command-a", order: 4),
      ]
    )
  }
}

@MainActor
private struct DuplicateFixtureFeature: DisplayoraFeature {
  static let id = fixtureFeatureID
  let kind: ContributionKind

  func makeContributions() throws -> FeatureContributions {
    switch kind {
    case .control:
      return try FeatureContributions(
        featureID: Self.id,
        controls: [
          try control("fixture.duplicate", order: 0),
          try control("fixture.duplicate", order: 1),
        ]
      )
    case .setting:
      return try FeatureContributions(
        featureID: Self.id,
        settings: [
          try setting("fixture.duplicate", order: 0),
          try setting("fixture.duplicate", order: 1),
        ]
      )
    case .capability:
      return try FeatureContributions(
        featureID: Self.id,
        capabilities: [
          try capability("fixture.duplicate", order: 0),
          try capability("fixture.duplicate", order: 1),
        ]
      )
    case .command:
      return try FeatureContributions(
        featureID: Self.id,
        commands: [
          try command("fixture.duplicate", order: 0),
          try command("fixture.duplicate", order: 1),
        ]
      )
    }
  }
}

@MainActor
private func control(_ rawValue: String, order: Int) throws -> ControlContribution {
  try ControlContribution(
    id: controlID(rawValue),
    ownerID: fixtureFeatureID,
    label: "Control",
    accessibilityLabel: "Fixture control",
    sortOrder: order,
    viewFactory: { AnyView(Text("Control")) }
  )
}

@MainActor
private func setting(_ rawValue: String, order: Int) throws -> SettingContribution {
  try SettingContribution(
    id: settingID(rawValue),
    ownerID: fixtureFeatureID,
    label: "Setting",
    accessibilityLabel: "Fixture setting",
    sortOrder: order,
    viewFactory: { AnyView(Text("Setting")) }
  )
}

@MainActor
private func capability(_ rawValue: String, order: Int) throws -> CapabilityContribution {
  try CapabilityContribution(
    metadata: CapabilityMetadata(
      id: capabilityID(rawValue),
      ownerID: fixtureFeatureID,
      label: "Capability",
      accessibilityLabel: "Fixture capability",
      sortOrder: order
    )
  )
}

@MainActor
private func command(_ rawValue: String, order: Int) throws -> CommandContribution {
  try CommandContribution(
    metadata: CommandMetadata(
      id: commandID(rawValue),
      ownerID: fixtureFeatureID,
      label: "Command",
      accessibilityLabel: "Fixture command",
      sortOrder: order
    ),
    action: {}
  )
}

@MainActor
private func fingerprint(_ snapshot: FeatureRegistrySnapshot) -> [[String]] {
  [
    snapshot.features.map(\.rawValue),
    snapshot.controls.map(\.id.rawValue),
    snapshot.settings.map(\.id.rawValue),
    snapshot.capabilities.map(\.id.rawValue),
    snapshot.commands.map(\.id.rawValue),
  ]
}

private func featureID(_ value: String) -> FeatureID {
  guard let identifier = FeatureID(rawValue: value) else {
    preconditionFailure("Invalid fixture feature identifier '\(value)'.")
  }
  return identifier
}

private func controlID(_ value: String) -> ControlID {
  guard let identifier = ControlID(rawValue: value) else {
    preconditionFailure("Invalid fixture control identifier '\(value)'.")
  }
  return identifier
}

private func settingID(_ value: String) -> SettingID {
  guard let identifier = SettingID(rawValue: value) else {
    preconditionFailure("Invalid fixture setting identifier '\(value)'.")
  }
  return identifier
}

private func capabilityID(_ value: String) -> CapabilityID {
  guard let identifier = CapabilityID(rawValue: value) else {
    preconditionFailure("Invalid fixture capability identifier '\(value)'.")
  }
  return identifier
}

private func commandID(_ value: String) -> CommandID {
  guard let identifier = CommandID(rawValue: value) else {
    preconditionFailure("Invalid fixture command identifier '\(value)'.")
  }
  return identifier
}
