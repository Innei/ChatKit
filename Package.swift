// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ChatKit",
  platforms: [.iOS("26.0"), .macOS("26.0")],
  products: [
    .library(name: "ChatKit", targets: ["ChatKit"]),
    .library(name: "ChatKitCore", targets: ["ChatKitCore"]),
    .library(name: "ChatAppKit", targets: ["ChatAppKit"]),
  ],
  targets: [
    .target(name: "ChatKitCore"),
    .target(name: "ChatKit", dependencies: ["ChatKitCore"]),
    .target(name: "ChatAppKit", dependencies: ["ChatKitCore"]),
    .testTarget(name: "ChatKitCoreTests", dependencies: ["ChatKitCore"]),
    .testTarget(name: "ChatAppKitTests", dependencies: ["ChatAppKit"]),
  ]
)
