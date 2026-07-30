import SwiftUI

public struct ShellDisplayStatusFailure: Equatable, Sendable {
  public let code: String
  public let recoveryMessage: String

  public init(code: String, recoveryMessage: String) {
    self.code = code
    self.recoveryMessage = recoveryMessage
  }
}

public enum ShellDisplayStatus: Equatable, Sendable {
  case loading
  case available
  case noDisplays
  case failed(ShellDisplayStatusFailure)
}

public enum ShellAction: Sendable {
  case continueWelcome
  case retryRegistration
  case retryDisplayStatus
  case openSettings
  case quit
  case refreshLoginItem
  case setLaunchAtLogin(Bool)
  case openLoginItemsSettings
  case dismissLoginError
}

public enum MenuBarPresentation {
  case loading
  case registrationFailed(message: String)
  case welcome(message: String?)
  case empty
  case displayLoading(FeatureRegistrySnapshot)
  case available(FeatureRegistrySnapshot)
  case noDisplays(FeatureRegistrySnapshot)
  case displayFailed(FeatureRegistrySnapshot, ShellDisplayStatusFailure)
}

public struct SettingsPresentation {
  public let snapshot: FeatureRegistrySnapshot?
  public let isLoading: Bool
  public let launchAtLoginEnabled: Bool
  public let launchAtLoginAvailable: Bool
  public let requiresLoginApproval: Bool
  public let loginError: String?
  public let version: String
  public let build: String

  public init(
    snapshot: FeatureRegistrySnapshot?,
    isLoading: Bool,
    launchAtLoginEnabled: Bool,
    launchAtLoginAvailable: Bool,
    requiresLoginApproval: Bool,
    loginError: String?,
    version: String,
    build: String
  ) {
    self.snapshot = snapshot
    self.isLoading = isLoading
    self.launchAtLoginEnabled = launchAtLoginEnabled
    self.launchAtLoginAvailable = launchAtLoginAvailable
    self.requiresLoginApproval = requiresLoginApproval
    self.loginError = loginError
    self.version = version
    self.build = build
  }
}

public struct MenuBarRoot: View {
  private let presentation: MenuBarPresentation
  private let perform: @MainActor (ShellAction) -> Void

  public init(
    presentation: MenuBarPresentation,
    perform: @escaping @MainActor (ShellAction) -> Void
  ) {
    self.presentation = presentation
    self.perform = perform
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text("Displayora")
          .font(.headline)
          .accessibilityLabel("Displayora")
        content
        Divider()
        if #available(macOS 14.0, *) {
          ModernSettingsButton()
        } else {
          Button("Settings…") { perform(.openSettings) }
            .keyboardShortcut(",")
            .accessibilityLabel("Open Displayora Settings")
        }
        Button("Quit Displayora") { perform(.quit) }
          .keyboardShortcut("q")
          .accessibilityLabel("Quit Displayora")
      }
      .padding()
    }
    .frame(width: 320)
    .frame(maxHeight: 480)
  }

  @ViewBuilder
  private var content: some View {
    switch presentation {
    case .loading:
      statusText("Loading display controls…")
    case .registrationFailed(let message):
      statusText("Displayora couldn’t load its controls.")
      statusText(message)
      Button("Try Again") { perform(.retryRegistration) }
        .accessibilityLabel("Try Again")
    case .welcome(let error):
      Text("Your displays, made simple")
        .font(.title3)
        .accessibilityAddTraits(.isHeader)
      Text(
        "Displayora lives in the menu bar. Open it here whenever you want to adjust an included display control."
      )
      if let error { statusText(error) }
      Button("Continue") { perform(.continueWelcome) }
        .accessibilityLabel("Continue")
    case .empty:
      statusText("No display controls are included in this build.")
    case .displayLoading(let snapshot):
      statusText("Looking for displays…")
      controls(snapshot, disabled: true)
    case .available(let snapshot):
      controls(snapshot, disabled: false)
    case .noDisplays:
      statusText("No displays available")
      Text("Connect or wake a display. Displayora will update automatically.")
    case .displayFailed(_, let failure):
      statusText("Displayora can’t check your displays right now.")
      statusText(failure.recoveryMessage)
      Button("Try Again") { perform(.retryDisplayStatus) }
        .accessibilityLabel("Try Again")
    }
  }

  @ViewBuilder
  private func controls(_ snapshot: FeatureRegistrySnapshot, disabled: Bool) -> some View {
    ForEach(Array(snapshot.controls.enumerated()), id: \.element.id) { index, contribution in
      if index > 0 { Divider() }
      contribution.makeView()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(contribution.accessibilityLabel)
        .disabled(disabled)
    }
  }

  private func statusText(_ value: String) -> some View {
    Text(value)
      .accessibilityLabel(value)
      .accessibilityAddTraits(.isStaticText)
  }
}

@available(macOS 14.0, *)
private struct ModernSettingsButton: View {
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Button("Settings…") {
      openSettings()
    }
    .keyboardShortcut(",")
    .accessibilityLabel("Open Displayora Settings")
  }
}

public struct SettingsRoot: View {
  private let presentation: SettingsPresentation
  private let perform: @MainActor (ShellAction) -> Void

  public init(
    presentation: SettingsPresentation,
    perform: @escaping @MainActor (ShellAction) -> Void
  ) {
    self.presentation = presentation
    self.perform = perform
  }

  public var body: some View {
    TabView {
      general
        .tabItem { Text("General") }
      featureSettings
        .tabItem { Text("Features") }
      about
        .tabItem { Text("About") }
    }
    .padding(24)
    .frame(minWidth: 420, minHeight: 300)
    .onAppear { perform(.refreshLoginItem) }
  }

  private var general: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle(
        "Launch Displayora at login",
        isOn: Binding(
          get: { presentation.launchAtLoginEnabled },
          set: { perform(.setLaunchAtLogin($0)) }
        )
      )
      .disabled(!presentation.launchAtLoginAvailable)
      .accessibilityLabel("Launch Displayora at login")
      if presentation.requiresLoginApproval {
        Text("Allow Displayora in Login Items to finish setup.")
        Button("Open Login Items Settings…") { perform(.openLoginItemsSettings) }
      }
      if let error = presentation.loginError {
        HStack {
          Text(error)
          Button("Dismiss") { perform(.dismissLoginError) }
        }
      }
      Spacer()
    }
  }

  @ViewBuilder
  private var featureSettings: some View {
    if presentation.isLoading {
      Text("Loading settings…")
    } else if let snapshot = presentation.snapshot, !snapshot.settings.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(snapshot.settings, id: \.id) { contribution in
          contribution.makeView()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(contribution.accessibilityLabel)
        }
      }
    } else {
      Text("No settings are included in this build.")
    }
  }

  private var about: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Displayora")
        .font(.title2)
      Text("Your displays, made simple.")
      Text("Version \(presentation.version) (\(presentation.build))")
      Text("com.displayora.Displayora")
      Spacer()
    }
  }
}
