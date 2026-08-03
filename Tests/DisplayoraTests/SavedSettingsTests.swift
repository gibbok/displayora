import AppKit
import CoreGraphics
import Testing

@testable import Displayora

@Suite("Saved settings")
struct SavedSettingsTests {
  @Test("UserDefaults store round-trips a versioned collection and starts empty")
  func storeRoundTrip() throws {
    let suite = "DisplayoraTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = UserDefaultsSavedSettingsStore(defaults: defaults)
    #expect(try store.load().isEmpty)

    let setting = Self.makeSetting(name: "Desk")
    try store.save([setting])
    #expect(try store.load() == [setting])
    #expect(defaults.data(forKey: UserDefaultsSavedSettingsStore.key) != nil)
  }

  @Test("A new controller loads saved setups without applying or activating them")
  func controllerReloadsSavedSettingsWithoutApplying() throws {
    let store = MemorySavedSettingsStore()
    let firstBackend = ProfileDisplayBackend(
      online: [10], active: [10], brightness: [10: 55])
    let firstController = DisplayController(
      backend: firstBackend, savedSettingsStore: store)
    try firstController.setNightMode(.warm)
    let saved = try firstController.createSavedSettings(named: "Desk")

    let relaunchedBackend = ProfileDisplayBackend(
      online: [10], active: [10], brightness: [10: 100])
    let relaunchedController = DisplayController(
      backend: relaunchedBackend, savedSettingsStore: store)

    #expect(relaunchedController.savedSettings == [saved])
    #expect(relaunchedController.activeSavedSettingsID == nil)
    #expect(relaunchedController.nightMode == .none)
    #expect(relaunchedBackend.batchCalls.isEmpty)
    #expect(relaunchedBackend.brightnessCalls.isEmpty)
    #expect(relaunchedBackend.nightModeCalls.isEmpty)
  }

