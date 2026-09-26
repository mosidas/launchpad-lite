// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LaunchpadLite",
  platforms: [.macOS(.v14)],
  targets: [
    .executableTarget(name: "LaunchpadLite"),
    .testTarget(name: "LaunchpadLiteTests", dependencies: ["LaunchpadLite"]),
  ]
)
