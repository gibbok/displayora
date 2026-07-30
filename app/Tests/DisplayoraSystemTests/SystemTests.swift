import DisplayoraDisplay
import DisplayoraSystem
import DisplayoraTestSupport
import Foundation
import Testing

struct DisplayPlatformTests {
  @Test func testReconciliationPublishesAReadyDeterministicSnapshot() async {
    let inventory = ScriptedInventory(records: [
      DisplayInventoryRecord(
        id: DisplayID(rawValue: "display.external"), stability: .persistent, name: "Zeta",
        isBuiltIn: false, isActive: true, dynamicRange: .standard),
      DisplayInventoryRecord(
        id: DisplayID(rawValue: "display.builtin"), stability: .persistent, name: "Alpha",
        isBuiltIn: true, isActive: true, dynamicRange: .standard),
    ])
    let platform = DisplayPlatform(inventory: inventory)
    await platform.reconcile()
    var iterator = await platform.snapshots().makeAsyncIterator()
    let snapshot = await iterator.next()
    XCTAssertEqual(snapshot?.phase, .ready)
    XCTAssertEqual(snapshot?.displays.map(\.id.rawValue), ["display.builtin", "display.external"])
  }

  @Test func testFailedInventoryPublishesOnlyTheSafeFailure() async {
    let platform = DisplayPlatform(inventory: ScriptedInventory(records: [], shouldFail: true))
    await platform.reconcile()
    var iterator = await platform.snapshots().makeAsyncIterator()
    let snapshot = await iterator.next()
    XCTAssertEqual(snapshot?.phase, .failed(.enumerationFailed))
    XCTAssertTrue(snapshot?.displays.isEmpty ?? false)
  }
}

struct ColorTransformCoordinatorTests {
  @Test func testContributionsComposeFromTheBaselineAndRestoreAfterLastRemoval() async throws {
    let display = DisplayID(rawValue: "display.fixture")
    let baseline = try makeCurve(1)
    let backend = ScriptedColorBackend(baseline: baseline)
    let coordinator = ColorTransformCoordinator(backend: backend)
    let first = ColorTransformContribution(
      owner: ColorTransformOwnerID(rawValue: "feature.one"), priority: 100,
      curve: try makeCurve(0.5))
    let second = ColorTransformContribution(
      owner: ColorTransformOwnerID(rawValue: "feature.two"), priority: 200,
      curve: try makeCurve(0.5))
    try await coordinator.set(first, for: display)
    try await coordinator.set(second, for: display)
    XCTAssertEqual(await backend.lastApplied()?.red.first, 0.25)
    try await coordinator.remove(owner: first.owner, from: display)
    try await coordinator.remove(owner: second.owner, from: display)
    XCTAssertEqual(await backend.lastApplied(), baseline)
  }
}

private actor ScriptedInventory: DisplayInventoryReading {
  let records: [DisplayInventoryRecord]
  let shouldFail: Bool
  init(records: [DisplayInventoryRecord], shouldFail: Bool = false) {
    self.records = records
    self.shouldFail = shouldFail
  }
  func enumerate() async throws -> [DisplayInventoryRecord] {
    if shouldFail { throw FixtureError.expected }
    return records
  }
}

private actor ScriptedColorBackend: ColorTransformBackend {
  let savedBaseline: ColorCurve
  private var applied: ColorCurve?
  init(baseline: ColorCurve) { savedBaseline = baseline }
  func baseline(for display: DisplayID) async throws -> ColorCurve { savedBaseline }
  func apply(_ curve: ColorCurve, to display: DisplayID) async throws { applied = curve }
  func restore(_ curve: ColorCurve, to display: DisplayID) async throws { applied = curve }
  func isSafe(for display: DisplayID) async -> Bool { true }
  func lastApplied() -> ColorCurve? { applied }
}

private enum FixtureError: Error { case expected }
private func makeCurve(_ value: Float) throws -> ColorCurve {
  try XCTUnwrap(
    ColorCurve(
      red: Array(repeating: value, count: 256), green: Array(repeating: value, count: 256),
      blue: Array(repeating: value, count: 256)))
}

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
