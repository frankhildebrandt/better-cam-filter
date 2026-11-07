// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BetterCamCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BetterCamCore", targets: ["BetterCamCore"])],
    targets: [
        .target(name: "BetterCamCore", path: "Shared"),
        .testTarget(name: "BetterCamCoreTests", dependencies: ["BetterCamCore"], path: "Tests")
    ]
)
