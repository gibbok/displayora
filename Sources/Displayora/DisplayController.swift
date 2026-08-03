import CoreGraphics
import Foundation

struct DisplayDescriptor: Equatable {
  let id: CGDirectDisplayID
  let name: String
  let isActive: Bool
  let brightnessPercentage: Int?
}

protocol DisplayBackend {
  func onlineDisplayIDs() throws -> [CGDirectDisplayID]
  func activeDisplayIDs() throws -> [CGDirectDisplayID]
  func localizedDisplayNames() -> [CGDirectDisplayID: String]
  func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) throws
  func brightnessPercentage(for id: CGDirectDisplayID) -> Int?
  func setBrightnessPercentage(_ percentage: Int, for id: CGDirectDisplayID) throws
}

enum DisplayControllerError: LocalizedError, Equatable {
  case displayNotActive(CGDirectDisplayID)
  case lastActiveDisplay
  case invalidBrightnessPercentage

  var errorDescription: String? {
    switch self {
    case .displayNotActive:
      return "That display is no longer active."
    case .lastActiveDisplay:
      return "Displayora cannot disable the only active display."
    case .invalidBrightnessPercentage:
      return "Brightness must be between 10% and 100% in 5% steps."
    }
  }
}

final class DisplayController {
  private let backend: DisplayBackend
  private var cachedNames: [CGDirectDisplayID: String] = [:]
  private var disabledByDisplayora: Set<CGDirectDisplayID> = []

  init(backend: DisplayBackend) {
    self.backend = backend
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

    return displayIDs.map { id in
      DisplayDescriptor(
        id: id,
        name: cachedNames[id] ?? "Display \(id)",
        isActive: activeIDs.contains(id),
        brightnessPercentage: activeIDs.contains(id) ? backend.brightnessPercentage(for: id) : nil
      )
    }
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

    try backend.setDisplay(id, enabled: enabled)
    if enabled {
      disabledByDisplayora.remove(id)
    } else {
      disabledByDisplayora.insert(id)
    }
    return try displays()
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
    return try displays()
  }
}
