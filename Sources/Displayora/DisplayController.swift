import CoreGraphics
import Foundation

struct DisplayDescriptor: Equatable {
  let id: CGDirectDisplayID
  let displayUUID: UUID
  let name: String
  let isActive: Bool
  let brightnessPercentage: Int?

  init(
    id: CGDirectDisplayID,
    displayUUID: UUID? = nil,
    name: String,
    isActive: Bool,
    brightnessPercentage: Int?
  ) {
    self.id = id
    self.displayUUID = displayUUID ?? DisplayIdentity.fallbackUUID(for: id)
    self.name = name
    self.isActive = isActive
    self.brightnessPercentage = brightnessPercentage
  }
}

enum DisplayIdentity {
  static func fallbackUUID(for id: CGDirectDisplayID) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012llX", UInt64(id)))!
  }
}

enum NightMode: String, CaseIterable, Codable, Equatable {
  case none
  case warm

  var title: String {
    switch self {
    case .none: "None"
    case .warm: "Warm"
    }
  }
}

protocol DisplayBackend {
  func onlineDisplayIDs() throws -> [CGDirectDisplayID]
  func activeDisplayIDs() throws -> [CGDirectDisplayID]
  func localizedDisplayNames() -> [CGDirectDisplayID: String]
  func displayUUID(for id: CGDirectDisplayID) -> UUID?
  func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) throws
  func setDisplaysEnabled(_ states: [CGDirectDisplayID: Bool]) throws
  func brightnessPercentage(for id: CGDirectDisplayID) -> Int?
  func setBrightnessPercentage(_ percentage: Int, for id: CGDirectDisplayID) throws
  func setNightMode(_ mode: NightMode) throws
}

extension DisplayBackend {
  func displayUUID(for id: CGDirectDisplayID) -> UUID? {
    DisplayIdentity.fallbackUUID(for: id)
  }

  func setDisplaysEnabled(_ states: [CGDirectDisplayID: Bool]) throws {
    for (id, enabled) in states.sorted(by: { $0.key < $1.key }) {
      try setDisplay(id, enabled: enabled)
    }
  }
}

enum DisplayControllerError: LocalizedError, Equatable {
  case displayNotActive(CGDirectDisplayID)
  case lastActiveDisplay
  case invalidBrightnessPercentage
  case displayIdentityUnavailable(CGDirectDisplayID)
  case savedSettingsNotFound
  case emptySavedSettingsName
  case allDisplaysDisabled
  case incompatibleSavedSettings(missing: [String], additional: [String])
  case savedSettingsUpdateFailed

  var errorDescription: String? {
    switch self {
    case .displayNotActive:
      return "That display is no longer active."
    case .lastActiveDisplay:
      return "Displayora cannot disable the only active display."
    case .invalidBrightnessPercentage:
      return "Brightness must be between 10% and 100% in 5% steps."
    case .displayIdentityUnavailable:
      return "A connected display could not be identified reliably."
    case .savedSettingsNotFound:
      return "Those saved settings no longer exist."
    case .emptySavedSettingsName:
      return "Saved settings must have a name."
    case .allDisplaysDisabled:
      return "Saved settings must leave at least one display enabled."
    case .incompatibleSavedSettings(let missing, let additional):
      var parts: [String] = []
      if !missing.isEmpty { parts.append("Missing monitors: \(missing.joined(separator: ", ")).") }
      if !additional.isEmpty {
        parts.append("Additional monitors connected: \(additional.joined(separator: ", ")).")
      }
      return "These saved settings cannot be applied. " + parts.joined(separator: " ")
    case .savedSettingsUpdateFailed:
      return "The current changes could not be saved. The saved setup was left unchanged."
    }
  }
}

