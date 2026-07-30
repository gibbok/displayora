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
      SettingsWindowOpener.open(model: model)
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

  private static var window: NSWindow?

  static func open(model: ApplicationModel) {
    NSApp.activate(ignoringOtherApps: true)
    if let window {
      window.makeKeyAndOrderFront(nil)
      return
    }
    let controller = NSHostingController(rootView: ApplicationSettingsContainer(model: model))
    let window = NSWindow(contentViewController: controller)
    window.title = "Displayora Settings"
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.setContentSize(NSSize(width: 468, height: 360))
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    Self.window = window
    logger.info("Opened the Displayora Settings window.")
  }
}

@MainActor
private struct ApplicationSettingsContainer: View {
  @ObservedObject var model: ApplicationModel

  var body: some View {
    SettingsRoot(presentation: model.settingsPresentation, perform: model.perform)
      .onAppear { model.openedSettings() }
  }
}
