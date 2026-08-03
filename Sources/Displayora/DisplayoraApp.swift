import AppKit

@main
@MainActor
final class DisplayoraApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let displayController = DisplayController(backend: CoreGraphicsDisplayBackend())
  private let menu = NSMenu()
  private var statusItem: NSStatusItem?
  private var screenChangeObserver: NSObjectProtocol?
  private var expandedActionsSettingsID: UUID?

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

  func menuDidClose(_ menu: NSMenu) {
    expandedActionsSettingsID = nil
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

    let resetItem = NSMenuItem()
    let resetButton = NSButton(
      title: "Reset Displays", target: self, action: #selector(resetDisplays))
    resetButton.image = NSImage(
      systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "Reset")
    resetButton.imagePosition = .imageLeading
    resetButton.bezelStyle = .rounded
    resetButton.frame = NSRect(x: 12, y: 5, width: 366, height: 30)
    resetButton.isEnabled = !displays.isEmpty
    resetButton.toolTip = "Enable all displays and set every brightness to 100%"
    let resetView = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 40))
    resetView.addSubview(resetButton)
    resetItem.view = resetView
    menu.addItem(resetItem)

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
    let savedSetupsHeading = NSMenuItem(
      title: "Saved Setups", action: nil, keyEquivalent: "")
    savedSetupsHeading.isEnabled = false
    menu.addItem(savedSetupsHeading)

    let scratchItem = NSMenuItem()
    scratchItem.view = noSavedSettingsRow()
    menu.addItem(scratchItem)

    for setting in displayController.savedSettings {
      let item = NSMenuItem()
      item.title = setting.name
      item.view = savedSettingsRow(for: setting, displays: displays)
      menu.addItem(item)
      if expandedActionsSettingsID == setting.id {
        let actionsItem = NSMenuItem()
        actionsItem.view = savedSettingsActionsRow(for: setting)
        menu.addItem(actionsItem)
      }
    }

    let saveItem = NSMenuItem()
    let saveButton = NSButton(
      title: "Save Current Setup",
      target: self,
      action: #selector(saveCurrentSettings))
    saveButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")
    saveButton.imagePosition = .imageLeading
    saveButton.bezelStyle = .rounded
    saveButton.frame = NSRect(x: 12, y: 5, width: 366, height: 30)
    let saveView = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 40))
    saveView.addSubview(saveButton)
    saveItem.view = saveView
    menu.addItem(saveItem)

    menu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit Displayora", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

  }

  private func noSavedSettingsRow() -> NSView {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 30))
    if displayController.activeSavedSettingsID == nil {
      let checkmark = NSImageView(frame: NSRect(x: 10, y: 7, width: 16, height: 16))
      checkmark.image = NSImage(
        systemSymbolName: "checkmark", accessibilityDescription: "Selected")
      row.addSubview(checkmark)
    }

    let button = NSButton(
      title: "Manual", target: self, action: #selector(selectNoSavedSettings))
    button.bezelStyle = .inline
    button.isBordered = false
    button.alignment = .left
    button.frame = NSRect(x: 28, y: 3, width: 190, height: 24)
    button.toolTip = "Adjust displays without changing a saved setup"
    row.addSubview(button)
    return row
  }

  private func savedSettingsRow(for setting: SavedSettings, displays: [DisplayDescriptor]) -> NSView
  {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 34))
    let isActive = displayController.activeSavedSettingsID == setting.id
    let isModified = isActive && displayController.activeSavedSettingsIsModified
    let compatibility = displayController.compatibility(of: setting, with: displays)

    let state = NSImageView(frame: NSRect(x: 10, y: 9, width: 16, height: 16))
    if isActive {
      state.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Active")
    } else if !compatibility.isAvailable {
      state.image = NSImage(
        systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Unavailable")
      state.contentTintColor = .systemOrange
    }
    row.addSubview(state)

    let nameWidth: CGFloat = isModified ? 135 : (compatibility.isAvailable ? 285 : 140)
    let name = NSButton(
      title: setting.name, target: self, action: #selector(applySavedSettings(_:)))
    name.identifier = NSUserInterfaceItemIdentifier(setting.id.uuidString)
    name.bezelStyle = .inline
    name.isBordered = false
    name.alignment = .left
    name.lineBreakMode = .byTruncatingTail
    name.frame = NSRect(x: 28, y: 5, width: nameWidth, height: 24)
    name.toolTip =
      compatibility.isAvailable
      ? "Apply \(setting.name)"
      : "Show why \(setting.name) is unavailable"
    row.addSubview(name)

    if isModified || !compatibility.isAvailable {
      let status = NSTextField(labelWithString: isModified ? "Modified" : "Unavailable")
      status.textColor = .secondaryLabelColor
      status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
      status.frame = NSRect(x: 168, y: 9, width: 68, height: 16)
      row.addSubview(status)
    }

    if isModified {
      row.addSubview(
        profileButton(
          title: "Update", x: 238, width: 72, action: #selector(updateSavedSettings(_:)),
          id: setting.id))
    }

    let actions = profileButton(
      title: "", x: 344, width: 32, action: #selector(showSavedSettingsActions(_:)),
      id: setting.id)
    actions.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "More actions")
    actions.bezelStyle = .inline
    row.addSubview(actions)
    return row
  }

  private func savedSettingsActionsRow(for setting: SavedSettings) -> NSView {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 36))
    row.addSubview(
      profileButton(
        title: "Rename…", x: 28, width: 90, action: #selector(renameSavedSettings(_:)),
        id: setting.id))
    let delete = profileButton(
      title: "Delete…", x: 124, width: 86, action: #selector(deleteSavedSettings(_:)),
      id: setting.id)
    delete.contentTintColor = .systemRed
    row.addSubview(delete)
    let close = profileButton(
      title: "Done", x: 302, width: 72, action: #selector(hideSavedSettingsActions),
      id: setting.id)
    row.addSubview(close)
    return row
  }

  private func profileButton(
    title: String, x: CGFloat, width: CGFloat, action: Selector, id: UUID
  ) -> NSButton {
    let button = NSButton(title: title, target: self, action: action)
    button.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
    button.bezelStyle = .rounded
    button.frame = NSRect(x: x, y: 5, width: width, height: 24)
    return button
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

  @objc private func resetDisplays() {
    do {
      let displays = try displayController.resetDisplays()
      rebuildMenu(with: displays)
    } catch {
      refreshMenu()
      report(error)
    }
  }

  @objc private func saveCurrentSettings() {
    do {
      expandedActionsSettingsID = nil
      _ = try displayController.createSavedSettings()
      refreshMenu()
    } catch {
      refreshMenu()
      report(error)
    }
  }

  @objc private func selectNoSavedSettings() {
    expandedActionsSettingsID = nil
    displayController.selectNoSavedSettings()
    refreshMenu()
  }

  @objc private func applySavedSettings(_ sender: NSButton) {
    guard let id = sender.savedSettingsID else { return }
    do {
      expandedActionsSettingsID = nil
      let displays = try displayController.applySavedSettings(id: id)
      rebuildMenu(with: displays)
    } catch {
      refreshMenu()
      report(error)
    }
  }

  @objc private func updateSavedSettings(_ sender: Any) {
    do {
      try displayController.updateActiveSavedSettings()
      refreshMenu()
    } catch {
      refreshMenu()
      report(error)
    }
  }

  @objc private func showSavedSettingsActions(_ sender: NSButton) {
    guard let id = sender.savedSettingsID else { return }
    expandedActionsSettingsID = expandedActionsSettingsID == id ? nil : id
    refreshMenu()
  }

  @objc private func hideSavedSettingsActions() {
    expandedActionsSettingsID = nil
    refreshMenu()
  }

  @objc private func renameSavedSettings(_ sender: NSButton) {
    guard let id = sender.savedSettingsID,
      let setting = displayController.savedSettings.first(where: { $0.id == id }),
      let name = promptForName(
        title: "Rename Setup", message: "Enter a new name for this setup.",
        defaultName: setting.name, actionTitle: "Rename")
    else { return }
    do {
      try displayController.renameSavedSettings(id: id, to: name)
      refreshMenu()
    } catch {
      refreshMenu()
      report(error)
    }
  }

  @objc private func deleteSavedSettings(_ sender: NSButton) {
    guard let id = sender.savedSettingsID,
      let setting = displayController.savedSettings.first(where: { $0.id == id })
    else { return }
    NSApplication.shared.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "Delete “\(setting.name)”?"
    alert.informativeText =
      "This saved setup cannot be recovered. Your current displays will not change."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Delete")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }
    do {
      try displayController.deleteSavedSettings(id: id)
      refreshMenu()
    } catch {
      refreshMenu()
      report(error)
    }
  }

  private func promptForName(
    title: String, message: String, defaultName: String, actionTitle: String = "Save"
  ) -> String? {
    NSApplication.shared.activate(ignoringOtherApps: true)
    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    field.stringValue = defaultName
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.accessoryView = field
    alert.addButton(withTitle: actionTitle)
    alert.addButton(withTitle: "Cancel")
    alert.window.initialFirstResponder = field
    guard alert.runModal() == .alertFirstButtonReturn else { return nil }
    let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? defaultName : name
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

extension NSControl {
  fileprivate var savedSettingsID: UUID? {
    identifier.flatMap { UUID(uuidString: $0.rawValue) }
  }
}
