import DisplayoraDisplay
import Foundation

public protocol ColorTransformBackend: Sendable {
  func baseline(for display: DisplayID) async throws -> ColorCurve
  func apply(_ curve: ColorCurve, to display: DisplayID) async throws
  func restore(_ curve: ColorCurve, to display: DisplayID) async throws
  func isSafe(for display: DisplayID) async -> Bool
}
public enum ColorTransformError: Error, Equatable { case unsafeDynamicRange, backendFailure }
public actor ColorTransformCoordinator: ColorTransformCoordinating {
  private let backend: any ColorTransformBackend
  private var baselines: [DisplayID: ColorCurve] = [:]
  private var contributions: [DisplayID: [ColorTransformOwnerID: ColorTransformContribution]] = [:]
  private var continuations: [UUID: AsyncStream<[DisplayID: ColorTransformState]>.Continuation] =
    [:]
  public init(backend: any ColorTransformBackend) { self.backend = backend }
  public func set(_ contribution: ColorTransformContribution, for display: DisplayID) async throws {
    guard await backend.isSafe(for: display) else {
      await invalidate(display: display)
      throw ColorTransformError.unsafeDynamicRange
    }
    let baseline = try await baseline(for: display)
    var staged = contributions[display] ?? [:]
    staged[contribution.owner] = contribution
    let composite = compose(baseline: baseline, contributions: staged.values)
    do {
      try await backend.apply(composite, to: display)
      contributions[display] = staged
      publish()
    } catch {
      let previous =
        contributions[display].map { compose(baseline: baseline, contributions: $0.values) }
        ?? baseline
      try? await backend.restore(previous, to: display)
      throw ColorTransformError.backendFailure
    }
  }
  public func remove(owner: ColorTransformOwnerID, from display: DisplayID) async throws {
    guard let baseline = baselines[display] else { return }
    var staged = contributions[display] ?? [:]
    staged[owner] = nil
    let composite =
      staged.isEmpty ? baseline : compose(baseline: baseline, contributions: staged.values)
    do {
      try await backend.apply(composite, to: display)
      if staged.isEmpty {
        contributions[display] = nil
        baselines[display] = nil
      } else {
        contributions[display] = staged
      }
      publish()
    } catch { throw ColorTransformError.backendFailure }
  }
  public func restoreAll() async {
    for (display, baseline) in baselines { try? await backend.restore(baseline, to: display) }
    baselines = [:]
    contributions = [:]
    publish()
  }

  public func invalidate(display: DisplayID) async {
    guard let baseline = baselines[display] else { return }
    try? await backend.restore(baseline, to: display)
    baselines[display] = nil
    contributions[display] = nil
    publish()
  }
  public func states() -> AsyncStream<[DisplayID: ColorTransformState]> {
    let token = UUID()
    return AsyncStream { continuation in
      continuations[token] = continuation
      continuation.yield(Dictionary(uniqueKeysWithValues: contributions.keys.map { ($0, .active) }))
      continuation.onTermination = { [weak self] _ in Task { await self?.remove(token) } }
    }
  }
  private func baseline(for display: DisplayID) async throws -> ColorCurve {
    if let baseline = baselines[display] { return baseline }
    let baseline = try await backend.baseline(for: display)
    baselines[display] = baseline
    return baseline
  }
  private func compose(
    baseline: ColorCurve,
    contributions: Dictionary<ColorTransformOwnerID, ColorTransformContribution>.Values
  ) -> ColorCurve { compose(baseline: baseline, contributions: Array(contributions)) }
  private func compose(baseline: ColorCurve, contributions: [ColorTransformContribution])
    -> ColorCurve
  {
    contributions.sorted {
      $0.priority == $1.priority ? $0.owner < $1.owner : $0.priority < $1.priority
    }.reduce(baseline) { result, next in
      ColorCurve(
        red: zip(result.red, next.curve.red).map { $0 * $1 },
        green: zip(result.green, next.curve.green).map { $0 * $1 },
        blue: zip(result.blue, next.curve.blue).map { $0 * $1 })!
    }
  }
  private func publish() {
    let states = Dictionary(
      uniqueKeysWithValues: contributions.keys.map { ($0, ColorTransformState.active) })
    for continuation in continuations.values { continuation.yield(states) }
  }
  private func remove(_ token: UUID) { continuations[token] = nil }
}
