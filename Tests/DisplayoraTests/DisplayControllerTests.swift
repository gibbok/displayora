import CoreGraphics
import Testing

@testable import Displayora

@Suite("Display controller")
struct DisplayControllerTests {
  @Test("Two active displays have stable localized names")
  func twoActiveDisplaysHaveStableNamesAndActiveState() throws {
    let backend = FakeDisplayBackend(
      online: [10, 20],
      active: [10, 20],
      names: [10: "Built-in Display", 20: "Studio Display"]
    )
    let controller = DisplayController(backend: backend)

    #expect(
      try controller.displays() == [
        DisplayDescriptor(id: 10, name: "Built-in Display", isActive: true),
        DisplayDescriptor(id: 20, name: "Studio Display", isActive: true),
      ]
    )
  }

  @Test("A disabled display retains its name and can be re-enabled")
  func disableRetainsNameAndCanBeReenabled() throws {
    let backend = FakeDisplayBackend(
      online: [10, 20],
      active: [10, 20],
      names: [10: "Built-in Display", 20: "Studio Display"]
    )
    let controller = DisplayController(backend: backend)
    _ = try controller.displays()

    backend.names[20] = nil
    backend.removeDisabledDisplaysFromOnlineList = true
    var displays = try controller.setDisplay(20, enabled: false)
    #expect(backend.calls == [.init(id: 20, enabled: false)])
    #expect(displays[1] == DisplayDescriptor(id: 20, name: "Studio Display", isActive: false))

    displays = try controller.setDisplay(20, enabled: true)
    #expect(backend.calls.last == .init(id: 20, enabled: true))
    #expect(displays[1] == DisplayDescriptor(id: 20, name: "Studio Display", isActive: true))
  }

  @Test("The only active display cannot be disabled")
  func onlyActiveDisplayCannotBeDisabled() throws {
    let backend = FakeDisplayBackend(online: [10, 20], active: [10, 20], names: [:])
    let controller = DisplayController(backend: backend)
    _ = try controller.displays()

    // Simulate another display disappearing while the status menu is open.
    backend.active = [10]

    #expect(throws: DisplayControllerError.lastActiveDisplay) {
      try controller.setDisplay(10, enabled: false)
    }
    #expect(backend.calls.isEmpty)
  }

  @Test("A configuration failure preserves the previous state")
  func configurationFailurePreservesState() throws {
    let backend = FakeDisplayBackend(online: [10, 20], active: [10, 20], names: [:])
    let controller = DisplayController(backend: backend)
    backend.configurationError = FakeError.configurationFailed

    #expect(throws: FakeError.configurationFailed) {
      try controller.setDisplay(20, enabled: false)
    }
    #expect(backend.active == [10, 20])
    #expect(try controller.displays().map(\.isActive) == [true, true])
  }
}

private enum FakeError: Error {
  case configurationFailed
}

private final class FakeDisplayBackend: DisplayBackend {
  struct Call: Equatable {
    let id: CGDirectDisplayID
    let enabled: Bool
  }

  var online: [CGDirectDisplayID]
  var active: [CGDirectDisplayID]
  var names: [CGDirectDisplayID: String]
  var configurationError: Error?
  var removeDisabledDisplaysFromOnlineList = false
  private(set) var calls: [Call] = []

  init(
    online: [CGDirectDisplayID],
    active: [CGDirectDisplayID],
    names: [CGDirectDisplayID: String]
  ) {
    self.online = online
    self.active = active
    self.names = names
  }

  func onlineDisplayIDs() throws -> [CGDirectDisplayID] { online }

  func activeDisplayIDs() throws -> [CGDirectDisplayID] { active }

  func localizedDisplayNames() -> [CGDirectDisplayID: String] { names }

  func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) throws {
    calls.append(Call(id: id, enabled: enabled))
    if let configurationError { throw configurationError }

    if enabled {
      if !active.contains(id) { active.append(id) }
      if !online.contains(id) { online.append(id) }
    } else {
      active.removeAll { $0 == id }
      if removeDisabledDisplaysFromOnlineList {
        online.removeAll { $0 == id }
      }
    }
  }
}
