import AppKit

@main
@MainActor
final class DisplayoraApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private enum Layout {
    static let menuWidth: CGFloat = 420
    static let horizontalInset: CGFloat = 14
    static let contentWidth = menuWidth - (horizontalInset * 2)
    static let primaryButtonHeight: CGFloat = 36
    static let regularButtonHeight: CGFloat = 32
  }

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

    let displayActionsItem = NSMenuItem()
    displayActionsItem.view = displayActionsRow(canReset: !displays.isEmpty)
    menu.addItem(displayActionsItem)

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
    saveButton.controlSize = .large
    saveButton.frame = NSRect(
      x: Layout.horizontalInset, y: 6, width: Layout.contentWidth,
      height: Layout.primaryButtonHeight)
    let saveView = NSView(frame: NSRect(x: 0, y: 0, width: Layout.menuWidth, height: 48))
    saveView.addSubview(saveButton)
    saveItem.view = saveView
    menu.addItem(saveItem)

    menu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit Displayora", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

  }

  private func noSavedSettingsRow() -> NSView {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: Layout.menuWidth, height: 38))
    if displayController.activeSavedSettingsID == nil {
      let checkmark = NSImageView(frame: NSRect(x: 12, y: 11, width: 16, height: 16))
      checkmark.image = NSImage(
        systemSymbolName: "checkmark", accessibilityDescription: "Selected")
      row.addSubview(checkmark)
    }

    let button = NSButton(
      title: "Manual", target: self, action: #selector(selectNoSavedSettings))
    button.bezelStyle = .inline
    button.isBordered = false
    button.alignment = .left
    button.frame = NSRect(x: 30, y: 3, width: 206, height: Layout.regularButtonHeight)
    button.toolTip = "Adjust displays without changing a saved setup"
    row.addSubview(button)
    return row
  }

  private func displayActionsRow(canReset: Bool) -> NSView {
    let rowHeight: CGFloat = 48
    let controlHeight = Layout.primaryButtonHeight
    let controlY = (rowHeight - controlHeight) / 2
    let row = NSView(frame: NSRect(x: 0, y: 0, width: Layout.menuWidth, height: rowHeight))

    let label = NSTextField(labelWithString: "Night mode")
    let labelHeight: CGFloat = 17
    label.frame = NSRect(
      x: Layout.horizontalInset, y: (rowHeight - labelHeight) / 2, width: 72,
      height: labelHeight)
    row.addSubview(label)

    let control = NSSegmentedControl(
      labels: NightMode.allCases.map(\.title), trackingMode: .selectOne, target: self,
      action: #selector(changeNightMode(_:)))
    control.controlSize = .large
    control.frame = NSRect(x: 94, y: controlY, width: 166, height: controlHeight)
    control.selectedSegment = NightMode.allCases.firstIndex(of: displayController.nightMode) ?? 0
    row.addSubview(control)

    let resetButton = NSButton(
      title: "Reset Displays", target: self, action: #selector(resetDisplays))
    resetButton.image = NSImage(
      systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "Reset")
    resetButton.imagePosition = .imageLeading
    resetButton.bezelStyle = .rounded
    resetButton.controlSize = .large
    resetButton.frame = NSRect(x: 272, y: controlY, width: 134, height: controlHeight)
    resetButton.isEnabled = canReset
    resetButton.toolTip = "Enable all displays, set brightness to 100%, and turn off Night mode"
    row.addSubview(resetButton)
    return row
  }

  private func savedSettingsRow(for setting: SavedSettings, displays: [DisplayDescriptor]) -> NSView
  {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: Layout.menuWidth, height: 44))
    let isActive = displayController.activeSavedSettingsID == setting.id
    let isModified = isActive && displayController.activeSavedSettingsIsModified
    let compatibility = displayController.compatibility(of: setting, with: displays)

    let state = NSImageView(frame: NSRect(x: 12, y: 14, width: 16, height: 16))
    if isActive {
      state.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Active")
    } else if !compatibility.isAvailable {
      state.image = NSImage(
        systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Unavailable")
      state.contentTintColor = .systemOrange
    }
    row.addSubview(state)

    let nameWidth: CGFloat = isModified ? 145 : (compatibility.isAvailable ? 315 : 150)
    let name = NSButton(
      title: setting.name, target: self, action: #selector(applySavedSettings(_:)))
    name.identifier = NSUserInterfaceItemIdentifier(setting.id.uuidString)
    name.bezelStyle = .inline
    name.isBordered = false
    name.alignment = .left
    name.lineBreakMode = .byTruncatingTail
    name.frame = NSRect(x: 30, y: 6, width: nameWidth, height: Layout.regularButtonHeight)
    name.toolTip =
      compatibility.isAvailable
      ? "Apply \(setting.name)"
      : "Show why \(setting.name) is unavailable"
    row.addSubview(name)

    if isModified || !compatibility.isAvailable {
      let status = NSTextField(labelWithString: isModified ? "Modified" : "Unavailable")
      status.textColor = .secondaryLabelColor
      status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
      status.frame = NSRect(x: 184, y: 14, width: 72, height: 16)
      row.addSubview(status)
    }

    if isModified {
      row.addSubview(
        profileButton(
          title: "Update", x: 258, width: 78, action: #selector(updateSavedSettings(_:)),
          id: setting.id))
    }

    let actions = profileButton(
      title: "", x: 374, width: 32, action: #selector(showSavedSettingsActions(_:)),
      id: setting.id)
    actions.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "More actions")
    actions.bezelStyle = .inline
    row.addSubview(actions)
    return row
  }

  private func savedSettingsActionsRow(for setting: SavedSettings) -> NSView {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: Layout.menuWidth, height: 44))
    row.addSubview(
      profileButton(
        title: "Rename…", x: 214, width: 94, action: #selector(beginRename(_:)),
        id: setting.id))
    let delete = profileButton(
      title: "Delete…", x: 314, width: 92, action: #selector(beginDelete(_:)),
      id: setting.id)
    delete.contentTintColor = .systemRed
    row.addSubview(delete)
    return row
  }

  private func profileButton(
    title: String, x: CGFloat, width: CGFloat, action: Selector, id: UUID
  ) -> NSButton {
    let button = NSButton(title: title, target: self, action: action)
    button.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
    button.bezelStyle = .rounded
    button.controlSize = .large
    button.frame = NSRect(x: x, y: 6, width: width, height: Layout.regularButtonHeight)
    return button
  }

  private func displayRow(for display: DisplayDescriptor, canDisable: Bool) -> NSView {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: Layout.menuWidth, height: 74))

    let nameLabel = NSTextField(labelWithString: display.name)
    nameLabel.lineBreakMode = .byTruncatingTail
    nameLabel.frame = NSRect(x: Layout.horizontalInset, y: 52, width: 378, height: 17)

    let stateLabel = NSTextField(labelWithString: display.isActive ? "Active" : "Disabled")
    stateLabel.textColor = .secondaryLabelColor
    stateLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    stateLabel.frame = NSRect(x: Layout.horizontalInset, y: 37, width: 378, height: 14)

    let toggle = NSSwitch(frame: NSRect(x: 354, y: 8, width: 52, height: 24))
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
    slider.frame = NSRect(x: Layout.horizontalInset, y: 8, width: 256, height: 26)
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
    brightnessLabel.frame = NSRect(x: 280, y: 12, width: 64, height: 17)

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

  @objc private func changeNightMode(_ sender: NSSegmentedControl) {
    guard NightMode.allCases.indices.contains(sender.selectedSegment) else {
      refreshMenu()
      return
    }

    do {
      try displayController.setNightMode(NightMode.allCases[sender.selectedSegment])
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
      _ = try displayController.createSavedSettings()
      refreshMenu()
    } catch {
      refreshMenu()
      report(error)
    }
  }

  @objc private func selectNoSavedSettings() {
    displayController.selectNoSavedSettings()
    refreshMenu()
  }

  @objc private func applySavedSettings(_ sender: NSButton) {
    guard let id = sender.savedSettingsID else { return }
    do {
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

  @objc private func beginRename(_ sender: NSButton) {
    guard
      let id = sender.savedSettingsID,
      let setting = displayController.savedSettings.first(where: { $0.id == id })
    else { return }

    let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
    field.stringValue = setting.name

    let alert = NSAlert()
    alert.messageText = "Rename saved setup"
    alert.informativeText = "Enter a new name for “\(setting.name)”."
    alert.accessoryView = field
    let rename = alert.addButton(withTitle: "Rename")
    rename.keyEquivalent = "\r"
    let cancel = alert.addButton(withTitle: "Cancel")
    cancel.keyEquivalent = "\u{1b}"

    NSApplication.shared.activate(ignoringOtherApps: true)
    alert.window.initialFirstResponder = field
    DispatchQueue.main.async {
      field.selectText(nil)
    }
    defer { reopenMenu() }
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      NSSound.beep()
      return
    }
    do {
      try displayController.renameSavedSettings(id: id, to: name)
      expandedActionsSettingsID = nil
      refreshMenu()
    } catch {
      refreshMenu()
      report(error)
    }
  }

  private func reopenMenu() {
    DispatchQueue.main.async { [weak self] in
      NSApplication.shared.activate(ignoringOtherApps: true)
      self?.statusItem?.button?.performClick(nil)
    }
  }

  @objc private func beginDelete(_ sender: NSButton) {
    guard
      let id = sender.savedSettingsID,
      let setting = displayController.savedSettings.first(where: { $0.id == id })
    else { return }

    let alert = NSAlert()
    alert.messageText = "Delete saved setup?"
    alert.informativeText = "“\(setting.name)” will be permanently deleted."
    alert.alertStyle = .warning
    let delete = alert.addButton(withTitle: "Delete")
    delete.contentTintColor = .systemRed
    let cancel = alert.addButton(withTitle: "Cancel")
    cancel.keyEquivalent = "\u{1b}"

    NSApplication.shared.activate(ignoringOtherApps: true)
    defer { reopenMenu() }
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    do {
      try displayController.deleteSavedSettings(id: id)
      expandedActionsSettingsID = nil
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

extension NSControl {
  fileprivate var savedSettingsID: UUID? {
    identifier.flatMap { UUID(uuidString: $0.rawValue) }
  }
}
