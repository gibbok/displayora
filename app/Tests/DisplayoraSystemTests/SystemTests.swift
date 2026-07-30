import DisplayoraSystem
import DisplayoraTestSupport
import Foundation
import Testing

struct WelcomeCompletionStoreTests {
  @Test func testCompletionPersistsInAnInjectedDefaultsSuite() throws {
    let suite = "DisplayoraSystemTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
      return XCTFail("Could not create an isolated defaults suite.")
    }
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = UserDefaultsWelcomeCompletionStore(defaults: defaults)

    XCTAssertFalse(try store.isComplete())
    try store.markComplete()
    XCTAssertTrue(try store.isComplete())
  }

  @Test func testCorruptStoredValueIsRecoverable() {
    let suite = "DisplayoraSystemTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
      return XCTFail("Could not create an isolated defaults suite.")
    }
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("invalid", forKey: UserDefaultsWelcomeCompletionStore.key)

    XCTAssertThrowsError(try UserDefaultsWelcomeCompletionStore(defaults: defaults).isComplete()) {
      XCTAssertEqual($0 as? WelcomeCompletionStoreError, .unreadable)
    }
  }
}

@MainActor
struct LaunchAtLoginContractTests {
  @Test func testFakeManagerOnlyChangesStateAfterExplicitOperation() throws {
    let manager = FakeLaunchAtLoginManager(status: .disabled)
    XCTAssertEqual(manager.status(), .disabled)
    try manager.enable()
    XCTAssertEqual(manager.status(), .enabled)
    try manager.disable()
    XCTAssertEqual(manager.status(), .disabled)
  }
}

@MainActor
private final class FakeLaunchAtLoginManager: LaunchAtLoginManaging {
  private var currentStatus: LaunchAtLoginStatus

  init(status: LaunchAtLoginStatus) {
    currentStatus = status
  }

  func status() -> LaunchAtLoginStatus { currentStatus }
  func enable() throws(LaunchAtLoginError) { currentStatus = .enabled }
  func disable() throws(LaunchAtLoginError) { currentStatus = .disabled }
  func openLoginItemsSettings() {}
}
