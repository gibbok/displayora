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
      PopoverRootView(model: model)
    }
    .menuBarExtraStyle(.window)

    Settings {
      SettingsRootView(model: model)
    }
  }
}

private struct PopoverRootView: View {
  @ObservedObject var model: ApplicationModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Displayora")
        .font(.headline)
        .accessibilityLabel("Displayora")

      stateContent

      Divider()

      SettingsButton()

      Button("Quit Displayora") {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
      .accessibilityLabel("Quit Displayora")
    }
    .padding()
    .frame(width: 320)
  }

  @ViewBuilder
  private var stateContent: some View {
    switch model.state {
    case .registering:
      Text("Loading display controls…")
        .accessibilityLabel("Loading display controls")
    case .ready(let snapshot):
      if snapshot.controls.isEmpty {
        Text("No display controls are included in this build.")
          .accessibilityLabel("No display controls are included in this build")
      } else {
        ForEach(snapshot.controls, id: \.id) { contribution in
          contribution.makeView()
            .accessibilityElement(children: .contain)
            .accessibilityLabel(contribution.accessibilityLabel)
        }
      }
    case .failed(let error):
      Text("Displayora couldn’t load its controls.")
        .accessibilityLabel("Displayora could not load its controls")
      Text(error.localizedDescription)
        .accessibilityLabel(error.localizedDescription)
      Button("Try Again") {
        model.retry()
      }
      .accessibilityLabel("Try Again")
    }
  }
}

private struct SettingsRootView: View {
  @ObservedObject var model: ApplicationModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Displayora")
        .font(.title)
        .accessibilityLabel("Displayora Settings")

      switch model.state {
      case .registering:
        Text("Loading settings…")
          .accessibilityLabel("Loading settings")
      case .ready(let snapshot):
        if snapshot.settings.isEmpty {
          Text("No settings are included in this build.")
            .accessibilityLabel("No settings are included in this build")
        } else {
          ForEach(snapshot.settings, id: \.id) { contribution in
            contribution.makeView()
              .accessibilityElement(children: .contain)
              .accessibilityLabel(contribution.accessibilityLabel)
          }
        }
      case .failed:
        Text("No settings are included in this build.")
          .accessibilityLabel("No settings are included in this build")
      }
    }
    .padding(24)
    .frame(minWidth: 420, minHeight: 220)
  }
}

private struct SettingsButton: View {
  var body: some View {
    if #available(macOS 14.0, *) {
      ModernSettingsButton()
    } else {
      LegacySettingsButton()
    }
  }
}

@available(macOS 14.0, *)
private struct ModernSettingsButton: View {
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    Button("Settings…") {
      openSettings()
    }
    .keyboardShortcut(",")
    .accessibilityLabel("Open Displayora Settings")
  }
}

private struct LegacySettingsButton: View {
  private static let logger = Logger(
    subsystem: "com.displayora.Displayora",
    category: "Settings"
  )
  private let opener = AppKitSettingsOpener()

  var body: some View {
    Button("Settings…") {
      if !opener.openSettings() {
        Self.logger.error("AppKit did not accept the Settings window action.")
      }
    }
    .keyboardShortcut(",")
    .accessibilityLabel("Open Displayora Settings")
  }
}