final class DisplayController {
  private let backend: DisplayBackend
  private let savedSettingsStore: SavedSettingsStoring
  private var cachedNames: [CGDirectDisplayID: String] = [:]
  private var disabledByDisplayora: Set<CGDirectDisplayID> = []
  private var rememberedBrightness: [UUID: Int] = [:]
  private(set) var nightMode: NightMode = .none
  private(set) var savedSettings: [SavedSettings]
  private(set) var activeSavedSettingsID: UUID?
  private(set) var activeSavedSettingsIsModified = false

  init(
    backend: DisplayBackend,
    savedSettingsStore: SavedSettingsStoring = UserDefaultsSavedSettingsStore()
  ) {
    self.backend = backend
    self.savedSettingsStore = savedSettingsStore
    savedSettings = (try? savedSettingsStore.load()) ?? []
  }

  func displays() throws -> [DisplayDescriptor] {
    var displayIDs = try backend.onlineDisplayIDs()
    let activeIDs = Set(try backend.activeDisplayIDs())
    disabledByDisplayora.subtract(activeIDs)

    for id in disabledByDisplayora where !displayIDs.contains(id) {
      displayIDs.append(id)
    }

    for (id, name) in backend.localizedDisplayNames() {
      cachedNames[id] = name
    }

    let result = try displayIDs.map { id in
      guard let displayUUID = backend.displayUUID(for: id) else {
        throw DisplayControllerError.displayIdentityUnavailable(id)
      }
      let brightness = activeIDs.contains(id) ? backend.brightnessPercentage(for: id) : nil
      if let brightness { rememberedBrightness[displayUUID] = brightness }
      return DisplayDescriptor(
        id: id,
        displayUUID: displayUUID,
        name: cachedNames[id] ?? "Display \(id)",
        isActive: activeIDs.contains(id),
        brightnessPercentage: brightness
      )
    }
    detachActiveSettingsIfIncompatible(with: result)
    return result
  }

