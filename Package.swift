// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenScreen",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "OpenScreen", targets: ["OpenScreen"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "OpenScreen",
            dependencies: [],
            path: "Sources/native-macos",
            exclude: [
                "Editing/MetalShaders.metal",
                "Editing/MetalShaders.air",
                "Timeline/TimelineShaders.metal",
                "Timeline/TimelineShaders.air"
            ],
            resources: [
                .copy("Editing/MetalShaders.metallib"),
                .copy("Timeline/TimelineShaders.metallib")
            ]
        ),
        .testTarget(
            name: "OpenScreenTests",
            dependencies: ["OpenScreen"],
            path: "Tests/OpenScreenTests"
        )
    ]
)
