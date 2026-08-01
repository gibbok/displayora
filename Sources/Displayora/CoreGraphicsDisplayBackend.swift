import AppKit
import CoreGraphics
import Foundation

#if arch(x86_64)
  import Darwin
  import IOKit
  import IOKit.graphics
  import IOKit.i2c
#endif

enum CoreGraphicsDisplayError: LocalizedError {
  case listOnline(CGError)
  case listActive(CGError)
  case beginConfiguration(CGError)
  case configure(CGError)
  case completeConfiguration(CGError)
  case brightnessUnavailable

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
    case .brightnessUnavailable:
      return
        "Could not change this display's hardware brightness. Check that DDC/CI is enabled and supported by the display connection."
    }
  }
}

@_silgen_name("CGSConfigureDisplayEnabled")
private func configureDisplayEnabled(
  _ configuration: CGDisplayConfigRef,
  _ display: CGDirectDisplayID,
  _ enabled: Bool
) -> CGError

#if arch(x86_64)
  // The symbol remains in CoreGraphics and is the only system mapping from a
  // CGDirectDisplayID to the framebuffer needed by IOKit's public I²C API.
  @_silgen_name("CGDisplayIOServicePort")
  private func displayIOServicePort(_ display: CGDirectDisplayID) -> io_service_t
#endif

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

  func brightnessPercentage(for id: CGDirectDisplayID) -> Int? {
    #if arch(x86_64)
      DDCBrightness.readPercentage(for: id)
    #else
      nil
    #endif
  }

  func setBrightnessPercentage(_ percentage: Int, for id: CGDirectDisplayID) throws {
    #if arch(x86_64)
      guard DDCBrightness.writePercentage(percentage, for: id) else {
        throw CoreGraphicsDisplayError.brightnessUnavailable
      }
    #else
      throw CoreGraphicsDisplayError.brightnessUnavailable
    #endif
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

#if arch(x86_64)
  private enum DDCBrightness {
    private static let featureCode: UInt8 = 0x10
    private static let displayWriteAddress: UInt32 = 0x6e
    private static let displayReadAddress: UInt32 = 0x6f
    private static let hostAddressForChecksum: UInt8 = 0x50

    static func readPercentage(for displayID: CGDirectDisplayID) -> Int? {
      withEachBus(for: displayID) { connection in
        guard let value = readNativeValue(using: connection) else { return nil }
        let percentage = Double(value.current) * 100 / Double(value.maximum)
        return min(100, max(5, Int((percentage / 5).rounded()) * 5))
      }
    }

    static func writePercentage(_ percentage: Int, for displayID: CGDirectDisplayID) -> Bool {
      withEachBus(for: displayID) { connection in
        guard let value = readNativeValue(using: connection) else { return nil }
        let scaled = UInt16(
          min(
            UInt32(value.maximum),
            UInt32((Double(value.maximum) * Double(percentage) / 100).rounded())))
        return writeNativeValue(scaled, using: connection) ? true : nil
      } ?? false
    }

    private static func withEachBus<Result>(
      for displayID: CGDirectDisplayID,
      operation: (IOI2CConnectRef) -> Result?
    ) -> Result? {
      let framebuffer = displayIOServicePort(displayID)
      guard framebuffer != 0 else { return nil }

      var busCount: IOItemCount = 0
      guard IOFBGetI2CInterfaceCount(framebuffer, &busCount) == kIOReturnSuccess else {
        return nil
      }

      for bus in 0..<busCount {
        var interface: io_service_t = 0
        guard IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface) == kIOReturnSuccess,
          interface != 0
        else { continue }
        defer { IOObjectRelease(interface) }

        var connection: IOI2CConnectRef?
        guard IOI2CInterfaceOpen(interface, 0, &connection) == kIOReturnSuccess,
          let connection
        else { continue }
        defer { IOI2CInterfaceClose(connection, 0) }

        if let result = operation(connection) { return result }
      }
      return nil
    }

    private static func readNativeValue(using connection: IOI2CConnectRef) -> (
      current: UInt16, maximum: UInt16
    )? {
      var command: [UInt8] = [0x51, 0x82, 0x01, featureCode, 0]
      command[4] = checksum(command.dropLast(), seed: UInt8(displayWriteAddress))
      var reply = Array(repeating: UInt8(0), count: 11)
      let commandCount = command.count
      let replyCapacity = reply.count

      let succeeded = command.withUnsafeMutableBytes { commandBytes in
        reply.withUnsafeMutableBytes { replyBytes in
          var request = IOI2CRequest()
          request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
          request.replyTransactionType = IOOptionBits(kIOI2CDDCciReplyTransactionType)
          request.sendAddress = displayWriteAddress
          request.replyAddress = displayReadAddress
          // DDC/CI requires at least 40 ms between a Get VCP request and reply.
          request.minReplyDelay = absoluteTime(nanoseconds: 40_000_000)
          request.sendBuffer = vm_address_t(UInt(bitPattern: commandBytes.baseAddress!))
          request.sendBytes = UInt32(commandCount)
          request.replyBuffer = vm_address_t(UInt(bitPattern: replyBytes.baseAddress!))
          request.replyBytes = UInt32(replyCapacity)

          return IOI2CSendRequest(connection, 0, &request) == kIOReturnSuccess
            && request.result == kIOReturnSuccess
            && request.replyBytes >= UInt32(replyCapacity)
        }
      }

      guard succeeded,
        reply[0] == UInt8(displayWriteAddress),
        reply[1] & 0x80 == 0x80,
        reply[1] & 0x7f == 8,
        reply[2] == 0x02,
        reply[3] == 0,
        reply[4] == featureCode,
        checksum(reply, seed: hostAddressForChecksum) == 0
      else { return nil }

      let maximum = UInt16(reply[6]) << 8 | UInt16(reply[7])
      guard maximum > 0 else { return nil }
      let current = UInt16(reply[8]) << 8 | UInt16(reply[9])
      return (min(current, maximum), maximum)
    }

    private static func writeNativeValue(_ value: UInt16, using connection: IOI2CConnectRef) -> Bool
    {
      var command: [UInt8] = [
        0x51, 0x84, 0x03, featureCode, UInt8(value >> 8), UInt8(value & 0xff), 0,
      ]
      command[6] = checksum(command.dropLast(), seed: UInt8(displayWriteAddress))
      let commandCount = command.count

      return command.withUnsafeMutableBytes { commandBytes in
        var request = IOI2CRequest()
        request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
        request.replyTransactionType = IOOptionBits(kIOI2CNoTransactionType)
        request.sendAddress = displayWriteAddress
        request.sendBuffer = vm_address_t(UInt(bitPattern: commandBytes.baseAddress!))
        request.sendBytes = UInt32(commandCount)

        return IOI2CSendRequest(connection, 0, &request) == kIOReturnSuccess
          && request.result == kIOReturnSuccess
      }
    }

    private static func checksum<Bytes: Sequence>(_ bytes: Bytes, seed: UInt8) -> UInt8
    where Bytes.Element == UInt8 {
      bytes.reduce(seed, ^)
    }

    private static func absoluteTime(nanoseconds: UInt64) -> UInt64 {
      var timebase = mach_timebase_info_data_t()
      guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.numer > 0 else {
        return nanoseconds
      }
      return nanoseconds * UInt64(timebase.denom) / UInt64(timebase.numer)
    }
  }
#endif