  @discardableResult
  func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) throws -> [DisplayDescriptor] {
    if !enabled {
      // Re-read immediately before configuring so a stale menu cannot turn off
      // the only display that remains active.
      let activeIDs = try backend.activeDisplayIDs()
      guard activeIDs.contains(id) else {
        throw DisplayControllerError.displayNotActive(id)
      }
      guard activeIDs.count > 1 else {
        throw DisplayControllerError.lastActiveDisplay
      }
    }

    if !enabled, let uuid = backend.displayUUID(for: id),
      let brightness = backend.brightnessPercentage(for: id)
    {
      rememberedBrightness[uuid] = brightness
    }
    try backend.setDisplaysEnabled([id: enabled])
    if enabled {
      disabledByDisplayora.remove(id)
    } else {
      disabledByDisplayora.insert(id)
    }
    let result = try displays()
    try refreshModificationState(after: result)
    return result
  }

  @discardableResult
  func setBrightnessPercentage(_ percentage: Int, for id: CGDirectDisplayID) throws
    -> [DisplayDescriptor]
  {
    guard (10...100).contains(percentage), percentage.isMultiple(of: 5) else {
      throw DisplayControllerError.invalidBrightnessPercentage
    }

    // Re-read immediately before changing brightness so a stale menu cannot address a
    // display that was disconnected or disabled while the menu was open.
    guard try backend.activeDisplayIDs().contains(id) else {
      throw DisplayControllerError.displayNotActive(id)
    }

    try backend.setBrightnessPercentage(percentage, for: id)
    let result = try displays()
    try refreshModificationState(after: result)
    return result
  }

  func setNightMode(_ mode: NightMode) throws {
    try backend.setNightMode(mode)
    nightMode = mode
    try refreshModificationState(after: displays())
  }

  @discardableResult
  func resetDisplays() throws -> [DisplayDescriptor] {
    let currentDisplays = try displays()
    guard !currentDisplays.isEmpty else { return [] }
    try backend.setDisplaysEnabled(
      Dictionary(uniqueKeysWithValues: currentDisplays.map { ($0.id, true) }))
    disabledByDisplayora.removeAll()
    for display in currentDisplays {
      try backend.setBrightnessPercentage(100, for: display.id)
      rememberedBrightness[display.displayUUID] = 100
    }
    let result = try displays()
    try refreshModificationState(after: result)
    return result
  }

  @discardableResult
  func createSavedSettings(named name: String? = nil) throws -> SavedSettings {
    let displays = try displays()
    let configuration = try captureConfiguration(from: displays)
    let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    let settingName = trimmedName.flatMap { $0.isEmpty ? nil : $0 } ?? nextDefaultName()
    let setting = SavedSettings(name: settingName, configuration: configuration)
    var updated = savedSettings
    updated.append(setting)
    try savedSettingsStore.save(updated)
    savedSettings = updated
    activeSavedSettingsID = setting.id
    activeSavedSettingsIsModified = false
    return setting
  }

  func updateActiveSavedSettings() throws {
    guard let activeSavedSettingsID,
      let index = savedSettings.firstIndex(where: { $0.id == activeSavedSettingsID })
    else { throw DisplayControllerError.savedSettingsNotFound }
    let currentDisplays = try displays()
    let compatibility = compatibility(of: savedSettings[index], with: currentDisplays)
    guard compatibility.isAvailable else {
      throw DisplayControllerError.incompatibleSavedSettings(
        missing: compatibility.missingMonitorNames,
        additional: compatibility.additionalMonitorNames)
    }
    var updated = savedSettings
    updated[index].configuration = try captureConfiguration(from: currentDisplays)
    do {
      try savedSettingsStore.save(updated)
    } catch {
      throw DisplayControllerError.savedSettingsUpdateFailed
    }
    savedSettings = updated
    activeSavedSettingsIsModified = false
  }

  func renameSavedSettings(id: UUID, to name: String) throws {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw DisplayControllerError.emptySavedSettingsName }
    guard let index = savedSettings.firstIndex(where: { $0.id == id }) else {
      throw DisplayControllerError.savedSettingsNotFound
    }
    var updated = savedSettings
    updated[index].name = trimmed
    try savedSettingsStore.save(updated)
    savedSettings = updated
  }

  func deleteSavedSettings(id: UUID) throws {
    guard savedSettings.contains(where: { $0.id == id }) else {
      throw DisplayControllerError.savedSettingsNotFound
    }
    let updated = savedSettings.filter { $0.id != id }
    try savedSettingsStore.save(updated)
    savedSettings = updated
    if activeSavedSettingsID == id {
      activeSavedSettingsID = nil
      activeSavedSettingsIsModified = false
    }
  }

  func selectNoSavedSettings() {
    activeSavedSettingsID = nil
    activeSavedSettingsIsModified = false
  }

  func compatibility(of setting: SavedSettings, with displays: [DisplayDescriptor])
    -> SavedSettingsCompatibility
  {
    let currentByUUID = Dictionary(uniqueKeysWithValues: displays.map { ($0.displayUUID, $0.name) })
    let savedByUUID = Dictionary(
      uniqueKeysWithValues: setting.configuration.monitors.map {
        ($0.displayUUID, $0.lastKnownName)
      })
    return SavedSettingsCompatibility(
      missingMonitorNames: savedByUUID.keys.filter { currentByUUID[$0] == nil }
        .compactMap { savedByUUID[$0] }.sorted(),
      additionalMonitorNames: currentByUUID.keys.filter { savedByUUID[$0] == nil }
        .compactMap { currentByUUID[$0] }.sorted())
  }

  func compatibility(of setting: SavedSettings) throws -> SavedSettingsCompatibility {
    compatibility(of: setting, with: try displays())
  }

  @discardableResult
  func applySavedSettings(id: UUID) throws -> [DisplayDescriptor] {
    guard let setting = savedSettings.first(where: { $0.id == id }) else {
      throw DisplayControllerError.savedSettingsNotFound
    }
    try validate(setting)
    let currentDisplays = try displays()
    let compatibility = compatibility(of: setting, with: currentDisplays)
    guard compatibility.isAvailable else {
      throw DisplayControllerError.incompatibleSavedSettings(
        missing: compatibility.missingMonitorNames,
        additional: compatibility.additionalMonitorNames)
    }

    let idByUUID = Dictionary(uniqueKeysWithValues: currentDisplays.map { ($0.displayUUID, $0.id) })
    let states = Dictionary(
      uniqueKeysWithValues: setting.configuration.monitors.compactMap {
        monitor in idByUUID[monitor.displayUUID].map { ($0, monitor.isEnabled) }
      })
    for monitor in setting.configuration.monitors {
      rememberedBrightness[monitor.displayUUID] = monitor.brightnessPercentage
    }
    try backend.setDisplaysEnabled(states)
    disabledByDisplayora = Set(states.compactMap { $0.value ? nil : $0.key })

    for monitor in setting.configuration.monitors where monitor.isEnabled {
      guard let id = idByUUID[monitor.displayUUID] else { continue }
      try backend.setBrightnessPercentage(monitor.brightnessPercentage, for: id)
      rememberedBrightness[monitor.displayUUID] = monitor.brightnessPercentage
    }
    try backend.setNightMode(setting.configuration.nightMode)
    nightMode = setting.configuration.nightMode
    let result = try displays()
    activeSavedSettingsID = setting.id
    activeSavedSettingsIsModified = false
    return result
  }

  private func validate(_ setting: SavedSettings) throws {
    guard !setting.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw DisplayControllerError.emptySavedSettingsName
    }
    guard !setting.configuration.monitors.isEmpty,
      setting.configuration.monitors.contains(where: \.isEnabled)
    else { throw DisplayControllerError.allDisplaysDisabled }
    guard
      Set(setting.configuration.monitors.map(\.displayUUID)).count
        == setting.configuration.monitors.count
    else { throw SavedSettingsStoreError.malformedData }
    guard
      setting.configuration.monitors.allSatisfy({
        (10...100).contains($0.brightnessPercentage)
          && $0.brightnessPercentage.isMultiple(of: 5)
      })
    else { throw DisplayControllerError.invalidBrightnessPercentage }
  }

  private func captureConfiguration(from displays: [DisplayDescriptor]) throws
    -> SavedDisplayConfiguration
  {
    let monitors = try displays.map { display in
      let brightness =
        display.brightnessPercentage ?? rememberedBrightness[display.displayUUID] ?? 100
      guard (10...100).contains(brightness), brightness.isMultiple(of: 5) else {
        throw DisplayControllerError.invalidBrightnessPercentage
      }
      return SavedMonitorConfiguration(
        displayUUID: display.displayUUID,
        lastKnownName: display.name,
        isEnabled: display.isActive,
        brightnessPercentage: brightness)
    }
    guard monitors.contains(where: \.isEnabled) else {
      throw DisplayControllerError.allDisplaysDisabled
    }
    return SavedDisplayConfiguration(monitors: monitors, nightMode: nightMode)
  }

  private func refreshModificationState(after displays: [DisplayDescriptor]) throws {
    guard let activeSavedSettingsID,
      let setting = savedSettings.first(where: { $0.id == activeSavedSettingsID })
    else { return }
    activeSavedSettingsIsModified =
      try captureConfiguration(from: displays) != setting.configuration
  }

  private func detachActiveSettingsIfIncompatible(with displays: [DisplayDescriptor]) {
    guard let activeSavedSettingsID,
      let setting = savedSettings.first(where: { $0.id == activeSavedSettingsID })
    else { return }
    if !compatibility(of: setting, with: displays).isAvailable {
      self.activeSavedSettingsID = nil
      activeSavedSettingsIsModified = false
    }
  }

  private func nextDefaultName() -> String {
    let existing = Set(savedSettings.map(\.name))
    var number = 1
    while existing.contains("Settings \(number)") { number += 1 }
    return "Settings \(number)"
  }
}
