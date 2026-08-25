// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoHarbor",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VideoHarbor", targets: ["VideoHarbor"]),
        .library(name: "VideoHarborCore", targets: ["VideoHarborCore"])
    ],
    targets: [
        .target(name: "VideoHarborCore", path: "Sources/VideoHarborCore"),
        .executableTarget(
            name: "VideoHarbor",
            dependencies: ["VideoHarborCore"],
            path: "Sources/VideoHarbor"
        ),
        .testTarget(
            name: "VideoHarborTests",
            dependencies: ["VideoHarborCore"],
            path: "Tests/VideoHarborTests",
            sources: ["CoreTests.swift"]
        )
    ]
)
