import DisplayoraDisplay
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
public protocol DisplayLifecycleObserving: Sendable {
  func events() -> AsyncStream<DisplayLifecycleEvent>
}
public enum DisplayLifecycleEvent: Sendable { case changed, willSleep, didWake }

public actor DisplayPlatform: DisplayPlatformReading {
  private let inventory: any DisplayInventoryReading
  private var snapshot = DisplayPlatformSnapshot(revision: 0, phase: .starting, displays: [])
  private var continuations: [UUID: AsyncStream<DisplayPlatformSnapshot>.Continuation] = [:]
  private var reconciliationTask: Task<Void, Never>?
  public init(inventory: any DisplayInventoryReading) { self.inventory = inventory }
  deinit { reconciliationTask?.cancel() }
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
  public func retry() async { await reconcile() }
  public func reconcile() async {
    publish(phase: .reconciling, displays: snapshot.displays)
    do {
      let records = try await inventory.enumerate()
      let displays = records.map {
        ManagedDisplay(
          id: $0.id, identityStability: $0.stability, localizedName: $0.name,
          isBuiltIn: $0.isBuiltIn, isActive: $0.isActive, dynamicRange: $0.dynamicRange)
      }
      publish(phase: .ready, displays: displays)
    } catch { publish(phase: .failed(.enumerationFailed), displays: []) }
  }
  public func willSleep() {
    reconciliationTask?.cancel()
    publish(phase: .sleeping, displays: [])
  }
  public func didWake() {
    reconciliationTask?.cancel()
    reconciliationTask = Task {
      try? await Task.sleep(for: .seconds(1))
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
