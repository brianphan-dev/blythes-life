// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BlythesLifeShared",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BlythesLifeShared",
            targets: ["BlythesLifeShared"]
        )
    ],
    targets: [
        .target(
            name: "BlythesLifeShared"
        ),
        .testTarget(
            name: "BlythesLifeSharedTests",
            dependencies: ["BlythesLifeShared"]
        )
    ]
)
