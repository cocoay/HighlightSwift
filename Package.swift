// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HighlightSwift",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "HighlightSwift",
            targets: ["HighlightSwift"]
        )
    ],
    targets: [
        .target(
            name: "HighlightSwift",
            resources: [.process("HighlightJS")],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "HighlightSwiftTests",
            dependencies: ["HighlightSwift"]
        )
    ]
)
