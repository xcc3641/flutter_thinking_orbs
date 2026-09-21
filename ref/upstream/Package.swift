// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThinkingOrbs",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "ThinkingOrbs", targets: ["ThinkingOrbs"]),
    ],
    targets: [
        .target(name: "ThinkingOrbs"),
        .testTarget(
            name: "ThinkingOrbsTests",
            dependencies: ["ThinkingOrbs"],
            resources: [.copy("Resources/orbs-golden.json")]
        ),
    ]
)
