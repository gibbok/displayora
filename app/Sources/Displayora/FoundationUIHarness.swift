#if DISPLAYORA_FOUNDATION_UI_HARNESS
  import DisplayoraCore
  import DisplayoraUI
  import SwiftUI

  @MainActor
  struct FoundationUIHarness {
    let installedFeatures: [any DisplayoraFeature]
    let shouldLoad: Bool

    init(arguments: [String]) {
      let state = arguments.dropFirst().first ?? "loading"
      switch state {
      case "loading":
        installedFeatures = []
        shouldLoad = false
      case "populated":
        installedFeatures = [FoundationPopulatedFixture()]
        shouldLoad = true
      case "failed":
        installedFeatures = [FoundationRetryFixture()]
        shouldLoad = true
      default:
        installedFeatures = []
        shouldLoad = false
      }
    }
  }

  @MainActor
  private struct FoundationPopulatedFixture: DisplayoraFeature {
    static let id = foundationHarnessFeatureID

    func makeContributions() throws -> FeatureContributions {
      try foundationHarnessContributions()
    }
  }

  @MainActor
  private final class FoundationRetryFixture: DisplayoraFeature {
    static let id = foundationHarnessFeatureID
    private var attempts = 0

    func makeContributions() throws -> FeatureContributions {
      attempts += 1
      guard attempts > 1 else {
        throw FoundationHarnessError.expectedRegistrationFailure
      }
      return try foundationHarnessContributions()
    }
  }

  private enum FoundationHarnessError: Error {
    case expectedRegistrationFailure
  }

  @MainActor
  private func foundationHarnessContributions() throws -> FeatureContributions {
    try FeatureContributions(
      featureID: foundationHarnessFeatureID,
      controls: [
        try ControlContribution(
          id: foundationHarnessControlID,
          ownerID: foundationHarnessFeatureID,
          label: "Foundation fixture control",
          accessibilityLabel: "Foundation fixture display control",
          sortOrder: 0,
          viewFactory: {
            AnyView(Text("Foundation fixture display control"))
          }
        )
      ],
      settings: [
        try SettingContribution(
          id: foundationHarnessSettingID,
          ownerID: foundationHarnessFeatureID,
          label: "Foundation fixture setting",
          accessibilityLabel: "Foundation fixture display setting",
          sortOrder: 0,
          viewFactory: {
            AnyView(Text("Foundation fixture display setting"))
          }
        )
      ]
    )
  }

  private let foundationHarnessFeatureID: FeatureID = {
    guard let identifier = FeatureID(rawValue: "foundation-fixture") else {
      preconditionFailure("The compile-time foundation fixture ID must remain valid.")
    }
    return identifier
  }()

  private let foundationHarnessControlID: ControlID = {
    guard let identifier = ControlID(rawValue: "foundation-fixture.control") else {
      preconditionFailure("The compile-time foundation control ID must remain valid.")
    }
    return identifier
  }()

  private let foundationHarnessSettingID: SettingID = {
    guard let identifier = SettingID(rawValue: "foundation-fixture.setting") else {
      preconditionFailure("The compile-time foundation setting ID must remain valid.")
    }
    return identifier
  }()
#endif
