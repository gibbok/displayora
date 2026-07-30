import Combine
import DisplayoraCore
import DisplayoraSystem
import DisplayoraUI

public protocol ShellDisplayStatusProviding: Sendable {
  func statusUpdates() -> AsyncStream<ShellDisplayStatus>
  func retry() async
}

@MainActor
public enum ApplicationState {
  case registering
  case ready(FeatureRegistrySnapshot)
  case failed(FeatureRegistrationError)
}

@MainActor
public final class ApplicationModel: ObservableObject {
  @Published public private(set) var state: ApplicationState = .registering
  @Published public private(set) var menuBarPresentation: MenuBarPresentation = .loading
  @Published public private(set) var settingsPresentation: SettingsPresentation
  public private(set) var registry: FeatureRegistry

  private let installedFeatures: [any DisplayoraFeature]
  private let welcomeStore: any WelcomeCompletionStoring
  private let displayStatusProvider: (any ShellDisplayStatusProviding)?
  private let launchAtLoginManager: any LaunchAtLoginManaging
  private var welcomeComplete = false
  private var welcomeError: String?
  private var displayStatus: ShellDisplayStatus = .loading
  private var observationTask: Task<Void, Never>?

  public init(
    installedFeatures: [any DisplayoraFeature],
    welcomeStore: any WelcomeCompletionStoring = UserDefaultsWelcomeCompletionStore(),
    displayStatusProvider: (any ShellDisplayStatusProviding)? = nil,
    launchAtLoginManager: any LaunchAtLoginManaging = SystemLaunchAtLoginManager(),
    version: String = "0.1.0",
    build: String = "1"
  ) {
    self.installedFeatures = installedFeatures
    self.welcomeStore = welcomeStore
    self.displayStatusProvider = displayStatusProvider
    self.launchAtLoginManager = launchAtLoginManager
    registry = FeatureRegistry()
    settingsPresentation = SettingsPresentation(
      snapshot: nil,
      isLoading: true,
      launchAtLoginEnabled: false,
      launchAtLoginAvailable: true,
      requiresLoginApproval: false,
      loginError: nil,
      version: version,
      build: build
    )
  }

  deinit {
    observationTask?.cancel()
  }

  public func load() {
    observationTask?.cancel()
    state = .registering
    refreshPresentations()
    let replacement = FeatureRegistry()

    do {
      for feature in installedFeatures {
        try replacement.register(feature)
      }
      registry = replacement
      state = .ready(replacement.snapshot)
      readWelcomeCompletion()
    } catch let error {
      registry = FeatureRegistry()
      state = .failed(error)
    }
    refreshPresentations()
    observeDisplayStatusIfNeeded()
  }

  public func retry() {
    load()
  }

  public func perform(_ action: ShellAction) {
    switch action {
    case .continueWelcome:
      completeWelcome()
    case .retryRegistration:
      retry()
    case .retryDisplayStatus:
      retryDisplayStatus()
    case .openSettings:
      break
    case .quit:
      break
    case .refreshLoginItem:
      refreshLoginItem()
    case .setLaunchAtLogin(let enabled):
      setLaunchAtLogin(enabled)
    case .openLoginItemsSettings:
      launchAtLoginManager.openLoginItemsSettings()
    case .dismissLoginError:
      updateSettings(loginError: nil)
    }
  }

  public func openedSettings() {
    refreshLoginItem()
  }

  private func readWelcomeCompletion() {
    do {
      welcomeComplete = try welcomeStore.isComplete()
      welcomeError = nil
    } catch {
      welcomeComplete = false
      welcomeError = WelcomeCompletionStoreError.unreadable.localizedDescription
    }
  }

  private func completeWelcome() {
    do {
      try welcomeStore.markComplete()
      welcomeComplete = true
      welcomeError = nil
      refreshPresentations()
      observeDisplayStatusIfNeeded()
    } catch {
      welcomeError = WelcomeCompletionStoreError.unwritable.localizedDescription
      refreshPresentations()
    }
  }

  private func observeDisplayStatusIfNeeded() {
    observationTask?.cancel()
    guard case .ready(let snapshot) = state, welcomeComplete, !snapshot.controls.isEmpty,
      let displayStatusProvider
    else {
      return
    }
    displayStatus = .loading
    refreshPresentations()
    let stream = displayStatusProvider.statusUpdates()
    observationTask = Task { [weak self] in
      var receivedValue = false
      for await status in stream {
        guard !Task.isCancelled else { return }
        receivedValue = true
        self?.receiveDisplayStatus(status)
      }
      if !receivedValue, !Task.isCancelled {
        self?.receiveDisplayStatus(
          .failed(
            ShellDisplayStatusFailure(
              code: "status-stream-ended",
              recoveryMessage: "Try Again to check your displays."
            )
          )
        )
      }
    }
  }

  private func receiveDisplayStatus(_ status: ShellDisplayStatus) {
    guard status != displayStatus else { return }
    displayStatus = status
    refreshPresentations()
  }

  private func retryDisplayStatus() {
    guard let displayStatusProvider else { return }
    displayStatus = .loading
    refreshPresentations()
    Task { await displayStatusProvider.retry() }
  }

  private func refreshPresentations() {
    switch state {
    case .registering:
      menuBarPresentation = .loading
    case .failed(let error):
      menuBarPresentation = .registrationFailed(message: error.localizedDescription)
    case .ready(let snapshot):
      if !welcomeComplete {
        menuBarPresentation = .welcome(message: welcomeError)
      } else if snapshot.controls.isEmpty {
        menuBarPresentation = .empty
      } else {
        switch displayStatus {
        case .loading:
          menuBarPresentation = .displayLoading(snapshot)
        case .available:
          menuBarPresentation = .available(snapshot)
        case .noDisplays:
          menuBarPresentation = .noDisplays(snapshot)
        case .failed(let failure):
          menuBarPresentation = .displayFailed(snapshot, failure)
        }
      }
    }
    updateSettings(loginError: settingsPresentation.loginError)
  }

  private func refreshLoginItem() {
    updateSettings(loginError: settingsPresentation.loginError)
  }

  private func setLaunchAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try launchAtLoginManager.enable()
      } else {
        try launchAtLoginManager.disable()
      }
      updateSettings(loginError: nil)
    } catch {
      updateSettings(loginError: "Displayora couldn’t update this setting.")
    }
  }

  private func updateSettings(loginError: String?) {
    let status = launchAtLoginManager.status()
    let snapshot: FeatureRegistrySnapshot?
    let isLoading: Bool
    switch state {
    case .ready(let readySnapshot):
      snapshot = readySnapshot
      isLoading = false
    case .registering:
      snapshot = nil
      isLoading = true
    case .failed:
      snapshot = nil
      isLoading = false
    }
    settingsPresentation = SettingsPresentation(
      snapshot: snapshot,
      isLoading: isLoading,
      launchAtLoginEnabled: status == .enabled,
      launchAtLoginAvailable: status != .unavailable,
      requiresLoginApproval: status == .requiresApproval,
      loginError: loginError,
      version: settingsPresentation.version,
      build: settingsPresentation.build
    )
  }
}
