// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SportsDeskCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "SportsDeskCore", targets: ["SportsDeskCore"])
    ],
    targets: [
        .target(name: "SportsDeskCore"),
        .testTarget(
            name: "SportsDeskCoreTests",
            dependencies: ["SportsDeskCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
