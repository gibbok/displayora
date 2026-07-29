import AppKit

@MainActor
public protocol SettingsOpening {
  @discardableResult
  func openSettings() -> Bool
}

@MainActor
public struct AppKitSettingsOpener: SettingsOpening {
  private let send: (Selector) -> Bool

  public init() {
    send = { selector in
      NSApp.sendAction(selector, to: nil, from: nil)
    }
  }

  init(send: @escaping (Selector) -> Bool) {
    self.send = send
  }

  @discardableResult
  public func openSettings() -> Bool {
    send(Selector(("showSettingsWindow:")))
  }
}
