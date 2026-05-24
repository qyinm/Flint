// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flint",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FlintCore", targets: ["FlintCore"]),
        .executable(name: "FlintApp", targets: ["FlintApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .target(name: "FlintCore"),
        .executableTarget(
            name: "FlintApp",
            dependencies: [
                "FlintCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "FlintCoreTests", dependencies: ["FlintCore"])
    ]
)
