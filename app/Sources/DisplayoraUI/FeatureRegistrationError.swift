import DisplayoraCore
import Foundation

public enum ContributionKind: String, Equatable, Sendable {
  case control
  case setting
  case capability
  case command
}

public enum FeatureRegistrationError: Error, Equatable, LocalizedError, Sendable {
  case featureConstruction(FeatureID)
  case malformedIdentifier(kind: String, value: String)
  case ownerMismatch(
    kind: ContributionKind,
    id: String,
    expected: FeatureID,
    actual: FeatureID
  )
  case emptyLabel(kind: ContributionKind, id: String)
  case invalidSortOrder(kind: ContributionKind, id: String)
  case featureIdentityMismatch(expected: FeatureID, actual: FeatureID)
  case duplicateFeature(FeatureID)
  case duplicateControl(ControlID)
  case duplicateSetting(SettingID)
  case duplicateCapability(CapabilityID)
  case duplicateCommand(CommandID)

  public var errorDescription: String? {
    switch self {
    case .featureConstruction(let featureID):
      "The '\(featureID.rawValue)' feature could not create its controls."
    case .malformedIdentifier(let kind, let value):
      "The \(kind) identifier '\(value)' is invalid."
    case .ownerMismatch(let kind, let id, let expected, let actual):
      "The \(kind.rawValue) '\(id)' belongs to '\(actual.rawValue)', not "
        + "'\(expected.rawValue)'."
    case .emptyLabel(let kind, let id):
      "The \(kind.rawValue) '\(id)' is missing a readable label."
    case .invalidSortOrder(let kind, let id):
      "The \(kind.rawValue) '\(id)' has an invalid sort order."
    case .featureIdentityMismatch(let expected, let actual):
      "The '\(expected.rawValue)' feature returned contributions owned by "
        + "'\(actual.rawValue)'."
    case .duplicateFeature(let id):
      "The feature '\(id.rawValue)' is registered more than once."
    case .duplicateControl(let id):
      "The control '\(id.rawValue)' is registered more than once."
    case .duplicateSetting(let id):
      "The setting '\(id.rawValue)' is registered more than once."
    case .duplicateCapability(let id):
      "The capability '\(id.rawValue)' is registered more than once."
    case .duplicateCommand(let id):
      "The command '\(id.rawValue)' is registered more than once."
    }
  }
}
