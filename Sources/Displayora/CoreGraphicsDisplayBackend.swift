import AppKit
import CoreGraphics
import Foundation

enum CoreGraphicsDisplayError: LocalizedError {
  case listOnline(CGError)
  case listActive(CGError)
  case beginConfiguration(CGError)
  case configure(CGError)
  case completeConfiguration(CGError)

  var errorDescription: String? {
    switch self {
    case .listOnline(let error):
      return "Could not list connected displays (Core Graphics error \(error.rawValue))."
    case .listActive(let error):
      return "Could not list active displays (Core Graphics error \(error.rawValue))."
    case .beginConfiguration(let error):
      return "Could not begin a display configuration (Core Graphics error \(error.rawValue))."
    case .configure(let error):
      return "Could not change the display (Core Graphics error \(error.rawValue))."
    case .completeConfiguration(let error):
      return "Could not apply the display configuration (Core Graphics error \(error.rawValue))."
    }
  }
}

@_silgen_name("CGSConfigureDisplayEnabled")
private func configureDisplayEnabled(
  _ configuration: CGDisplayConfigRef,
  _ display: CGDirectDisplayID,
  _ enabled: Bool
) -> CGError

struct CoreGraphicsDisplayBackend: DisplayBackend {
  private let softwareBrightness: SoftwareBrightnessController

  init() {
    softwareBrightness = MainActor.assumeIsolated {
      SoftwareBrightnessController()
    }
  }

  func onlineDisplayIDs() throws -> [CGDirectDisplayID] {
    try displayIDs(returnedBy: CGGetOnlineDisplayList, error: CoreGraphicsDisplayError.listOnline)
  }

  func activeDisplayIDs() throws -> [CGDirectDisplayID] {
    let ids = try displayIDs(
      returnedBy: CGGetActiveDisplayList, error: CoreGraphicsDisplayError.listActive)
    MainActor.assumeIsolated {
      softwareBrightness.reconcile(activeDisplayIDs: Set(ids))
    }
    return ids
  }

  func localizedDisplayNames() -> [CGDirectDisplayID: String] {
    Dictionary(
      uniqueKeysWithValues: NSScreen.screens.compactMap { screen in
        guard
          let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            as? NSNumber
        else {
          return nil
        }
        return (CGDirectDisplayID(number.uint32Value), screen.localizedName)
      })
  }

  func displayUUID(for id: CGDirectDisplayID) -> UUID? {
    guard let displayUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
      return nil
    }
    return UUID(uuidString: CFUUIDCreateString(nil, displayUUID) as String)
  }

  func setDisplaysEnabled(_ states: [CGDirectDisplayID: Bool]) throws {
    var configuration: CGDisplayConfigRef?
    let beginError = CGBeginDisplayConfiguration(&configuration)
    guard beginError == .success, let configuration else {
      throw CoreGraphicsDisplayError.beginConfiguration(beginError)
    }

    for (id, enabled) in states.sorted(by: { $0.key < $1.key }) {
      let configureError = configureDisplayEnabled(configuration, id, enabled)
      guard configureError == .success else {
        CGCancelDisplayConfiguration(configuration)
        throw CoreGraphicsDisplayError.configure(configureError)
      }
    }

    let completionError = CGCompleteDisplayConfiguration(configuration, .forAppOnly)
    guard completionError == .success else {
      throw CoreGraphicsDisplayError.completeConfiguration(completionError)
    }
  }

  func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) throws {
    try setDisplaysEnabled([id: enabled])
  }

  func brightnessPercentage(for id: CGDirectDisplayID) -> Int? {
    MainActor.assumeIsolated {
      softwareBrightness.percentage(for: id)
    }
  }

  func setBrightnessPercentage(_ percentage: Int, for id: CGDirectDisplayID) throws {
    MainActor.assumeIsolated {
      softwareBrightness.setPercentage(percentage, for: id)
    }
  }

  func setNightMode(_ mode: NightMode) throws {
    _ = try activeDisplayIDs()
    MainActor.assumeIsolated {
      softwareBrightness.setNightMode(mode)
    }
  }

  private func displayIDs(
    returnedBy function: (
      _ maxDisplays: UInt32, _ displays: UnsafeMutablePointer<CGDirectDisplayID>?,
      _ displayCount: UnsafeMutablePointer<UInt32>?
    ) -> CGError,
    error makeError: (CGError) -> CoreGraphicsDisplayError
  ) throws -> [CGDirectDisplayID] {
    var count: UInt32 = 0
    var result = function(0, nil, &count)
    guard result == .success else { throw makeError(result) }
    guard count > 0 else { return [] }

    var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
    result = function(count, &ids, &count)
    guard result == .success else { throw makeError(result) }
    return Array(ids.prefix(Int(count)))
  }
}

