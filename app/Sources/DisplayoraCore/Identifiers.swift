import Foundation

public enum IdentifierValidationError: Error, Equatable, LocalizedError, Sendable {
  case malformed(kind: String, value: String)

  public var errorDescription: String? {
    switch self {
    case .malformed(let kind, let value):
      "Invalid \(kind) identifier '\(value)'."
    }
  }
}

private func validateIdentifier(_ rawValue: String, kind: String) throws {
  let bytes = Array(rawValue.utf8)
  guard let first = bytes.first, first >= 97, first <= 122 else {
    throw IdentifierValidationError.malformed(kind: kind, value: rawValue)
  }

  var previousWasSeparator = false
  for byte in bytes.dropFirst() {
    let isLowercaseLetter = byte >= 97 && byte <= 122
    let isNumber = byte >= 48 && byte <= 57
    let isSeparator = byte == 45 || byte == 46
    guard isLowercaseLetter || isNumber || isSeparator else {
      throw IdentifierValidationError.malformed(kind: kind, value: rawValue)
    }
    guard !(isSeparator && previousWasSeparator) else {
      throw IdentifierValidationError.malformed(kind: kind, value: rawValue)
    }
    previousWasSeparator = isSeparator
  }

  guard !previousWasSeparator else {
    throw IdentifierValidationError.malformed(kind: kind, value: rawValue)
  }
}

public struct FeatureID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: String

  public init?(rawValue: String) {
    guard (try? validateIdentifier(rawValue, kind: "feature")) != nil else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init(validating rawValue: String) throws {
    try validateIdentifier(rawValue, kind: "feature")
    self.rawValue = rawValue
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let identifier = Self(rawValue: value) else {
      throw DecodingError.dataCorruptedError(
        in: try decoder.singleValueContainer(),
        debugDescription: "Invalid feature identifier."
      )
    }
    self = identifier
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct ControlID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: String

  public init?(rawValue: String) {
    guard (try? validateIdentifier(rawValue, kind: "control")) != nil else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init(validating rawValue: String) throws {
    try validateIdentifier(rawValue, kind: "control")
    self.rawValue = rawValue
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let identifier = Self(rawValue: value) else {
      throw DecodingError.dataCorruptedError(
        in: try decoder.singleValueContainer(),
        debugDescription: "Invalid control identifier."
      )
    }
    self = identifier
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct SettingID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: String

  public init?(rawValue: String) {
    guard (try? validateIdentifier(rawValue, kind: "setting")) != nil else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init(validating rawValue: String) throws {
    try validateIdentifier(rawValue, kind: "setting")
    self.rawValue = rawValue
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let identifier = Self(rawValue: value) else {
      throw DecodingError.dataCorruptedError(
        in: try decoder.singleValueContainer(),
        debugDescription: "Invalid setting identifier."
      )
    }
    self = identifier
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct CapabilityID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: String

  public init?(rawValue: String) {
    guard (try? validateIdentifier(rawValue, kind: "capability")) != nil else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init(validating rawValue: String) throws {
    try validateIdentifier(rawValue, kind: "capability")
    self.rawValue = rawValue
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let identifier = Self(rawValue: value) else {
      throw DecodingError.dataCorruptedError(
        in: try decoder.singleValueContainer(),
        debugDescription: "Invalid capability identifier."
      )
    }
    self = identifier
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

public struct CommandID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: String

  public init?(rawValue: String) {
    guard (try? validateIdentifier(rawValue, kind: "command")) != nil else {
      return nil
    }
    self.rawValue = rawValue
  }

  public init(validating rawValue: String) throws {
    try validateIdentifier(rawValue, kind: "command")
    self.rawValue = rawValue
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public init(from decoder: any Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let identifier = Self(rawValue: value) else {
      throw DecodingError.dataCorruptedError(
        in: try decoder.singleValueContainer(),
        debugDescription: "Invalid command identifier."
      )
    }
    self = identifier
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
