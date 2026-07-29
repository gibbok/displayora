import Darwin
import DisplayoraComposition
import DisplayoraCore
import DisplayoraUI
import Foundation

private let featureIDsBySlug = [
  "brightness": "brightness",
  "contrast": "contrast",
  "disable-and-reenable-display": "display-state",
  "keyboard-controls": "keyboard-controls",
  "night-comfort": "night-comfort",
  "resolution-selector": "resolution",
  "volume-and-mute": "volume",
]

@main
private struct FeatureTestHost {
  @MainActor
  static func main() {
    let execution = runFeatureHost(
      arguments: Array(CommandLine.arguments.dropFirst()),
      features: makeInstalledFeatures()
    )
    if !execution.standardOutput.isEmpty {
      print(execution.standardOutput)
    }
    if !execution.standardError.isEmpty {
      FileHandle.standardError.write(Data((execution.standardError + "\n").utf8))
    }
    exit(execution.exitCode)
  }
}

struct HostExecution: Equatable {
  let exitCode: Int32
  let standardOutput: String
  let standardError: String
}

@MainActor
func runFeatureHost(
  arguments: [String],
  features: [any DisplayoraFeature]
) -> HostExecution {
  guard arguments.count == 2, arguments[0] == "--expect-feature" else {
    return failure(
      "usage: DisplayoraFeatureTestHost --expect-feature <canonical-slug>",
      code: 64
    )
  }

  let expectedSlug = arguments[1]
  guard let expectedID = featureIDsBySlug[expectedSlug] else {
    return failure("unknown feature slug '\(expectedSlug)'", code: 65)
  }

  let registry = FeatureRegistry()
  do {
    for feature in features {
      try registry.register(feature)
    }
  } catch {
    return failure(error.localizedDescription, code: 66)
  }

  let snapshot = registry.snapshot
  guard snapshot.features.count == 1 else {
    return failure(
      "expected exactly one installed feature; found \(snapshot.features.count)",
      code: 67
    )
  }
  guard snapshot.features[0].rawValue == expectedID else {
    return failure(
      "selected feature '\(expectedSlug)' registered as "
        + "'\(snapshot.features[0].rawValue)'",
      code: 68
    )
  }

  do {
    let data = try encodeHostSnapshot(makeHostSnapshot(from: snapshot))
    guard let json = String(data: data, encoding: .utf8) else {
      return failure("could not encode host output as UTF-8", code: 69)
    }
    return HostExecution(exitCode: 0, standardOutput: json, standardError: "")
  } catch {
    return failure("could not encode feature snapshot", code: 69)
  }
}

private func failure(_ message: String, code: Int32) -> HostExecution {
  HostExecution(exitCode: code, standardOutput: "", standardError: message)
}
