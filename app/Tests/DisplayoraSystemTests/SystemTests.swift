import DisplayoraCore
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

  @Test func testChangeEventCoalescesIntoOneFreshReconciliation() async throws {
    let inventory = ScriptedInventory(records: [])
    let platform = DisplayPlatform(inventory: inventory)
    await platform.receive(.changed)
    await platform.receive(.changed)
    try await Task.sleep(for: .milliseconds(260))
    var iterator = await platform.snapshots().makeAsyncIterator()
    XCTAssertEqual(await iterator.next()?.phase, .ready)
    XCTAssertEqual(await inventory.enumerationCount(), 1)
  }
}

struct DisplayIdentityResolverTests {
  @Test func testUsesSystemUUIDBeforeAnyOtherMaterial() {
    let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let resolved = DisplayIdentityResolver(epoch: UUID())
      .resolve(DisplayIdentityMaterial(systemUUID: uuid, manufacturer: 1, product: 2, serial: 3, connectionToken: "a"))
    XCTAssertEqual(resolved.0.rawValue, "display.uuid.00000000-0000-0000-0000-000000000001")
    XCTAssertEqual(resolved.1, .persistent)
  }

  @Test func testFallsBackToConnectionScopedIdentityWithoutSafeMaterial() {
    let epoch = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let resolved = DisplayIdentityResolver(epoch: epoch)
      .resolve(DisplayIdentityMaterial(systemUUID: nil, manufacturer: 1, product: 2, serial: 0, connectionToken: "a"))
    XCTAssertEqual(resolved.1, .connectionScoped)
    XCTAssertTrue(resolved.0.rawValue.contains(".a"))
  }
}

struct CapabilitySelectionTests {
  @Test func testHardwareWinsOverSoftware() {
    let hardware = CapabilityProbeResult.usable(AdapterDescriptor(id: "hardware"))
    let software = CapabilityProbeResult.usable(AdapterDescriptor(id: "software"))
    XCTAssertEqual(CapabilitySelection.resolve(hardware: hardware, software: software), .hardware(AdapterDescriptor(id: "hardware")))
  }

  @Test func testSoftwareRecordsUnsupportedHardware() {
    let result = CapabilitySelection.resolve(hardware: .unsupported, software: .usable(AdapterDescriptor(id: "software")))
    XCTAssertEqual(result, .softwareFallback(AdapterDescriptor(id: "software"), .hardwareUnsupported))
  }
}

struct CapabilityProbeSchedulerTests {
  @Test func testRejectsDuplicateRegistrationsBeforeProbing() throws {
    XCTAssertThrowsError(try CapabilityProbeScheduler(probes: [FixtureProbe(.hardware), FixtureProbe(.hardware)]))
  }
}

private struct FixtureProbe: DisplayCapabilityProbing {
  let mechanism: CapabilityMechanism
  init(_ mechanism: CapabilityMechanism) { self.mechanism = mechanism }
  let owner = FeatureID(rawValue: "fixture")!
  let capabilityID = DisplayCapabilityID(rawValue: "fixture.capability")!
  func probe(_ endpoint: DisplayProbeEndpoint) async -> CapabilityProbeResult {
    .usable(AdapterDescriptor(id: mechanism.rawValue))
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

  @Test func testUnsafeDynamicRangeRestoresAndDropsPriorContribution() async throws {
    let display = DisplayID(rawValue: "display.hdr")
    let baseline = try makeCurve(1)
    let backend = ScriptedColorBackend(baseline: baseline)
    let coordinator = ColorTransformCoordinator(backend: backend)
    let contribution = ColorTransformContribution(
      owner: ColorTransformOwnerID(rawValue: "feature.one"), priority: 100,
      curve: try makeCurve(0.5))
    try await coordinator.set(contribution, for: display)
    await backend.setSafe(false)
    await XCTAssertThrowsErrorAsync {
      try await coordinator.set(contribution, for: display)
    }
    XCTAssertEqual(await backend.lastApplied(), baseline)
  }
}

private actor ScriptedInventory: DisplayInventoryReading {
  let records: [DisplayInventoryRecord]
  let shouldFail: Bool
  private var count = 0
  init(records: [DisplayInventoryRecord], shouldFail: Bool = false) {
    self.records = records
    self.shouldFail = shouldFail
  }
  func enumerate() async throws -> [DisplayInventoryRecord] {
    count += 1
    if shouldFail { throw FixtureError.expected }
    return records
  }
  func enumerationCount() -> Int { count }
}

private actor ScriptedColorBackend: ColorTransformBackend {
  let savedBaseline: ColorCurve
  private var applied: ColorCurve?
  private var safe = true
  init(baseline: ColorCurve) { savedBaseline = baseline }
  func baseline(for display: DisplayID) async throws -> ColorCurve { savedBaseline }
  func apply(_ curve: ColorCurve, to display: DisplayID) async throws { applied = curve }
  func restore(_ curve: ColorCurve, to display: DisplayID) async throws { applied = curve }
  func isSafe(for display: DisplayID) async -> Bool { safe }
  func setSafe(_ value: Bool) { safe = value }
  func lastApplied() -> ColorCurve? { applied }
}

private func XCTAssertThrowsErrorAsync(_ expression: () async throws -> Void) async {
  do { try await expression(); XCTFail("Expected an error to be thrown") } catch {}
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