  @Test("Saving captures stable identities, disabled brightness, and Night mode")
  func captureCompleteConfiguration() throws {
    let backend = ProfileDisplayBackend(
      online: [10, 20], active: [10, 20], names: [10: "Built-in", 20: "Studio"],
      brightness: [10: 40, 20: 75])
    let store = MemorySavedSettingsStore()
    let controller = DisplayController(backend: backend, savedSettingsStore: store)

    _ = try controller.setDisplay(20, enabled: false)
    try controller.setNightMode(.warm)
    let setting = try controller.createSavedSettings()

    #expect(setting.name == "Settings 1")
    #expect(setting.configuration.nightMode == .warm)
    #expect(
      setting.configuration.monitors == [
        .init(
          displayUUID: DisplayIdentity.fallbackUUID(for: 10), lastKnownName: "Built-in",
          isEnabled: true, brightnessPercentage: 40),
        .init(
          displayUUID: DisplayIdentity.fallbackUUID(for: 20), lastKnownName: "Studio",
          isEnabled: false, brightnessPercentage: 75),
      ])
    #expect(controller.activeSavedSettingsID == setting.id)
    #expect(store.settings == [setting])
  }

  @Test("Default names use the first available number; rename and delete persist")
  func namingRenameAndDelete() throws {
    let backend = ProfileDisplayBackend(online: [10], active: [10])
    let store = MemorySavedSettingsStore()
    let controller = DisplayController(backend: backend, savedSettingsStore: store)
    let first = try controller.createSavedSettings()
    let second = try controller.createSavedSettings()
    try controller.renameSavedSettings(id: second.id, to: "  Travel  ")
    try controller.deleteSavedSettings(id: first.id)
    let replacement = try controller.createSavedSettings()

    #expect(controller.savedSettings.map(\.name) == ["Travel", "Settings 1"])
    #expect(replacement.name == "Settings 1")
    #expect(store.settings == controller.savedSettings)

    let relaunchedController = DisplayController(
      backend: ProfileDisplayBackend(online: [10], active: [10]),
      savedSettingsStore: store)
    #expect(relaunchedController.savedSettings.map(\.name) == ["Travel", "Settings 1"])
    #expect(relaunchedController.activeSavedSettingsID == nil)
  }

  @Test("Applying uses one batch update, restores brightness and Night mode, then activates")
  func compatibleApply() throws {
    let backend = ProfileDisplayBackend(
      online: [10, 20], active: [10, 20], names: [10: "Built-in", 20: "Studio"],
      brightness: [10: 100, 20: 100])
    let setting = Self.makeSetting(
      monitors: [
        .init(
          displayUUID: DisplayIdentity.fallbackUUID(for: 10), lastKnownName: "Built-in",
          isEnabled: true, brightnessPercentage: 45),
        .init(
          displayUUID: DisplayIdentity.fallbackUUID(for: 20), lastKnownName: "Studio",
          isEnabled: false, brightnessPercentage: 70),
      ], nightMode: .warm)
    let store = MemorySavedSettingsStore([setting])
    let controller = DisplayController(backend: backend, savedSettingsStore: store)

    let displays = try controller.applySavedSettings(id: setting.id)

    #expect(backend.batchCalls == [[10: true, 20: false]])
    #expect(backend.brightnessCalls == [.init(id: 10, percentage: 45)])
    #expect(backend.nightModeCalls == [.warm])
    #expect(displays.map(\.isActive) == [true, false])
    #expect(controller.nightMode == .warm)
    #expect(controller.activeSavedSettingsID == setting.id)

    try controller.setNightMode(.none)
    let disabledMonitor = try #require(
      store.settings[0].configuration.monitors.first { !$0.isEnabled })
    #expect(disabledMonitor.brightnessPercentage == 70)
  }

  @Test("Missing and additional monitors reject apply without backend mutations")
  func incompatibleApply() throws {
    let savedMonitor = SavedMonitorConfiguration(
      displayUUID: DisplayIdentity.fallbackUUID(for: 10), lastKnownName: "Saved monitor",
      isEnabled: true, brightnessPercentage: 50)
    let setting = Self.makeSetting(monitors: [savedMonitor])
    let backend = ProfileDisplayBackend(
      online: [20], active: [20], names: [20: "New monitor"])
    let controller = DisplayController(
      backend: backend, savedSettingsStore: MemorySavedSettingsStore([setting]))

    #expect(
      throws: DisplayControllerError.incompatibleSavedSettings(
        missing: ["Saved monitor"], additional: ["New monitor"])
    ) {
      try controller.applySavedSettings(id: setting.id)
    }
    #expect(backend.batchCalls.isEmpty)
    #expect(backend.brightnessCalls.isEmpty)
    #expect(backend.nightModeCalls.isEmpty)
  }

  @Test("Invalid brightness and all-disabled profiles reject apply before mutation")
  func invalidProfiles() throws {
    let backend = ProfileDisplayBackend(online: [10], active: [10])
    var disabled = Self.makeSetting()
    disabled.configuration.monitors[0].isEnabled = false
    var invalidBrightness = Self.makeSetting()
    invalidBrightness.configuration.monitors[0].brightnessPercentage = 42
    let store = MemorySavedSettingsStore([disabled, invalidBrightness])
    let controller = DisplayController(backend: backend, savedSettingsStore: store)

    #expect(throws: DisplayControllerError.allDisplaysDisabled) {
      try controller.applySavedSettings(id: disabled.id)
    }
    #expect(throws: DisplayControllerError.invalidBrightnessPercentage) {
      try controller.applySavedSettings(id: invalidBrightness.id)
    }
    #expect(backend.batchCalls.isEmpty)
  }

  @Test("Active edits remain modified until updated; Manual edits do not affect the setup")
  func activeAndScratchEdits() throws {
    let backend = ProfileDisplayBackend(
      online: [10], active: [10], brightness: [10: 50])
    let store = MemorySavedSettingsStore()
    let controller = DisplayController(backend: backend, savedSettingsStore: store)
    let setting = try controller.createSavedSettings()

    _ = try controller.setBrightnessPercentage(65, for: 10)
    try controller.setNightMode(.warm)
    #expect(controller.activeSavedSettingsIsModified)
    #expect(store.settings[0].configuration.monitors[0].brightnessPercentage == 50)
    #expect(store.settings[0].configuration.nightMode == .none)

    try controller.updateActiveSavedSettings()
    #expect(!controller.activeSavedSettingsIsModified)
    #expect(store.settings[0].configuration.monitors[0].brightnessPercentage == 65)
    #expect(store.settings[0].configuration.nightMode == .warm)

    controller.selectNoSavedSettings()
    _ = try controller.setBrightnessPercentage(80, for: 10)
    try controller.setNightMode(.none)
    #expect(store.settings[0].configuration.monitors[0].brightnessPercentage == 65)
    #expect(store.settings[0].configuration.nightMode == .warm)
    #expect(controller.savedSettings.first?.id == setting.id)
    #expect(controller.activeSavedSettingsID == nil)
  }

  @Test("Reset enables every display, restores brightness, and turns off Night mode")
  func resetDisplays() throws {
    let backend = ProfileDisplayBackend(
      online: [10, 20], active: [10], brightness: [10: 35, 20: 60])
    let controller = DisplayController(
      backend: backend, savedSettingsStore: MemorySavedSettingsStore())
    try controller.setNightMode(.warm)

    let displays = try controller.resetDisplays()

    #expect(backend.batchCalls == [[10: true, 20: true]])
    #expect(
      backend.brightnessCalls == [
        .init(id: 10, percentage: 100), .init(id: 20, percentage: 100),
      ])
    #expect(displays.map(\.isActive) == [true, true])
    #expect(displays.map(\.brightnessPercentage) == [100, 100])
    #expect(backend.nightModeCalls == [.warm, .none])
    #expect(controller.nightMode == .none)
  }

  @Test("A failed explicit update preserves the active setup and its saved snapshot")
  func updateFailure() throws {
    let backend = ProfileDisplayBackend(
      online: [10], active: [10], brightness: [10: 50])
    let store = MemorySavedSettingsStore()
    let controller = DisplayController(backend: backend, savedSettingsStore: store)
    let original = try controller.createSavedSettings()
    _ = try controller.setBrightnessPercentage(70, for: 10)
    store.failSaves = true

    #expect(throws: DisplayControllerError.savedSettingsUpdateFailed) {
      try controller.updateActiveSavedSettings()
    }
    #expect(backend.brightness[10] == 70)
    #expect(controller.activeSavedSettingsID == original.id)
    #expect(controller.activeSavedSettingsIsModified)
    #expect(controller.savedSettings == [original])
    #expect(store.settings == [original])
  }

  @Test("Topology changes and deleting the active profile detach without display changes")
  func detachWithoutMutation() throws {
    let backend = ProfileDisplayBackend(online: [10], active: [10])
    let store = MemorySavedSettingsStore()
    let controller = DisplayController(backend: backend, savedSettingsStore: store)
    let setting = try controller.createSavedSettings()
    backend.online.append(20)
    backend.active.append(20)
    backend.names[20] = "Projector"

    _ = try controller.displays()
    #expect(controller.activeSavedSettingsID == nil)
    #expect(controller.savedSettings == [setting])
    #expect(backend.batchCalls.isEmpty)

    let deleteBackend = ProfileDisplayBackend(online: [10], active: [10])
    let deleteStore = MemorySavedSettingsStore()
    let deleteController = DisplayController(
      backend: deleteBackend, savedSettingsStore: deleteStore)
    let activeSetting = try deleteController.createSavedSettings()
    try deleteController.deleteSavedSettings(id: activeSetting.id)
    #expect(deleteController.activeSavedSettingsID == nil)
    #expect(deleteBackend.active == [10])
    #expect(deleteBackend.batchCalls.isEmpty)
  }

  private static func makeSetting(
    name: String = "Desk",
    monitors: [SavedMonitorConfiguration]? = nil,
    nightMode: NightMode = .none
  ) -> SavedSettings {
    SavedSettings(
      name: name,
      configuration: .init(
        monitors: monitors ?? [
          .init(
            displayUUID: DisplayIdentity.fallbackUUID(for: 10), lastKnownName: "Display 10",
            isEnabled: true, brightnessPercentage: 50)
        ],
        nightMode: nightMode))
  }
}

