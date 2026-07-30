import DisplayoraDisplay
import ColorSync
import CoreGraphics
import Foundation

public struct DisplayInventoryRecord: Sendable, Equatable {
  public let id: DisplayID
  public let stability: DisplayIdentityStability
  public let name: String
  public let isBuiltIn: Bool
  public let isActive: Bool
  public let dynamicRange: DisplayDynamicRange
  public init(
    id: DisplayID, stability: DisplayIdentityStability, name: String, isBuiltIn: Bool,
    isActive: Bool, dynamicRange: DisplayDynamicRange
  ) {
    self.id = id
    self.stability = stability
    self.name = name
    self.isBuiltIn = isBuiltIn
    self.isActive = isActive
    self.dynamicRange = dynamicRange
  }
}
public protocol DisplayInventoryReading: Sendable {
  func enumerate() async throws -> [DisplayInventoryRecord]
}

public struct CoreGraphicsDisplayInventory: DisplayInventoryReading {
  private let identities: DisplayIdentityResolver

  public init(identities: DisplayIdentityResolver = DisplayIdentityResolver()) {
    self.identities = identities
  }

  public func enumerate() async throws -> [DisplayInventoryRecord] {
    var count: UInt32 = 0
    guard CGGetOnlineDisplayList(0, nil, &count) == .success else {
      throw DisplayInventoryError.enumerationFailed
    }
    var runtimeIDs = Array(repeating: CGDirectDisplayID(), count: Int(count))
    guard CGGetOnlineDisplayList(count, &runtimeIDs, &count) == .success else {
      throw DisplayInventoryError.enumerationFailed
    }
    return runtimeIDs.prefix(Int(count)).enumerated().map { index, runtimeID in
      let uuid = CGDisplayCreateUUIDFromDisplayID(runtimeID).map {
        UUID(uuidString: CFUUIDCreateString(nil, $0.takeRetainedValue()) as String)
      } ?? nil
      let identity = identities.resolve(
        DisplayIdentityMaterial(
          systemUUID: uuid, manufacturer: nil, product: nil, serial: nil,
          connectionToken: String(index)))
      return DisplayInventoryRecord(
        id: identity.0, stability: identity.1, name: "Display", 
        isBuiltIn: CGDisplayIsBuiltin(runtimeID) != 0,
        isActive: CGDisplayIsActive(runtimeID) != 0,
        dynamicRange: .unknown)
    }
  }
}

public enum DisplayInventoryError: Error, Sendable { case enumerationFailed }
public protocol DisplayLifecycleObserving: Sendable {
  func events() -> AsyncStream<DisplayLifecycleEvent>
}
public enum DisplayLifecycleEvent: Sendable { case changed, willSleep, didWake }

public actor DisplayPlatform: DisplayPlatformReading {
  private struct DisplayEndpoint: Sendable {
    let id: DisplayID
    let generation: UInt64
  }

  private let inventory: any DisplayInventoryReading
  private var snapshot = DisplayPlatformSnapshot(revision: 0, phase: .starting, displays: [])
  private var continuations: [UUID: AsyncStream<DisplayPlatformSnapshot>.Continuation] = [:]
  private var reconciliationTask: Task<Void, Never>?
  private var lifecycleTask: Task<Void, Never>?
  private var wakeTask: Task<Void, Never>?
  private var endpointGeneration: UInt64 = 0
  private var endpoints: [DisplayID: DisplayEndpoint] = [:]

  public init(inventory: any DisplayInventoryReading) {
    self.inventory = inventory
  }

  deinit {
    reconciliationTask?.cancel()
    lifecycleTask?.cancel()
    wakeTask?.cancel()
  }
  public func snapshots() -> AsyncStream<DisplayPlatformSnapshot> {
    let token = UUID()
    let current = snapshot
    return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      continuation.yield(current)
      continuations[token] = continuation
      continuation.onTermination = { [weak self] _ in Task { await self?.removeContinuation(token) }
      }
    }
  }
  public func retry() async {
    reconciliationTask?.cancel()
    await reconcile()
  }

  public func start(observing lifecycle: any DisplayLifecycleObserving) {
    lifecycleTask?.cancel()
    lifecycleTask = Task { [weak self] in
      for await event in lifecycle.events() {
        await self?.receive(event)
      }
    }
  }

  public func receive(_ event: DisplayLifecycleEvent) {
    switch event {
    case .changed:
      scheduleReconciliation(after: .milliseconds(200))
    case .willSleep:
      willSleep()
    case .didWake:
      didWake()
    }
  }
  public func reconcile() async {
    publish(phase: .reconciling, displays: snapshot.displays)
    do {
      let records = try await inventory.enumerate()
      let displays = records.map {
        ManagedDisplay(
          id: $0.id, identityStability: $0.stability, localizedName: $0.name,
          isBuiltIn: $0.isBuiltIn, isActive: $0.isActive, dynamicRange: $0.dynamicRange)
      }
      endpointGeneration &+= 1
      endpoints = Dictionary(
        uniqueKeysWithValues: displays.map {
          ($0.id, DisplayEndpoint(id: $0.id, generation: endpointGeneration))
        })
      publish(phase: .ready, displays: displays)
    } catch { publish(phase: .failed(.enumerationFailed), displays: []) }
  }
  public func willSleep() {
    reconciliationTask?.cancel()
    wakeTask?.cancel()
    endpoints = [:]
    publish(phase: .sleeping, displays: [])
  }
  public func didWake() {
    reconciliationTask?.cancel()
    publish(phase: .reconciling, displays: [])
    wakeTask?.cancel()
    wakeTask = Task {
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      await self.reconcile()
    }
  }

  private func scheduleReconciliation(after duration: Duration) {
    reconciliationTask?.cancel()
    reconciliationTask = Task {
      try? await Task.sleep(for: duration)
      guard !Task.isCancelled else { return }
      await self.reconcile()
    }
  }
  private func removeContinuation(_ token: UUID) { continuations[token] = nil }
  private func publish(phase: DisplayPlatformPhase, displays: [ManagedDisplay]) {
    let next = DisplayPlatformSnapshot(
      revision: snapshot.revision + 1, phase: phase, displays: displays)
    guard next.phase != snapshot.phase || next.displays != snapshot.displays else { return }
    snapshot = next
    for continuation in continuations.values { continuation.yield(next) }
  }
}

public actor DisplayPlatformShellStatusProvider {
  private let reader: any DisplayPlatformReading
  public init(reader: any DisplayPlatformReading) { self.reader = reader }
  public func statusUpdates() async -> AsyncStream<DisplayPlatformShellStatus> {
    let snapshots = await reader.snapshots()
    return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      Task {
        var previous: DisplayPlatformShellStatus?
        for await snapshot in snapshots {
          let status: DisplayPlatformShellStatus =
            switch snapshot.phase {
            case .starting, .reconciling: .loading
            case .sleeping: .noDisplays
            case .failed: .failed
            case .ready: snapshot.displays.contains(where: \.isActive) ? .available : .noDisplays
            }
          if status != previous {
            continuation.yield(status)
            previous = status
          }
        }
        continuation.finish()
      }
    }
  }
  public func retry() async { await reader.retry() }
}