enum SoftwareBrightness {
  private static let warmTintOpacity: CGFloat = 0.16

  static func overlayOpacity(for percentage: Int) -> CGFloat {
    1 - CGFloat(percentage) / 100
  }

  static func overlayOpacity(for percentage: Int, nightMode: NightMode) -> CGFloat {
    let brightnessOpacity = overlayOpacity(for: percentage)
    guard nightMode == .warm else { return brightnessOpacity }
    return 1 - (1 - brightnessOpacity) * (1 - warmTintOpacity)
  }

  static func overlayColor(for percentage: Int, nightMode: NightMode) -> NSColor {
    guard nightMode == .warm else { return .black }

    let clampedPercentage = min(max(percentage, 0), 100)
    let darkness = 1 - CGFloat(clampedPercentage) / 100
    return NSColor.systemOrange.blended(withFraction: darkness, of: .black) ?? .black
  }
}

@MainActor
private final class SoftwareBrightnessController: NSObject {
  private var percentages: [CGDirectDisplayID: Int] = [:]
  private var overlays: [CGDirectDisplayID: NSWindow] = [:]
  private var activeDisplayIDs: Set<CGDirectDisplayID> = []
  private var nightMode: NightMode = .none

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenParametersDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillTerminate),
      name: NSApplication.willTerminateNotification,
      object: nil)
  }

  func percentage(for displayID: CGDirectDisplayID) -> Int {
    percentages[displayID] ?? 100
  }

  func setPercentage(_ percentage: Int, for displayID: CGDirectDisplayID) {
    percentages[displayID] = percentage
    updateOverlay(for: displayID, on: screen(for: displayID))
  }

  func setNightMode(_ mode: NightMode) {
    nightMode = mode
    for displayID in activeDisplayIDs {
      updateOverlay(for: displayID, on: screen(for: displayID))
    }
  }

  func reconcile(activeDisplayIDs: Set<CGDirectDisplayID>) {
    self.activeDisplayIDs = activeDisplayIDs
    for displayID in Array(overlays.keys) where !activeDisplayIDs.contains(displayID) {
      removeOverlay(for: displayID)
    }

    for displayID in activeDisplayIDs {
      updateOverlay(for: displayID, on: screen(for: displayID))
    }
  }

  @objc private func screenParametersDidChange() {
    let screensByID = Dictionary(
      uniqueKeysWithValues: NSScreen.screens.compactMap { screen in
        screen.displayID.map { ($0, screen) }
      })
    reconcile(activeDisplayIDs: Set(screensByID.keys))

    for (displayID, screen) in screensByID {
      updateOverlay(for: displayID, on: screen)
    }
  }

  @objc private func applicationWillTerminate() {
    removeAllOverlays()
  }

  private func updateOverlay(for displayID: CGDirectDisplayID, on screen: NSScreen?) {
    let percentage = percentage(for: displayID)
    let opacity = SoftwareBrightness.overlayOpacity(for: percentage, nightMode: nightMode)
    guard opacity > 0, let screen else {
      removeOverlay(for: displayID)
      return
    }

    let window = overlays[displayID] ?? makeOverlayWindow()
    overlays[displayID] = window
    window.backgroundColor = SoftwareBrightness.overlayColor(
      for: percentage, nightMode: nightMode)
    window.setFrame(screen.frame, display: true)
    window.alphaValue = opacity
    window.orderFrontRegardless()
  }

  private func makeOverlayWindow() -> NSWindow {
    let window = NSWindow(
      contentRect: .zero,
      styleMask: .borderless,
      backing: .buffered,
      defer: false)
    window.isOpaque = false
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.level = .screenSaver
    window.collectionBehavior = [
      .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]
    return window
  }

  private func removeOverlay(for displayID: CGDirectDisplayID) {
    overlays.removeValue(forKey: displayID)?.orderOut(nil)
  }

  private func removeAllOverlays() {
    for window in overlays.values {
      window.orderOut(nil)
    }
    overlays.removeAll()
  }

  private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
    NSScreen.screens.first { $0.displayID == displayID }
  }
}

extension NSScreen {
  fileprivate var displayID: CGDirectDisplayID? {
    (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map {
      CGDirectDisplayID($0.uint32Value)
    }
  }
}
