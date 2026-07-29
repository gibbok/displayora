import DisplayoraCore

@MainActor
public protocol DisplayoraFeature {
  static var id: FeatureID { get }
  func makeContributions() throws -> FeatureContributions
}

extension DisplayoraFeature {
  public var featureID: FeatureID {
    Self.id
  }
}

@MainActor
public struct FeatureContributions {
  public let featureID: FeatureID
  public let controls: [ControlContribution]
  public let settings: [SettingContribution]
  public let capabilities: [CapabilityContribution]
  public let commands: [CommandContribution]

  public init(
    featureID: FeatureID,
    controls: [ControlContribution] = [],
    settings: [SettingContribution] = [],
    capabilities: [CapabilityContribution] = [],
    commands: [CommandContribution] = []
  ) throws {
    for control in controls where control.ownerID != featureID {
      throw FeatureRegistrationError.ownerMismatch(
        kind: .control,
        id: control.id.rawValue,
        expected: featureID,
        actual: control.ownerID
      )
    }
    for setting in settings where setting.ownerID != featureID {
      throw FeatureRegistrationError.ownerMismatch(
        kind: .setting,
        id: setting.id.rawValue,
        expected: featureID,
        actual: setting.ownerID
      )
    }
    for capability in capabilities where capability.ownerID != featureID {
      throw FeatureRegistrationError.ownerMismatch(
        kind: .capability,
        id: capability.id.rawValue,
        expected: featureID,
        actual: capability.ownerID
      )
    }
    for command in commands where command.ownerID != featureID {
      throw FeatureRegistrationError.ownerMismatch(
        kind: .command,
        id: command.id.rawValue,
        expected: featureID,
        actual: command.ownerID
      )
    }

    self.featureID = featureID
    self.controls = controls
    self.settings = settings
    self.capabilities = capabilities
    self.commands = commands
  }
}
