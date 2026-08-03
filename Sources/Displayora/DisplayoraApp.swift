import AppKit

@main
@MainActor
final class DisplayoraApp: NSObject, NSApplicationDelegate, NSMenuDelegate, NSTextFieldDelegate {
  private let displayController = DisplayController(backend: CoreGraphicsDisplayBackend())
  private let menu = NSMenu()
  private var statusItem: NSStatusItem?
  private var screenChangeObserver: NSObjectProtocol?
  private var editingSavedSettingsID: UUID?
  private var confirmingDeleteID: UUID?
  private var focusSavedSettingsID: UUID?

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
    let saveItem = NSMenuItem()
    let saveButton = NSButton(
      title: "Save Current Settings",
      target: self,
      action: #selector(saveCurrentSettings))
    saveButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")
    saveButton.imagePosition = .imageLeading
    saveButton.bezelStyle = .rounded
    saveButton.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
    saveButton.frame = NSRect(x: 12, y: 5, width: 286, height: 30)
    let saveView = NSView(frame: NSRect(x: 0, y: 0, width: 310, height: 40))
    saveView.addSubview(saveButton)
    saveItem.view = saveView
    menu.addItem(saveItem)

    let scratchItem = NSMenuItem()
    scratchItem.view = noSavedSettingsRow()
    menu.addItem(scratchItem)

    for setting in displayController.savedSettings {
      let item = NSMenuItem()
      item.view = savedSettingsRow(for: setting, displays: displays)
      menu.addItem(item)
    }

    menu.addItem(.separator())
    let quitItem = NSMenuItem(title: "Quit Displayora", action: #selector(quit), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    if let focusSavedSettingsID {
      self.focusSavedSettingsID = nil
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        let identifier = NSUserInterfaceItemIdentifier(focusSavedSettingsID.uuidString)
        for item in self.menu.items {
          if let field = item.view?.subviews.compactMap({ $0 as? ProfileNameField })
            .first(where: { $0.identifier == identifier })
          {
            field.window?.makeFirstResponder(field)
            field.currentEditor()?.selectedRange = NSRange(
              location: 0, length: field.stringValue.count)
            break
          }
        }
      }
    }
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
      title: "No Saved Settings", target: self, action: #selector(selectNoSavedSettings))
    button.bezelStyle = .inline
    button.isBordered = false
    button.alignment = .left
    button.frame = NSRect(x: 28, y: 3, width: 190, height: 24)
    row.addSubview(button)
    return row
  }

  private func savedSettingsRow(for setting: SavedSettings, displays: [DisplayDescriptor]) -> NSView
  {
    let row = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 34))
    let isActive = displayController.activeSavedSettingsID == setting.id
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

    if confirmingDeleteID == setting.id {
      let question = NSTextField(labelWithString: "Delete “\(setting.name)”?")
      question.lineBreakMode = .byTruncatingTail
      question.frame = NSRect(x: 34, y: 9, width: 190, height: 17)
      row.addSubview(question)
      row.addSubview(
        profileButton(
          title: "Cancel", x: 228, width: 68, action: #selector(cancelDelete(_:)), id: setting.id))
      let delete = profileButton(
        title: "Delete", x: 300, width: 76, action: #selector(confirmDelete(_:)), id: setting.id)
      delete.contentTintColor = .systemRed
      row.addSubview(delete)
      return row
    }

    let nameWidth: CGFloat = compatibility.isAvailable ? 190 : 125
    let name = ProfileNameField(frame: NSRect(x: 28, y: 5, width: nameWidth, height: 24))
    name.stringValue = setting.name
    name.identifier = NSUserInterfaceItemIdentifier(setting.id.uuidString)
    name.isBordered = false
    name.drawsBackground = false
    name.focusRingType = .none
    name.font = .systemFont(ofSize: NSFont.systemFontSize)

    if editingSavedSettingsID == setting.id {
      name.isEditable = true
      name.isSelectable = true
      name.delegate = self
      name.target = self
      name.action = #selector(commitRename(_:))
      name.onCancel = { [weak self] in
        self?.editingSavedSettingsID = nil
        self?.refreshMenu()
      }
    } else {
      name.isEditable = false
      name.isSelectable = false
      name.lineBreakMode = .byTruncatingTail
      name.onBeginEditing = { [weak self] in
        self?.beginRename(id: setting.id)
      }
    }
    row.addSubview(name)

    if !compatibility.isAvailable {
      let status = NSTextField(labelWithString: "Unavailable")
      status.textColor = .secondaryLabelColor
      status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
      status.frame = NSRect(x: 155, y: 9, width: 65, height: 16)
      row.addSubview(status)
    }

    row.addSubview(
      profileButton(
        title: "Apply", x: 225, width: 68, action: #selector(applySavedSettings(_:)), id: setting.id
      ))
    let trash = profileButton(
      title: "", x: 337, width: 32, action: #selector(beginDelete(_:)), id: setting.id)
    trash.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
    trash.bezelStyle = .inline
    row.addSubview(trash)
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

  @objc private func saveCurrentSettings() {
    do {
      let setting = try displayController.createSavedSettings()
      editingSavedSettingsID = setting.id
      focusSavedSettingsID = setting.id
      refreshMenu()
    } catch {
      refreshMenu()
      report(error)
    }
  }

  @objc private func selectNoSavedSettings() {
    displayController.selectNoSavedSettings()
    editingSavedSettingsID = nil
    confirmingDeleteID = nil
    refreshMenu()
  }

  private func beginRename(id: UUID) {
    editingSavedSettingsID = id
    confirmingDeleteID = nil
    focusSavedSettingsID = id
    refreshMenu()
  }

  @objc private func commitRename(_ sender: NSTextField) {
    guard let id = sender.savedSettingsID else { return }
    let trimmed = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    editingSavedSettingsID = nil
    guard !trimmed.isEmpty else {
      refreshMenu()
      return
    }
    do {
      try displayController.renameSavedSettings(id: id, to: trimmed)
      refreshMenu()
    } catch {
      refreshMenu()
      report(error)
    }
  }

  func controlTextDidEndEditing(_ notification: Notification) {
    guard let field = notification.object as? NSTextField,
      let id = field.savedSettingsID,
      editingSavedSettingsID == id
    else { return }
    commitRename(field)
  }

  @objc private func applySavedSettings(_ sender: NSButton) {
    guard let id = sender.savedSettingsID else { return }
    do {
      let displays = try displayController.applySavedSettings(id: id)
      editingSavedSettingsID = nil
      confirmingDeleteID = nil
      rebuildMenu(with: displays)
    } catch {
      refreshMenu()
      report(error)
    }
  }

  @objc private func beginDelete(_ sender: NSButton) {
    guard let id = sender.savedSettingsID else { return }
    confirmingDeleteID = id
    editingSavedSettingsID = nil
    refreshMenu()
  }

  @objc private func cancelDelete(_ sender: NSButton) {
    confirmingDeleteID = nil
    refreshMenu()
  }

  @objc private func confirmDelete(_ sender: NSButton) {
    guard let id = sender.savedSettingsID else { return }
    do {
      try displayController.deleteSavedSettings(id: id)
      confirmingDeleteID = nil
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

@MainActor
private final class ProfileNameField: NSTextField {
  var onBeginEditing: (() -> Void)?
  var onCancel: (() -> Void)?

  override func mouseDown(with event: NSEvent) {
    guard isEditable else {
      onBeginEditing?()
      return
    }
    super.mouseDown(with: event)
  }

  override func cancelOperation(_ sender: Any?) {
    onCancel?()
  }
}

extension NSControl {
  fileprivate var savedSettingsID: UUID? {
    identifier.flatMap { UUID(uuidString: $0.rawValue) }
  }
}
