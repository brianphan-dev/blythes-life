// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BlythesLifeAppKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BlythesLifeDesignSystem",
            targets: ["BlythesLifeDesignSystem"]
        ),
        .library(
            name: "BlythesLifeCore",
            targets: ["BlythesLifeCore"]
        ),
        .library(
            name: "BlythesLifeUI",
            targets: ["BlythesLifeUI"]
        )
    ],
    dependencies: [
        .package(name: "BlythesLifeShared", path: "../../shared")
    ],
    targets: [
        .target(
            name: "BlythesLifeDesignSystem",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "BlythesLifeCore",
            dependencies: [
                .product(name: "BlythesLifeShared", package: "BlythesLifeShared")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "BlythesLifeUI",
            dependencies: [
                .product(name: "BlythesLifeShared", package: "BlythesLifeShared"),
                "BlythesLifeDesignSystem",
                "BlythesLifeCore"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "BlythesLifeAppKitTests",
            dependencies: [
                .product(name: "BlythesLifeShared", package: "BlythesLifeShared"),
                "BlythesLifeDesignSystem",
                "BlythesLifeCore"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
