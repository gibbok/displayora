// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Displayora",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Displayora"),
        .testTarget(name: "DisplayoraTests", dependencies: ["Displayora"]),
    ]
)
