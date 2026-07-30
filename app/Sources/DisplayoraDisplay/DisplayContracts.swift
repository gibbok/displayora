import DisplayoraCore
import Foundation

public struct DisplayID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public enum DisplayIdentityStability: String, Codable, Sendable {
  case persistent, connectionScoped
}
public enum DisplayDynamicRange: String, Codable, Sendable {
  case standard, highDynamicRange, unknown
}

public struct DisplayCapabilityID: RawRepresentable, Hashable, Comparable, Codable, Sendable {
  public let rawValue: String
  public init?(rawValue: String) {
    guard rawValue.contains("."),
      rawValue.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" })
    else { return nil }
    self.rawValue = rawValue
  }
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct AdapterDescriptor: Equatable, Sendable {
  public let id: String
  public init(id: String) { self.id = id }
}
public struct CapabilityFailure: Equatable, Sendable {
  public let code: String
  public let isRetryable: Bool
  public init(code: String, isRetryable: Bool = true) {
    self.code = code
    self.isRetryable = isRetryable
  }
}
public enum UnsupportedReason: Equatable, Sendable {
  case noMatchingMechanism, permanentlyRejected, unsafeDynamicRange
}
public enum FallbackReason: Equatable, Sendable {
  case hardwareUnsupported, hardwareTemporarilyUnavailable
}
public enum CapabilityMechanism: String, Sendable { case hardware, software }

public enum DisplayCapabilityAvailability: Equatable, Sendable {
  case hardware(AdapterDescriptor)
  case softwareFallback(AdapterDescriptor, FallbackReason)
  case temporarilyUnavailable(CapabilityFailure)
  case unsupported(UnsupportedReason)
}
public struct DisplayCapability: Equatable, Sendable {
  public let id: DisplayCapabilityID
  public let availability: DisplayCapabilityAvailability
  public init(id: DisplayCapabilityID, availability: DisplayCapabilityAvailability) {
    self.id = id
    self.availability = availability
  }
}
public struct ManagedDisplay: Equatable, Sendable {
  public let id: DisplayID
  public let identityStability: DisplayIdentityStability
  public let localizedName: String
  public let isBuiltIn: Bool
  public let isActive: Bool
  public let dynamicRange: DisplayDynamicRange
  public let capabilities: [DisplayCapability]
  public init(
    id: DisplayID, identityStability: DisplayIdentityStability, localizedName: String,
    isBuiltIn: Bool, isActive: Bool, dynamicRange: DisplayDynamicRange,
    capabilities: [DisplayCapability] = []
  ) {
    self.id = id
    self.identityStability = identityStability
    self.localizedName = localizedName
    self.isBuiltIn = isBuiltIn
    self.isActive = isActive
    self.dynamicRange = dynamicRange
    self.capabilities = capabilities.sorted { $0.id < $1.id }
  }
}
public enum DisplayPlatformFailure: Equatable, Sendable { case enumerationFailed, eventStreamEnded }
public enum DisplayPlatformPhase: Equatable, Sendable {
  case starting, reconciling, ready, sleeping
  case failed(DisplayPlatformFailure)
}
public struct DisplayPlatformSnapshot: Equatable, Sendable {
  public let revision: UInt64
  public let phase: DisplayPlatformPhase
  public let displays: [ManagedDisplay]
  public init(revision: UInt64, phase: DisplayPlatformPhase, displays: [ManagedDisplay]) {
    self.revision = revision
    self.phase = phase
    self.displays = displays.sorted {
      (
        $0.isBuiltIn ? 0 : 1,
        $0.localizedName.localizedCaseInsensitiveCompare($1.localizedName) == .orderedAscending
          ? 0 : 1, $0.id
      ) < ($1.isBuiltIn ? 0 : 1, 0, $1.id)
    }
  }
}

public protocol DisplayPlatformReading: Sendable {
  func snapshots() async -> AsyncStream<DisplayPlatformSnapshot>
  func retry() async
}
public struct DisplayProbeEndpoint: Sendable {
  package let id: DisplayID
  package let generation: UInt64
  package init(id: DisplayID, generation: UInt64) {
    self.id = id
    self.generation = generation
  }
}
public enum CapabilityProbeResult: Sendable {
  case usable(AdapterDescriptor)
  case unsupported
  case temporarilyUnavailable(CapabilityFailure)
}
public protocol DisplayCapabilityProbing: Sendable {
  var owner: FeatureID { get }
  var capabilityID: DisplayCapabilityID { get }
  var mechanism: CapabilityMechanism { get }
  func probe(_ endpoint: DisplayProbeEndpoint) async -> CapabilityProbeResult
}

public struct ColorTransformOwnerID: RawRepresentable, Hashable, Comparable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
public struct ColorCurve: Equatable, Sendable {
  public let red: [Float]
  public let green: [Float]
  public let blue: [Float]
  public init?(red: [Float], green: [Float], blue: [Float]) {
    guard
      [red, green, blue].allSatisfy({
        $0.count == 256 && $0.allSatisfy { $0.isFinite && (0...1).contains($0) }
          && zip($0, $0.dropFirst()).allSatisfy(<=)
      })
    else { return nil }
    self.red = red
    self.green = green
    self.blue = blue
  }
}
public struct ColorTransformContribution: Equatable, Sendable {
  public let owner: ColorTransformOwnerID
  public let priority: Int
  public let curve: ColorCurve
  public init(owner: ColorTransformOwnerID, priority: Int, curve: ColorCurve) {
    self.owner = owner
    self.priority = priority
    self.curve = curve
  }
}
public enum ColorTransformState: Equatable, Sendable {
  case active
  case temporarilyUnavailable(CapabilityFailure)
  case unsupported(UnsupportedReason)
}
public protocol ColorTransformCoordinating: Sendable {
  func set(_ contribution: ColorTransformContribution, for display: DisplayID) async throws
  func remove(owner: ColorTransformOwnerID, from display: DisplayID) async throws
  func states() async -> AsyncStream<[DisplayID: ColorTransformState]>
}

public enum DisplayPlatformShellStatus: Equatable, Sendable {
  case loading, available, noDisplays, failed
}
