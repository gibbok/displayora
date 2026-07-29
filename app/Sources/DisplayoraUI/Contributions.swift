import DisplayoraCore
import SwiftUI

private func validateContribution(
  kind: ContributionKind,
  id: String,
  ownerID: FeatureID,
  label: String,
  accessibilityLabel: String,
  sortOrder: Int
) throws {
  let expectedPrefix = ownerID.rawValue + "."
  guard id.hasPrefix(expectedPrefix) else {
    let actualOwnerValue = id.split(separator: ".").first.map(String.init) ?? id
    guard let actualOwner = FeatureID(rawValue: actualOwnerValue) else {
      throw FeatureRegistrationError.malformedIdentifier(kind: kind.rawValue, value: id)
    }
    throw FeatureRegistrationError.ownerMismatch(
      kind: kind,
      id: id,
      expected: ownerID,
      actual: actualOwner
    )
  }
  guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
    !accessibilityLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  else {
    throw FeatureRegistrationError.emptyLabel(kind: kind, id: id)
  }
  guard sortOrder >= 0 else {
    throw FeatureRegistrationError.invalidSortOrder(kind: kind, id: id)
  }
}

@MainActor
public struct ControlContribution {
  public let id: ControlID
  public let ownerID: FeatureID
  public let label: String
  public let accessibilityLabel: String
  public let sortOrder: Int
  private let viewFactory: @MainActor () -> AnyView

  public init(
    id: ControlID,
    ownerID: FeatureID,
    label: String,
    accessibilityLabel: String,
    sortOrder: Int,
    viewFactory: @escaping @MainActor () -> AnyView
  ) throws {
    try validateContribution(
      kind: .control,
      id: id.rawValue,
      ownerID: ownerID,
      label: label,
      accessibilityLabel: accessibilityLabel,
      sortOrder: sortOrder
    )
    self.id = id
    self.ownerID = ownerID
    self.label = label
    self.accessibilityLabel = accessibilityLabel
    self.sortOrder = sortOrder
    self.viewFactory = viewFactory
  }

  public func makeView() -> AnyView {
    viewFactory()
  }
}

@MainActor
public struct SettingContribution {
  public let id: SettingID
  public let ownerID: FeatureID
  public let label: String
  public let accessibilityLabel: String
  public let sortOrder: Int
  private let viewFactory: @MainActor () -> AnyView

  public init(
    id: SettingID,
    ownerID: FeatureID,
    label: String,
    accessibilityLabel: String,
    sortOrder: Int,
    viewFactory: @escaping @MainActor () -> AnyView
  ) throws {
    try validateContribution(
      kind: .setting,
      id: id.rawValue,
      ownerID: ownerID,
      label: label,
      accessibilityLabel: accessibilityLabel,
      sortOrder: sortOrder
    )
    self.id = id
    self.ownerID = ownerID
    self.label = label
    self.accessibilityLabel = accessibilityLabel
    self.sortOrder = sortOrder
    self.viewFactory = viewFactory
  }

  public func makeView() -> AnyView {
    viewFactory()
  }
}

@MainActor
public struct CapabilityContribution {
  public let metadata: CapabilityMetadata

  public var id: CapabilityID { metadata.id }
  public var ownerID: FeatureID { metadata.ownerID }
  public var label: String { metadata.label }
  public var accessibilityLabel: String { metadata.accessibilityLabel }
  public var sortOrder: Int { metadata.sortOrder }

  public init(metadata: CapabilityMetadata) throws {
    try validateContribution(
      kind: .capability,
      id: metadata.id.rawValue,
      ownerID: metadata.ownerID,
      label: metadata.label,
      accessibilityLabel: metadata.accessibilityLabel,
      sortOrder: metadata.sortOrder
    )
    self.metadata = metadata
  }
}

@MainActor
public struct CommandContribution {
  public let metadata: CommandMetadata
  private let action: @MainActor () async throws -> Void

  public var id: CommandID { metadata.id }
  public var ownerID: FeatureID { metadata.ownerID }
  public var label: String { metadata.label }
  public var accessibilityLabel: String { metadata.accessibilityLabel }
  public var sortOrder: Int { metadata.sortOrder }

  public init(
    metadata: CommandMetadata,
    action: @escaping @MainActor () async throws -> Void
  ) throws {
    try validateContribution(
      kind: .command,
      id: metadata.id.rawValue,
      ownerID: metadata.ownerID,
      label: metadata.label,
      accessibilityLabel: metadata.accessibilityLabel,
      sortOrder: metadata.sortOrder
    )
    self.metadata = metadata
    self.action = action
  }

  public func perform() async throws {
    try await action()
  }
}
