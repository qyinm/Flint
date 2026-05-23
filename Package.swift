// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flint",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FlintCore", targets: ["FlintCore"]),
        .executable(name: "FlintApp", targets: ["FlintApp"])
    ],
    targets: [
        .target(name: "FlintCore"),
        .executableTarget(
            name: "FlintApp",
            dependencies: ["FlintCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "FlintCoreTests", dependencies: ["FlintCore"])
    ]
)
