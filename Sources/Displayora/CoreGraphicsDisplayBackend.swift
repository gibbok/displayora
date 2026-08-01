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
  func onlineDisplayIDs() throws -> [CGDirectDisplayID] {
    try displayIDs(returnedBy: CGGetOnlineDisplayList, error: CoreGraphicsDisplayError.listOnline)
  }

  func activeDisplayIDs() throws -> [CGDirectDisplayID] {
    try displayIDs(returnedBy: CGGetActiveDisplayList, error: CoreGraphicsDisplayError.listActive)
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

  func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) throws {
    var configuration: CGDisplayConfigRef?
    let beginError = CGBeginDisplayConfiguration(&configuration)
    guard beginError == .success, let configuration else {
      throw CoreGraphicsDisplayError.beginConfiguration(beginError)
    }

    let configureError = configureDisplayEnabled(configuration, id, enabled)
    guard configureError == .success else {
      CGCancelDisplayConfiguration(configuration)
      throw CoreGraphicsDisplayError.configure(configureError)
    }

    let completionError = CGCompleteDisplayConfiguration(configuration, .forAppOnly)
    guard completionError == .success else {
      throw CoreGraphicsDisplayError.completeConfiguration(completionError)
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
