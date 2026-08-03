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
        DisplayDescriptor(
          id: 10, name: "Built-in Display", isActive: true, brightnessPercentage: nil),
        DisplayDescriptor(
          id: 20, name: "Studio Display", isActive: true, brightnessPercentage: nil),
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
    #expect(
      displays[1]
        == DisplayDescriptor(
          id: 20, name: "Studio Display", isActive: false, brightnessPercentage: nil))

    displays = try controller.setDisplay(20, enabled: true)
    #expect(backend.calls.last == .init(id: 20, enabled: true))
    #expect(
      displays[1]
        == DisplayDescriptor(
          id: 20, name: "Studio Display", isActive: true, brightnessPercentage: nil))
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

  @Test("Displays expose independent software brightness")
  func displaysExposeIndependentBrightness() throws {
    let backend = FakeDisplayBackend(
      online: [10, 20], active: [10, 20], names: [:], brightness: [10: 35, 20: 80])

    #expect(
      try DisplayController(backend: backend).displays().map(\.brightnessPercentage) == [35, 80])
  }

  @Test("Changing brightness affects only the requested display")
  func changingBrightnessAffectsOnlyRequestedDisplay() throws {
    let backend = FakeDisplayBackend(
      online: [10, 20], active: [10, 20], names: [:], brightness: [10: 35, 20: 80])
    let controller = DisplayController(backend: backend)

    let displays = try controller.setBrightnessPercentage(55, for: 10)

    #expect(backend.brightnessCalls == [.init(id: 10, percentage: 55)])
    #expect(displays.map(\.brightnessPercentage) == [55, 80])
  }

  @Test(
    "Invalid brightness values are rejected",
    arguments: [0, 5, 9, 11, 101, 105]
  )
  func invalidBrightnessIsRejected(percentage: Int) throws {
    let backend = FakeDisplayBackend(
      online: [10], active: [10], names: [:], brightness: [10: 50])
    let controller = DisplayController(backend: backend)

    #expect(throws: DisplayControllerError.invalidBrightnessPercentage) {
      try controller.setBrightnessPercentage(percentage, for: 10)
    }
    #expect(backend.brightnessCalls.isEmpty)
  }

  @Test("Unsupported and inactive displays report unavailable brightness")
  func unsupportedAndInactiveBrightnessIsUnavailable() throws {
    let backend = FakeDisplayBackend(
      online: [10, 20], active: [10], names: [:], brightness: [20: 75])

    let displays = try DisplayController(backend: backend).displays()

    #expect(displays.map(\.brightnessPercentage) == [nil, nil])
  }

  @Test("Brightness cannot be changed on a display that became inactive")
  func brightnessRechecksActiveDisplay() throws {
    let backend = FakeDisplayBackend(
      online: [10], active: [10], names: [:], brightness: [10: 50])
    let controller = DisplayController(backend: backend)
    backend.active = []

    #expect(throws: DisplayControllerError.displayNotActive(10)) {
      try controller.setBrightnessPercentage(55, for: 10)
    }
    #expect(backend.brightnessCalls.isEmpty)
  }

  @Test(
    "Brightness percentage converts to overlay opacity",
    arguments: [(100, 0.0), (55, 0.45), (10, 0.90)]
  )
  func brightnessConvertsToOverlayOpacity(percentage: Int, expectedOpacity: Double) {
    let opacity = Double(SoftwareBrightness.overlayOpacity(for: percentage))
    #expect(abs(opacity - expectedOpacity) < 0.000_001)
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

  struct BrightnessCall: Equatable {
    let id: CGDirectDisplayID
    let percentage: Int
  }

  var online: [CGDirectDisplayID]
  var active: [CGDirectDisplayID]
  var names: [CGDirectDisplayID: String]
  var brightness: [CGDirectDisplayID: Int]
  var configurationError: Error?
  var removeDisabledDisplaysFromOnlineList = false
  private(set) var calls: [Call] = []
  private(set) var brightnessCalls: [BrightnessCall] = []

  init(
    online: [CGDirectDisplayID],
    active: [CGDirectDisplayID],
    names: [CGDirectDisplayID: String],
    brightness: [CGDirectDisplayID: Int] = [:]
  ) {
    self.online = online
    self.active = active
    self.names = names
    self.brightness = brightness
  }

  func onlineDisplayIDs() throws -> [CGDirectDisplayID] { online }

  func activeDisplayIDs() throws -> [CGDirectDisplayID] { active }

  func localizedDisplayNames() -> [CGDirectDisplayID: String] { names }

  func brightnessPercentage(for id: CGDirectDisplayID) -> Int? { brightness[id] }

  func setBrightnessPercentage(_ percentage: Int, for id: CGDirectDisplayID) throws {
    brightnessCalls.append(.init(id: id, percentage: percentage))
    brightness[id] = percentage
  }

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
