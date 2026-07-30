// swift-tools-version: 6.0

import Foundation
import PackageDescription

let canonicalFeatures = [
  "brightness",
  "contrast",
  "disable-and-reenable-display",
  "keyboard-controls",
  "night-comfort",
  "resolution-selector",
  "volume-and-mute",
]

let implementedFeatures: Set<String> = []
let rawFeatureSelection = ProcessInfo.processInfo.environment["DISPLAYORA_FEATURES"] ?? ""
let rawFoundationUIHarness =
  ProcessInfo.processInfo.environment["DISPLAYORA_FOUNDATION_UI_HARNESS"] ?? ""
let selectedFeatures: [String]

if rawFeatureSelection.isEmpty {
  selectedFeatures = []
} else {
  let tokens = rawFeatureSelection.split(separator: ",", omittingEmptySubsequences: false).map(
    String.init)
  var seen: Set<String> = []

  for token in tokens {
    guard !token.isEmpty else {
      fatalError(
        "DISPLAYORA_FEATURES contains an empty element in '\(rawFeatureSelection)'. "
          + "Canonical choices: \(canonicalFeatures.joined(separator: ", "))."
      )
    }
    guard token == token.trimmingCharacters(in: .whitespacesAndNewlines) else {
      fatalError(
        "DISPLAYORA_FEATURES contains whitespace in token '\(token)'. "
          + "Canonical choices: \(canonicalFeatures.joined(separator: ", "))."
      )
    }
    guard seen.insert(token).inserted else {
      fatalError("DISPLAYORA_FEATURES contains duplicate token '\(token)'.")
    }
    guard canonicalFeatures.contains(token) else {
      fatalError(
        "Unknown DISPLAYORA_FEATURES token '\(token)'. "
          + "Canonical choices: \(canonicalFeatures.joined(separator: ", "))."
      )
    }
  }

  let unavailable = tokens.filter { !implementedFeatures.contains($0) }
  guard unavailable.isEmpty else {
    fatalError(
      "DISPLAYORA_FEATURES token '\(unavailable[0])' is recognized but not yet implemented."
    )
  }
  selectedFeatures = tokens.sorted()
}

let strictSwiftSettings: [SwiftSetting] = [
  .unsafeFlags(["-warnings-as-errors", "-strict-concurrency=complete"])
]
guard ["", "0", "1"].contains(rawFoundationUIHarness) else {
  fatalError("DISPLAYORA_FOUNDATION_UI_HARNESS must be unset, '0', or '1'.")
}
let displayoraSwiftSettings =
  strictSwiftSettings
  + (rawFoundationUIHarness == "1"
    ? [.define("DISPLAYORA_FOUNDATION_UI_HARNESS")]
    : [])

let package = Package(
  name: "Displayora",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "DisplayoraCore", targets: ["DisplayoraCore"]),
    .library(name: "DisplayoraDisplay", targets: ["DisplayoraDisplay"]),
    .library(name: "DisplayoraUI", targets: ["DisplayoraUI"]),
    .library(name: "DisplayoraComposition", targets: ["DisplayoraComposition"]),
    .library(name: "DisplayoraSystem", targets: ["DisplayoraSystem"]),
    .executable(name: "Displayora", targets: ["Displayora"]),
    .executable(name: "DisplayoraFeatureTestHost", targets: ["DisplayoraFeatureTestHost"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "6.2.4")
  ],
  targets: [
    .target(
      name: "DisplayoraCore",
      swiftSettings: strictSwiftSettings
    ),
    .target(
      name: "DisplayoraDisplay",
      dependencies: ["DisplayoraCore"],
      swiftSettings: strictSwiftSettings
    ),
    .target(
      name: "DisplayoraUI",
      dependencies: ["DisplayoraCore", "DisplayoraDisplay"],
      swiftSettings: strictSwiftSettings
    ),
    .target(
      name: "DisplayoraComposition",
      dependencies: ["DisplayoraDisplay", "DisplayoraUI"],
      swiftSettings: strictSwiftSettings
    ),
    .target(
      name: "DisplayoraSystem",
      dependencies: ["DisplayoraCore", "DisplayoraDisplay"],
      swiftSettings: strictSwiftSettings
    ),
    .executableTarget(
      name: "Displayora",
      dependencies: [
        "DisplayoraComposition", "DisplayoraDisplay", "DisplayoraSystem", "DisplayoraUI",
      ],
      swiftSettings: displayoraSwiftSettings
    ),
    .executableTarget(
      name: "DisplayoraFeatureTestHost",
      dependencies: ["DisplayoraComposition", "DisplayoraUI"],
      swiftSettings: strictSwiftSettings
    ),
    .target(
      name: "DisplayoraTestSupport",
      dependencies: [.product(name: "Testing", package: "swift-testing")],
      path: "Tests/DisplayoraTestSupport",
      swiftSettings: strictSwiftSettings
    ),
    .testTarget(
      name: "DisplayoraCoreTests",
      dependencies: ["DisplayoraCore", "DisplayoraTestSupport"],
      swiftSettings: strictSwiftSettings
    ),
    .testTarget(
      name: "DisplayoraUITests",
      dependencies: ["DisplayoraCore", "DisplayoraUI", "DisplayoraTestSupport"],
      swiftSettings: strictSwiftSettings
    ),
    .testTarget(
      name: "DisplayoraSystemTests",
      dependencies: ["DisplayoraDisplay", "DisplayoraSystem", "DisplayoraTestSupport"],
      swiftSettings: strictSwiftSettings
    ),
    .testTarget(
      name: "DisplayoraCompositionTests",
      dependencies: [
        "DisplayoraComposition",
        "DisplayoraCore",
        "DisplayoraDisplay",
        "DisplayoraUI",
        "DisplayoraTestSupport",
      ],
      swiftSettings: strictSwiftSettings,
    ),
    .testTarget(
      name: "DisplayoraTests",
      dependencies: [
        "Displayora",
        "DisplayoraCore",
        "DisplayoraDisplay",
        "DisplayoraSystem",
        "DisplayoraUI",
        "DisplayoraTestSupport",
      ],
      swiftSettings: strictSwiftSettings,
    ),
    .testTarget(
      name: "DisplayoraFeatureTestHostTests",
      dependencies: [
        "DisplayoraCore",
        "DisplayoraFeatureTestHost",
        "DisplayoraUI",
        "DisplayoraTestSupport",
      ],
      swiftSettings: strictSwiftSettings,
    ),
  ],
  swiftLanguageModes: [.v6]
)
