import DisplayoraDisplay
import Foundation

public struct DisplayIdentityMaterial: Sendable {
  public let systemUUID: UUID?
  public let manufacturer: UInt16?
  public let product: UInt16?
  public let serial: UInt32?
  public let connectionToken: String

  public init(
    systemUUID: UUID?, manufacturer: UInt16?, product: UInt16?, serial: UInt32?,
    connectionToken: String
  ) {
    self.systemUUID = systemUUID
    self.manufacturer = manufacturer
    self.product = product
    self.serial = serial
    self.connectionToken = connectionToken
  }
}

public struct DisplayIdentityResolver: Sendable {
  private let epoch: UUID

  public init(epoch: UUID = UUID()) { self.epoch = epoch }

  public func resolve(_ material: DisplayIdentityMaterial) -> (DisplayID, DisplayIdentityStability) {
    if let systemUUID = material.systemUUID {
      return (DisplayID(rawValue: "display.uuid.\(systemUUID.uuidString.lowercased())"), .persistent)
    }
    if let manufacturer = material.manufacturer, let product = material.product,
      let serial = material.serial, serial != 0
    {
      let value = String(format: "display.edid.%04x.%04x.%08x", manufacturer, product, serial)
      return (DisplayID(rawValue: value), .persistent)
    }
    return (DisplayID(rawValue: "display.connection.\(epoch.uuidString.lowercased()).\(material.connectionToken)"), .connectionScoped)
  }
}
