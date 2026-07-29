import Combine
import DisplayoraUI

@MainActor
public enum ApplicationState {
  case registering
  case ready(FeatureRegistrySnapshot)
  case failed(FeatureRegistrationError)
}

@MainActor
public final class ApplicationModel: ObservableObject {
  @Published public private(set) var state: ApplicationState = .registering
  public private(set) var registry: FeatureRegistry

  private let installedFeatures: [any DisplayoraFeature]

  public init(installedFeatures: [any DisplayoraFeature]) {
    self.installedFeatures = installedFeatures
    registry = FeatureRegistry()
  }

  public func load() {
    state = .registering
    let replacement = FeatureRegistry()

    do {
      for feature in installedFeatures {
        try replacement.register(feature)
      }
      registry = replacement
      state = .ready(replacement.snapshot)
    } catch {
      registry = FeatureRegistry()
      state = .failed(error)
    }
  }

  public func retry() {
    load()
  }
}
