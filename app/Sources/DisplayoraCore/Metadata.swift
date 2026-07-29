public struct CapabilityMetadata: Equatable, Sendable {
  public let id: CapabilityID
  public let ownerID: FeatureID
  public let label: String
  public let accessibilityLabel: String
  public let sortOrder: Int

  public init(
    id: CapabilityID,
    ownerID: FeatureID,
    label: String,
    accessibilityLabel: String,
    sortOrder: Int
  ) {
    self.id = id
    self.ownerID = ownerID
    self.label = label
    self.accessibilityLabel = accessibilityLabel
    self.sortOrder = sortOrder
  }
}

public struct CommandMetadata: Equatable, Sendable {
  public let id: CommandID
  public let ownerID: FeatureID
  public let label: String
  public let accessibilityLabel: String
  public let sortOrder: Int

  public init(
    id: CommandID,
    ownerID: FeatureID,
    label: String,
    accessibilityLabel: String,
    sortOrder: Int
  ) {
    self.id = id
    self.ownerID = ownerID
    self.label = label
    self.accessibilityLabel = accessibilityLabel
    self.sortOrder = sortOrder
  }
}
