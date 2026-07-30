import AppKit
import DisplayoraComposition
import DisplayoraUI
import OSLog
import SwiftUI

@main
struct DisplayoraApp: App {
  @StateObject private var model: ApplicationModel

  @MainActor
  init() {
    #if DISPLAYORA_FOUNDATION_UI_HARNESS
      let harness = FoundationUIHarness(arguments: ProcessInfo.processInfo.arguments)
      let applicationModel = ApplicationModel(installedFeatures: harness.installedFeatures)
      if harness.shouldLoad {
        applicationModel.load()
      }
    #else
      let applicationModel = ApplicationModel(installedFeatures: makeInstalledFeatures())
      applicationModel.load()
    #endif
    _model = StateObject(wrappedValue: applicationModel)
  }

  var body: some Scene {
    MenuBarExtra("Displayora", systemImage: "display.2") {
      MenuBarRoot(presentation: model.menuBarPresentation, perform: perform)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsRoot(presentation: model.settingsPresentation, perform: perform)
    }
  }

  @MainActor
  private func perform(_ action: ShellAction) {
    switch action {
    case .openSettings:
      SettingsWindowOpener.open()
    case .quit:
      NSApplication.shared.terminate(nil)
    default:
      model.perform(action)
    }
  }
}

@MainActor
private enum SettingsWindowOpener {
  private static let logger = Logger(
    subsystem: "com.displayora.Displayora",
    category: "Settings"
  )

  static func open() {
    if #available(macOS 14.0, *) {
      NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    } else if !AppKitSettingsOpener().openSettings() {
      logger.error("AppKit did not accept the Settings window action.")
    }
  }
}
