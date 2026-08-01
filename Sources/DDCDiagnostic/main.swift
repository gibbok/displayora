import CoreGraphics
import Darwin
import Foundation
import IOKit
import IOKit.graphics
import IOKit.i2c

@_silgen_name("CGDisplayIOServicePort")
private func displayIOServicePort(_ display: CGDirectDisplayID) -> io_service_t

private func hex(_ value: Int32) -> String {
  String(format: "0x%08x", UInt32(bitPattern: value))
}

var count: UInt32 = 0
print("list", CGGetActiveDisplayList(0, nil, &count).rawValue, "count", count)
var ids = Array(repeating: CGDirectDisplayID(), count: Int(count))
print("fetch", CGGetActiveDisplayList(count, &ids, &count).rawValue)

for id in ids.prefix(Int(count)) {
  let framebuffer = displayIOServicePort(id)
  var busCount: IOItemCount = 0
  let countResult = IOFBGetI2CInterfaceCount(framebuffer, &busCount)
  print(
    "display", id, "framebuffer", framebuffer, "bus-count-result", hex(countResult), "buses",
    busCount)

  for bus in 0..<busCount {
    var interface: io_service_t = 0
    let copyResult = IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface)
    print(" bus", bus, "copy", hex(copyResult), "interface", interface)
    guard copyResult == kIOReturnSuccess, interface != 0 else { continue }
    defer { IOObjectRelease(interface) }

    var connection: IOI2CConnectRef?
    let openResult = IOI2CInterfaceOpen(interface, 0, &connection)
    print("  open", hex(openResult))
    guard openResult == kIOReturnSuccess, let connection else { continue }
    defer { IOI2CInterfaceClose(connection, 0) }

    var command: [UInt8] = [0x51, 0x82, 0x01, 0x10, 0]
    command[4] = command.dropLast().reduce(0x6e, ^)
    var reply = Array(repeating: UInt8(0), count: 11)
    let sendCount = command.count
    let replyCount = reply.count
    command.withUnsafeMutableBytes { sendBytes in
      reply.withUnsafeMutableBytes { replyBytes in
        var request = IOI2CRequest()
        request.sendTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
        request.replyTransactionType = IOOptionBits(kIOI2CSimpleTransactionType)
        request.sendAddress = 0x6e
        request.replyAddress = 0x6f
        request.minReplyDelay = 40_000_000
        request.sendBuffer = vm_address_t(UInt(bitPattern: sendBytes.baseAddress!))
        request.sendBytes = UInt32(sendCount)
        request.replyBuffer = vm_address_t(UInt(bitPattern: replyBytes.baseAddress!))
        request.replyBytes = UInt32(replyCount)
        let sendResult = IOI2CSendRequest(connection, 0, &request)
        print(
          "  send", hex(sendResult), "transaction", hex(request.result), "bytes",
          request.replyBytes)
      }
    }
    print("  reply", reply.map { String(format: "%02x", $0) }.joined(separator: " "))
  }
}