private enum ProfileTestError: Error { case failed }

private final class MemorySavedSettingsStore: SavedSettingsStoring {
  var settings: [SavedSettings]
  var failSaves = false

  init(_ settings: [SavedSettings] = []) { self.settings = settings }
  func load() throws -> [SavedSettings] { settings }
  func save(_ settings: [SavedSettings]) throws {
    if failSaves { throw ProfileTestError.failed }
    self.settings = settings
  }
}

private final class ProfileDisplayBackend: DisplayBackend {
  struct BrightnessCall: Equatable {
    let id: CGDirectDisplayID
    let percentage: Int
  }

  var online: [CGDirectDisplayID]
  var active: [CGDirectDisplayID]
  var names: [CGDirectDisplayID: String]
  var brightness: [CGDirectDisplayID: Int]
  private(set) var batchCalls: [[CGDirectDisplayID: Bool]] = []
  private(set) var brightnessCalls: [BrightnessCall] = []
  private(set) var nightModeCalls: [NightMode] = []

  init(
    online: [CGDirectDisplayID], active: [CGDirectDisplayID],
    names: [CGDirectDisplayID: String] = [:], brightness: [CGDirectDisplayID: Int] = [:]
  ) {
    self.online = online
    self.active = active
    self.names = names
    self.brightness = brightness
  }

  func onlineDisplayIDs() throws -> [CGDirectDisplayID] { online }
  func activeDisplayIDs() throws -> [CGDirectDisplayID] { active }
  func localizedDisplayNames() -> [CGDirectDisplayID: String] { names }
  func brightnessPercentage(for id: CGDirectDisplayID) -> Int? { brightness[id] }

  func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) throws {
    if enabled {
      if !active.contains(id) { active.append(id) }
    } else {
      active.removeAll { $0 == id }
    }
  }

  func setDisplaysEnabled(_ states: [CGDirectDisplayID: Bool]) throws {
    batchCalls.append(states)
    for (id, enabled) in states { try setDisplay(id, enabled: enabled) }
  }

  func setBrightnessPercentage(_ percentage: Int, for id: CGDirectDisplayID) throws {
    brightnessCalls.append(.init(id: id, percentage: percentage))
    brightness[id] = percentage
  }

  func setNightMode(_ mode: NightMode) throws {
    nightModeCalls.append(mode)
  }
}
