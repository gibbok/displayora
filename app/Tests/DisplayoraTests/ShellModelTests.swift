import DisplayoraCore
import DisplayoraSystem
import DisplayoraTestSupport
import DisplayoraUI
import Testing

@testable import Displayora

@MainActor
struct ShellModelTests {
  @Test func testWelcomeOutranksTheEmptyBuildUntilContinue() {
    let model = ApplicationModel(
      installedFeatures: [],
      welcomeStore: FakeWelcomeStore(isComplete: false),
      launchAtLoginManager: FakeLaunchAtLoginManager()
    )

    model.load()
    guard case .welcome = model.menuBarPresentation else {
      return XCTFail("Expected welcome before the empty-build presentation.")
    }

    model.perform(.continueWelcome)
    guard case .empty = model.menuBarPresentation else {
      return XCTFail("Expected the empty-build presentation after Continue.")
    }
  }

  @Test func testRegistrationFailureOutranksWelcome() {
    let model = ApplicationModel(
      installedFeatures: [FailingShellFixture()],
      welcomeStore: FakeWelcomeStore(isComplete: false),
      launchAtLoginManager: FakeLaunchAtLoginManager()
    )

    model.load()
    guard case .registrationFailed = model.menuBarPresentation else {
      return XCTFail("Expected registration failure to outrank welcome.")
    }
  }

  @Test func testLoginItemFailureRestoresQueriedStatusAndShowsRecoverableText() {
    let login = FakeLaunchAtLoginManager(failEnable: true)
    let model = ApplicationModel(
      installedFeatures: [],
      welcomeStore: FakeWelcomeStore(isComplete: true),
      launchAtLoginManager: login
    )

    model.load()
    model.perform(.setLaunchAtLogin(true))

    XCTAssertFalse(model.settingsPresentation.launchAtLoginEnabled)
    XCTAssertEqual(
      model.settingsPresentation.loginError,
      "Displayora couldn’t update this setting."
    )
  }
}

private final class FakeWelcomeStore: WelcomeCompletionStoring, @unchecked Sendable {
  private var value: Bool

  init(isComplete: Bool) {
    value = isComplete
  }

  func isComplete() throws(WelcomeCompletionStoreError) -> Bool { value }
  func markComplete() throws(WelcomeCompletionStoreError) { value = true }
}

@MainActor
private final class FakeLaunchAtLoginManager: LaunchAtLoginManaging {
  private let failEnable: Bool
  private var currentStatus: LaunchAtLoginStatus = .disabled

  init(failEnable: Bool = false) {
    self.failEnable = failEnable
  }

  func status() -> LaunchAtLoginStatus { currentStatus }

  func enable() throws(LaunchAtLoginError) {
    if failEnable { throw .operationFailed }
    currentStatus = .enabled
  }

  func disable() throws(LaunchAtLoginError) { currentStatus = .disabled }
  func openLoginItemsSettings() {}
}

@MainActor
private struct FailingShellFixture: DisplayoraFeature {
  static let id: FeatureID = {
    guard let identifier = FeatureID(rawValue: "shell-failure") else {
      preconditionFailure("The shell failure fixture identifier must remain valid.")
    }
    return identifier
  }()

  func makeContributions() throws -> FeatureContributions {
    throw ShellFixtureError.expected
  }
}

private enum ShellFixtureError: Error {
  case expected
}
