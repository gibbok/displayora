import DisplayoraCore

@MainActor
public struct FeatureRegistrySnapshot {
  public let features: [FeatureID]
  public let controls: [ControlContribution]
  public let settings: [SettingContribution]
  public let capabilities: [CapabilityContribution]
  public let commands: [CommandContribution]

  public static var empty: Self {
    Self(features: [], controls: [], settings: [], capabilities: [], commands: [])
  }

}

@MainActor
public final class FeatureRegistry {
  private var featureIDs: Set<FeatureID> = []
  private var controls: [ControlContribution] = []
  private var settings: [SettingContribution] = []
  private var capabilities: [CapabilityContribution] = []
  private var commands: [CommandContribution] = []

  public init() {}

  public var snapshot: FeatureRegistrySnapshot {
    FeatureRegistrySnapshot(
      features: featureIDs.sorted(),
      controls: controls.sorted(by: contributionOrder),
      settings: settings.sorted(by: contributionOrder),
      capabilities: capabilities.sorted(by: contributionOrder),
      commands: commands.sorted(by: contributionOrder)
    )
  }

  public func register(_ feature: any DisplayoraFeature) throws(FeatureRegistrationError) {
    let featureID = feature.featureID
    guard !featureIDs.contains(featureID) else {
      throw FeatureRegistrationError.duplicateFeature(featureID)
    }

    let contributions: FeatureContributions
    do {
      contributions = try feature.makeContributions()
    } catch let error as FeatureRegistrationError {
      throw error
    } catch {
      throw FeatureRegistrationError.featureConstruction(featureID)
    }

    guard contributions.featureID == featureID else {
      throw FeatureRegistrationError.featureIdentityMismatch(
        expected: featureID,
        actual: contributions.featureID
      )
    }

    try rejectDuplicates(in: contributions)

    featureIDs.insert(featureID)
    controls.append(contentsOf: contributions.controls)
    settings.append(contentsOf: contributions.settings)
    capabilities.append(contentsOf: contributions.capabilities)
    commands.append(contentsOf: contributions.commands)
  }

  private func rejectDuplicates(
    in contributions: FeatureContributions
  ) throws(FeatureRegistrationError) {
    var stagedControlIDs = Set(controls.map(\.id))
    for control in contributions.controls where !stagedControlIDs.insert(control.id).inserted {
      throw FeatureRegistrationError.duplicateControl(control.id)
    }

    var stagedSettingIDs = Set(settings.map(\.id))
    for setting in contributions.settings where !stagedSettingIDs.insert(setting.id).inserted {
      throw FeatureRegistrationError.duplicateSetting(setting.id)
    }

    var stagedCapabilityIDs = Set(capabilities.map(\.id))
    for capability in contributions.capabilities
    where !stagedCapabilityIDs.insert(capability.id).inserted {
      throw FeatureRegistrationError.duplicateCapability(capability.id)
    }

    var stagedCommandIDs = Set(commands.map(\.id))
    for command in contributions.commands where !stagedCommandIDs.insert(command.id).inserted {
      throw FeatureRegistrationError.duplicateCommand(command.id)
    }
  }
}

private func contributionOrder<T>(
  _ lhs: T,
  _ rhs: T,
  sortOrder: (T) -> Int,
  identifier: (T) -> String
) -> Bool {
  if sortOrder(lhs) != sortOrder(rhs) {
    return sortOrder(lhs) < sortOrder(rhs)
  }
  return identifier(lhs) < identifier(rhs)
}

@MainActor
private func contributionOrder(_ lhs: ControlContribution, _ rhs: ControlContribution) -> Bool {
  contributionOrder(lhs, rhs, sortOrder: \.sortOrder, identifier: { $0.id.rawValue })
}

@MainActor
private func contributionOrder(_ lhs: SettingContribution, _ rhs: SettingContribution) -> Bool {
  contributionOrder(lhs, rhs, sortOrder: \.sortOrder, identifier: { $0.id.rawValue })
}

@MainActor
private func contributionOrder(
  _ lhs: CapabilityContribution,
  _ rhs: CapabilityContribution
) -> Bool {
  contributionOrder(lhs, rhs, sortOrder: \.sortOrder, identifier: { $0.id.rawValue })
}

@MainActor
private func contributionOrder(_ lhs: CommandContribution, _ rhs: CommandContribution) -> Bool {
  contributionOrder(lhs, rhs, sortOrder: \.sortOrder, identifier: { $0.id.rawValue })
}
