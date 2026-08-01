import AppKit

@main
@MainActor
final class DisplayoraApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let displayController = DisplayController(backend: CoreGraphicsDisplayBackend())
  private let menu = NSMenu()
  private var statusItem: NSStatusItem?
  private var screenChangeObserver: NSObjectProtocol?

  static func main() {
    let application = NSApplication.shared
    let delegate = DisplayoraApp()

    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(
      systemSymbolName: "display", accessibilityDescription: "Displayora")
    statusItem.button?.imagePosition = .imageOnly

    menu.delegate = self
    statusItem.menu = menu
    self.statusItem = statusItem

    screenChangeObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.refreshMenu()
      }
    }

    refreshMenu()
  }

  func applicationWillTerminate(_ notification: Notification) {
    if let screenChangeObserver {
      NotificationCenter.default.removeObserver(screenChangeObserver)
    }
  }

  func menuWillOpen(_ menu: NSMenu) {
    refreshMenu()
  }

  private func refreshMenu() {
    do {
      rebuildMenu(with: try displayController.displays())
    } catch {
      rebuildMenu(with: [])
      report(error)
    }
  }

  private func rebuildMenu(with displays: [DisplayDescriptor]) {
    menu.removeAllItems()
    let activeCount = displays.lazy.filter(\.isActive).count

    if displays.isEmpty {
      let unavailableItem = NSMenuItem(
        title: "No displays available", action: nil, keyEquivalent: "")
      unavailableItem.isEnabled = false
      menu.addItem(unavailableItem)
    } else {
      for display in displays {
        let item = NSMenuItem()
        item.view = displayRow(for: display, canDisable: !display.isActive || activeCount > 1)
        menu.addItem(item)
      }
    }

    menu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit Displayora", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
  }

  private func displayRow(for display: DisplayDescriptor, canDisable: Bool) -> NSView {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: 290, height: 38))

    let nameLabel = NSTextField(labelWithString: display.name)
    nameLabel.lineBreakMode = .byTruncatingTail
    nameLabel.frame = NSRect(x: 14, y: 17, width: 190, height: 17)

    let stateLabel = NSTextField(labelWithString: display.isActive ? "Active" : "Disabled")
    stateLabel.textColor = .secondaryLabelColor
    stateLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    stateLabel.frame = NSRect(x: 14, y: 3, width: 190, height: 14)

    let toggle = NSSwitch(frame: NSRect(x: 225, y: 8, width: 50, height: 22))
    toggle.state = display.isActive ? .on : .off
    toggle.isEnabled = canDisable
    toggle.identifier = NSUserInterfaceItemIdentifier(String(display.id))
    toggle.target = self
    toggle.action = #selector(toggleDisplay(_:))
    toggle.toolTip = canDisable ? nil : "The only active display cannot be disabled"

    row.addSubview(nameLabel)
    row.addSubview(stateLabel)
    row.addSubview(toggle)
    return row
  }

  @objc private func toggleDisplay(_ sender: NSSwitch) {
    guard
      let value = sender.identifier?.rawValue,
      let id = CGDirectDisplayID(value)
    else {
      refreshMenu()
      return
    }

    do {
      let displays = try displayController.setDisplay(id, enabled: sender.state == .on)
      rebuildMenu(with: displays)
    } catch {
      refreshMenu()
      report(error)
    }
  }

  private func report(_ error: Error) {
    NSApplication.shared.activate(ignoringOtherApps: true)
    let alert = NSAlert(error: error)
    alert.alertStyle = .warning
    alert.runModal()
  }

  @objc private func quit() {
    NSApplication.shared.terminate(nil)
  }
}
