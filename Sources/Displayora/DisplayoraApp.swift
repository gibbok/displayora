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

    let nightModeItem = NSMenuItem(title: "Night mode", action: nil, keyEquivalent: "")
    let nightModeMenu = NSMenu(title: "Night mode")
    for (index, mode) in NightMode.allCases.enumerated() {
      let modeItem = NSMenuItem(
        title: mode.title, action: #selector(changeNightMode(_:)), keyEquivalent: "")
      modeItem.target = self
      modeItem.tag = index
      modeItem.state = mode == displayController.nightMode ? .on : .off
      nightModeMenu.addItem(modeItem)
    }
    nightModeItem.submenu = nightModeMenu
    menu.addItem(nightModeItem)

    menu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit Displayora", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)
  }

  private func displayRow(for display: DisplayDescriptor, canDisable: Bool) -> NSView {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: 310, height: 68))

    let nameLabel = NSTextField(labelWithString: display.name)
    nameLabel.lineBreakMode = .byTruncatingTail
    nameLabel.frame = NSRect(x: 14, y: 47, width: 210, height: 17)

    let stateLabel = NSTextField(labelWithString: display.isActive ? "Active" : "Disabled")
    stateLabel.textColor = .secondaryLabelColor
    stateLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    stateLabel.frame = NSRect(x: 14, y: 33, width: 210, height: 14)

    let toggle = NSSwitch(frame: NSRect(x: 245, y: 40, width: 50, height: 22))
    toggle.state = display.isActive ? .on : .off
    toggle.isEnabled = canDisable
    toggle.identifier = NSUserInterfaceItemIdentifier(String(display.id))
    toggle.target = self
    toggle.action = #selector(toggleDisplay(_:))
    toggle.toolTip = canDisable ? nil : "The only active display cannot be disabled"

    let brightness = display.brightnessPercentage
    let slider = NSSlider(
      value: Double(brightness ?? 10), minValue: 10, maxValue: 100, target: self,
      action: #selector(changeBrightness(_:)))
    slider.frame = NSRect(x: 14, y: 7, width: 225, height: 24)
    slider.numberOfTickMarks = 20
    slider.tickMarkPosition = .below
    slider.allowsTickMarkValuesOnly = true
    slider.altIncrementValue = 5
    slider.isContinuous = false
    slider.isEnabled = display.isActive && brightness != nil
    slider.identifier = NSUserInterfaceItemIdentifier(String(display.id))

    let brightnessLabel: NSTextField
    if !display.isActive {
      brightnessLabel = NSTextField(labelWithString: "Disabled")
    } else if let brightness {
      brightnessLabel = NSTextField(labelWithString: "\(brightness)%")
    } else {
      brightnessLabel = NSTextField(labelWithString: "Unavailable")
    }
    brightnessLabel.alignment = .right
    brightnessLabel.textColor = .secondaryLabelColor
    brightnessLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    brightnessLabel.frame = NSRect(x: 239, y: 9, width: 57, height: 17)

    row.addSubview(nameLabel)
    row.addSubview(stateLabel)
    row.addSubview(toggle)
    row.addSubview(slider)
    row.addSubview(brightnessLabel)
    return row
  }

  @objc private func changeBrightness(_ sender: NSSlider) {
    guard
      let value = sender.identifier?.rawValue,
      let id = CGDirectDisplayID(value)
    else {
      refreshMenu()
      return
    }

    do {
      let percentage = Int(sender.doubleValue.rounded() / 5) * 5
      let displays = try displayController.setBrightnessPercentage(percentage, for: id)
      rebuildMenu(with: displays)
    } catch {
      refreshMenu()
      report(error)
    }
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

  @objc private func changeNightMode(_ sender: NSMenuItem) {
    guard NightMode.allCases.indices.contains(sender.tag) else {
      refreshMenu()
      return
    }

    do {
      try displayController.setNightMode(NightMode.allCases[sender.tag])
      refreshMenu()
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
