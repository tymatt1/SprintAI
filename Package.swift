// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SprintCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "SprintCore", targets: ["SprintCore"])],
    targets: [
        .target(name: "SprintCore", path: "SprintAI/Core"),
        .testTarget(name: "SprintCoreTests", dependencies: ["SprintCore"], path: "Tests/SprintCoreTests")
    ]
)
